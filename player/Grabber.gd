extends Area

var _item:Spatial=null

func _ready()->void:
	var player:Player=$'..'
	var err:int = player.connect("action", self, "_on_action")

# find an object to grab
func find_object_to_grab()->Spatial:
	var selected:Spatial=null
	var distance:float=INF
	
	for body in get_overlapping_bodies():
		# check if the body is closer
		var dist:float=self.global_transform.origin.distance_squared_to(body.global_transform.origin)
		if dist < distance:
			pass
			# check the type of the body
	
	# return the object selected if any
	return selected


# grab the object
func grab(object:Spatial)->void:
	# check the type to disable the object
	_item=object


func throw()->void:
	# check the type to reenable the object
	_item=null


# called when the player start pressing the action button
func _on_action()->void:
	if _item == null:
		var obj:Spatial=find_object_to_grab()
		if obj != null: grab(obj)
	else: throw()