extends Control

func _ready():
	$spawn_btn.connect("button_down", self, "_on_spawn")
	$leave_btn.connect("button_down", lobby, "leave_game")
	
	var tree:SceneTree=get_tree()
	# TODO: problem: the list is not fully updated when those signals are called...
	tree.connect("network_peer_connected"   , self, "_on_update_list")
	tree.connect("network_peer_disconnected", self, "_on_update_list")


func _on_spawn()->void:
	var tree:SceneTree = get_tree()
	
	# get room and model to use
	var room :String = "plain"
	var model:String = "bear"
	var point:String = "/root/room/spawns/spawn1"
	
	var id:int = tree.get_network_unique_id()
	global.rpc("spawn", id, room, model, point)
	global.load_room(room)
	


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