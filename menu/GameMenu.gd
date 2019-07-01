extends Control

func _ready():
	$spawn_btn.connect("button_down", self, "_on_spawn")
	$leave_btn.connect("button_down", lobby, "leave_game")
	
	var tree:SceneTree=get_tree()
	# TODO: problem: the list is not fully updated when those signals are called...
	tree.connect("network_peer_connected"   , self, "_on_update_list")
	tree.connect("network_peer_disconnected", self, "_on_update_list")


func _on_spawn()->void:
	var id:int = get_tree().get_network_unique_id()
	global.rpc("spawn", id, "plain", "bear")
	
	# find the player we just created
#	var player:Player = global.find_node(str(id))
#	if player.is_network_master():
#		self.add_child(player)
#	player.set_room("plain")
	
	#if not global.rooms.has(room):
	#	print("Room '" + room + "' does not exists, cannot load level."); return
	

# when a player arrive or leave
func _on_update_list(id:int)->void:
	var tree:SceneTree = get_tree()
	var text:String = dict_name(lobby.player_names, tree.get_network_unique_id())
	for id in tree.get_network_connected_peers():
		text += "\n" + dict_name(lobby.player_names, id)
	$player_list.text = text

static func dict_name(dict, id)->String:
	if dict.has(id): return dict[id]
	else: return str(id)