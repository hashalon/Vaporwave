extends RayCast
class_name Projectile

# parameters of the projectile
export(float, 0, 100) var speed       :float = 10  #(m/s)
export(int  , 0,  10) var max_bounces :int   = 0   #(nb)
export(float, 0,   1) var network_lerp:float = 0.1 #(%)

# the player who fired this projectile
var player_id:int = 0

var _bounces:int = 0 # counter for bounces
var _life_timer:Timer = null # timer for lifespan (may be null...)
var _sync_timer:Timer = null # timer for network synchronization

# correct the position of the projectile over time
var _target_position:Vector3 = Vector3.ZERO

# disable the projectile at start
func _ready():
	make_dormant()
	if has_node("life_timer"):
		_life_timer = $life_timer
		_life_timer.connect("timeout", self, "destroy")
	if has_node("sync_timer"):
		_sync_timer = $sync_timer
		if is_network_master():
			_sync_timer.connect("timeout", self, "_send_unreliable")
			_sync_timer.start()


# correct the position of the projectile over time (for puppets only)
func _process(delta:float)->void:
	# move the target as the projectile moves
	var forward:Vector3 = -self.global_transform.basis.z
	_target_position += forward * self.speed * delta
	
	# interpolate the projectile toward the traget position
	self.global_transform.origin = self.global_transform.origin.linear_interpolate(
		_target_position, self.network_lerp)


# manage motion and interactions with the world
func _physics_process(delta:float)->void:
	var forward:Vector3 = -self.global_transform.basis.z
	global_translate(forward * self.speed * delta)
	
	# when our projectile hit something...
	if is_colliding():
		var coll:Node = get_collider()
		if coll.is_in_group("entities"):
			pass
			# TODO: apply damages
			if is_network_master(): rpc("destroy")
			
		elif _bounces > 0:
			var bounce:Vector3 = forward.bounce(get_collision_normal())
			var point:Vector3 = get_collision_point()
			look_at_from_position(point, point + bounce, Vector3.UP)
		else:
			if is_network_master(): rpc("destroy")


# send the state of the projectile at a constant rate across the network
func _send_unreliable()->void:
	rpc_unreliable("synchronize", self.global_transform.origin, -self.global_transform.basis.z)

puppet func synchronize(position:Vector3, forward:Vector3)->void:
	_target_position = position
	look_at(_target_position + forward, Vector3.UP)


# activate the projectile
remotesync func fire(id:int, position:Vector3, target:Vector3)->void:
	self.player_id = id
	look_at_from_position(position, target, Vector3.UP)
	_bounces = self.max_bounces
	
	# start the timer if any
	if _life_timer != null: _life_timer.start()
	
	# wake up the projectile
	self.enabled = true
	set_physics_process(true)
	if not is_network_master(): set_process(true)
	show()


# is the projectile dormant
func is_free_to_use()->bool: return not self.enabled


# destroy the projectile, generate an impact before making it dormant
remotesync func destroy()->void:
	# TODO:...
	make_dormant()


# call this method to make this projectile dormant for next firing
func make_dormant()->void:
	self.enabled = false
	set_physics_process(false)
	set_process(false)
	hide()