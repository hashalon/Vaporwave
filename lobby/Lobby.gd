extends Node
class_name Lobby

# game event relative to us
signal joined_game
signal left_game
signal character_spawned
signal character_died

const main_menu:PackedScene = preload("res://menu/main_menu.tscn")

# port to use for this game
const PORT:int=19952

# maximum number of players allow on this server
export(int, 1, 128) var max_players:int=32

# our name and the room currently loaded
var own_name:String = "unnamed"
var current_room:String = ""

# store the name of each player so that it is easier to identify them
var player_names:Dictionary={}

# store available rooms and models in the game
var rooms:Dictionary = {
	"forest": "res://world/rooms/forest.tscn",
	"plain":  "res://world/rooms/plain.tscn",
}
var characters:Dictionary = {
	"bear":     preload("res://player/characters/bear.tscn"),
	"bunny":    preload("res://player/characters/bunny.tscn"),
	"kitty":    preload("res://player/characters/kitty.tscn"),
	"panda":    preload("res://player/characters/panda.tscn"),
	"redpanda": preload("res://player/characters/redpanda.tscn"),
}


func _notification(what:int)->void:
	if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST :
		leave_game()
		get_tree().quit()


func _ready()->void:
	self.set_network_master(1, false)
	var tree:SceneTree=get_tree()
	tree.connect("server_disconnected"      , self, "leave_game")
	tree.connect("network_peer_connected"   , self, "_on_player_connected")
	tree.connect("network_peer_disconnected", self, "_on_player_disconnected")


### CALLBACKS ###

# called on peer when a new client connected
func _on_player_connected(id:int)->void:
	var own_id:int = get_tree().get_network_unique_id()
	# send this peer id and name to the newly connected client
	rpc_id(id, "set_player_name", own_id, self.own_name)
	
	# if we have a player already present in the game,
	# ask the new client to spawn it
	if has_node(str(own_id)):
		var character = get_node(str(own_id))
		rpc_id(id, "spawn", own_id, character.character_name, character.global_transform.origin)
	
	# server should also notify player of the room to load
	if get_tree().is_network_server():
		rpc_id(id, "load_room", self.current_room)


# rpc call of peers on newly connected client
remote func set_player_name(id:int, player_name:String)->void:
	self.player_names[id] = player_name

# rpc call of server on nwely connected client
remote func load_room(room:String)->bool:
	# try to load room
	if self.rooms.has(room):
		get_tree().change_scene(self.rooms[room])
		self.current_room = room
		
		# add the game menu to the tree
		#get_tree().root.add_child(global.game_menu.instance())
		return true
	else: return false
	

# called on peer when the client disconnected
func _on_player_disconnected(id:int)->void:
	self.player_names.erase(id)
	
	# if the client had a player in the game, destroy it
	if has_node(str(id)):
		var character = get_node(str(id))
		character.queue_free()


### CONTROLS ###

# create a game
func host_game(room:String)->int:
	var tree:SceneTree=get_tree()
	if tree.has_network_peer(): return ERR_ALREADY_EXISTS
	
	# create the server
	var host:NetworkedMultiplayerENet = NetworkedMultiplayerENet.new()
	var res:int = host.create_server(PORT, max_players)
	
	# add this player name to the list
	if res == OK:
		tree.network_peer = host
		self.player_names[1] = self.own_name
		
		# if we failed to load the map
		if load_room(room):
			emit_signal("joined_game")
			
		else:
			print("Room '" + room + "' does not exists, fail to start server.")
			leave_game()
			return ERR_DOES_NOT_EXIST
	
	return res


# join a game
func join_game(ip:String)->int:
	var tree:SceneTree=get_tree()
	if tree.has_network_peer(): return ERR_ALREADY_EXISTS
	
	# create the connection
	var host:NetworkedMultiplayerENet = NetworkedMultiplayerENet.new()
	var res:int = host.create_client(ip, PORT)
	
	# add this player name to the list
	if res == OK:
		tree.network_peer = host
		self.player_names[tree.get_network_unique_id()] = self.own_name
		emit_signal("joined_game")
	
	return res


# leave a game
func leave_game()->void:
	var tree:SceneTree=get_tree()
	
	# reset everything
	self.player_names = {}
	for player in get_children():
		player.queue_free()
	
	# then close the connection
	if tree.has_network_peer():
		tree.network_peer.close_connection()
	tree.network_peer = null
	
	# return to the main menu
	tree.change_scene_to(self.main_menu)
	self.current_room = ""
	emit_signal("left_game")


### SPAWN ###

# generate a new character for the given player in the specified room
# the player will always appear at (0,0,0)
remotesync func spawn(id:int, character_name:String, position:Vector3)->void:
	if not self.characters.has(character_name):
		print("Character '" + character_name + "' does not exists, will pick a random character.")
		character_name = self.characters.keys()[0]
	
	# prepare a new player
	var character = self.characters[character_name].instance()
	character.name = str(id) # set name as id
	character.character_name = character_name
	character.global_transform.origin = position
	character.set_network_master(id, true) # set network master as id
	add_child(character)
	
	if character.is_network_master():
		emit_signal("character_spawned")
