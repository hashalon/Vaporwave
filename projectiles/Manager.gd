extends Node

# max number of this type of projectile in the scene
export(int, 1, 1000) var max_number:int = 100

# projectile handled by this manager
export(String) var template:String = ""

# starting point to look for a free projectile
var _index:int = 0

# generate the projectiles
func _ready()->void:
	var temp:PackedScene = load(self.template)
	
	# generate the requested amount of projectiles
	for i in range(self.max_number):
		var projectile:Projectile = temp.instance() # projectiles can have variable names
		add_child(projectile, true) # give it a name so that we can communicate with it in rpc


# fire a new projectile
func fire_projectile(id:int, position:Vector3, target:Vector3)->void:
	# find a projectile that is available to use
	var projectiles:Array = get_children()
	
	# start searching at previous index
	for i in range(_index, get_child_count()):
		if _try_firing_projectile(i, id, position, target): return
	
	# start back from the beginning of the array
	for i in range(0, _index):
		if _try_firing_projectile(i, id, position, target): return
	
	# failed to find a free projectile
	_index = 0


# companion method of 'fire_projectile'
func _try_firing_projectile(index:int, id:int, position:Vector3, target:Vector3)->bool:
	# get the selected projectile
	var projectile:Projectile = get_child(index)
	if projectile.is_free_to_use():
		projectile.rpc("fire", id, position, target)
		_index = index
		return true
	return false