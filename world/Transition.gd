extends Area

# allow to place the player in the next scene
export(String) var target_room :String = ""
export(String) var target_point:String = ""

func _ready()->void:
	if global.rooms.has(self.target_room):
		self.connect("body_entered", self, "_on_body_entered")
	else:
		print("Transition improperly configured.")


# if our player entered the zone, change of scene
func _on_body_entered(body:Node)->void:
	if body.is_network_master() and body is Player:
		# load new scene and filter players that should be visible
		body.rpc("change_room", self.target_point)
		global.load_room(self.target_room)
		body.point = self.target_point