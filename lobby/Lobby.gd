extends Node
class_name Lobby

# port to use for this game
const PORT:int=19952

# maximum number of players allow on this server
export(int, 1, 128) var max_players:int=32

# store the name of each player so that it is easier to identify them
var own_name:String="unnamed"
var player_names:Dictionary={}


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
	if global.has_node(str(own_id)):
		var player:Player = global.get_node(str(own_id))
		global.rpc_id(id, "spawn", own_id, player.model, player.global_transform.origin)
	
	# server should also notify player of the room to load
	if get_tree().is_network_server():
		rpc_id(id, "load_room", global.current_room)


# rpc call of peers on newly connected client
remote func set_player_name(id:int, player_name:String)->void:
	self.player_names[id] = player_name

# rpc call of server on nwely connected client
remote func load_room(room:String)->bool:
	# try to load room
	if global.rooms.has(room):
		get_tree().change_scene_to(global.rooms[room])
		global.current_room = room
		
		# add the game menu to the tree
		get_tree().root.add_child(global.game_menu.instance())
		return true
	else: return false
	

# called on peer when the client disconnected
func _on_player_disconnected(id:int)->void:
	self.player_names.erase(id)
	
	# if the client had a player in the game, destroy it
	if global.has_node(str(id)):
		var player:Player = global.get_node(str(id))
		player.queue_free()


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
		if not load_room(room):
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
	
	return res


# leave a game
func leave_game()->void:
	var tree:SceneTree=get_tree()
	
	# reset everything
	self.player_names = {}
	for player in global.get_children():
		player.queue_free()
	
	# then close the connection
	if tree.has_network_peer():
		tree.network_peer.close_connection()
	tree.network_peer = null
	
	# return to the main menu
	tree.change_scene_to(global.main_menu)


