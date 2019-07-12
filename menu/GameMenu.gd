extends Control

func _ready()->void:
	$spawn_btn.connect("button_down", self, "_on_spawn")
	$leave_btn.connect("button_down", lobby, "leave_game")
	
	var tree:SceneTree=get_tree()
	
	lobby.connect("joined_game"      , self, "set_visible", [true])
	lobby.connect("left_game"        , self, "set_visible", [false])
	lobby.connect("character_spawned", self, "set_visible", [false])
	lobby.connect("character_died"   , self, "set_visible", [true])
	
	# TODO: problem: the list is not fully updated when those signals are called...
	#tree.connect("network_peer_connected"   , self, "_on_update_list")
	#tree.connect("network_peer_disconnected", self, "_on_update_list")
	
	self.visible = false


func _on_spawn()->void:
	var tree:SceneTree = get_tree()
	
	# model to use
	var model:String = "bear"
	var point:Vector3 = Vector3.ZERO
	
	var id:int = tree.get_network_unique_id()
	lobby.rpc("spawn", id, model, point)


func _on_game_joined()->void:
	self.visible = true

func _on_game_left()->void:
	self.visible = false


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