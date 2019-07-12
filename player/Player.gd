extends KinematicBody
class_name Player

signal jump
signal action

# parameters of players
export(int  , 1  , 10) var health         :int  = 3  #(pt)
export(float, 0.1, 50) var speed_walk     :float=10  #(m/s)
export(float, 0.1, 50) var speed_run      :float=20  #(m/s)
export(float, 0.1, 50) var jump_force     :float=20  #(m/s2)
export(float, 0.1,100) var gravity_force  :float=60  #(m/s2)
export(float, 0.1,100) var gravity_jump   :float=30  #(m/s2)
export(float, 1  ,200) var max_speed      :float=20  #(m/s)
export(float, 0  , 90) var slope_max_angle:float=45  #(deg)
export(float, 0  ,  1) var move_lerp      :float=0.1 #(%)
export(float, 0  ,  1) var network_lerp   :float=0.1 #(%)
export(float, 1  ,100) var pop_threshold  :float=10  #(m)


# called each time the player enter the scene tree
func _ready()->void:
	# local instance controls the player
	if is_network_master():
		var net_timer:Timer = $network_timer
		var err:int = net_timer.connect("timeout", self, "_send_unreliable")
		net_timer.start()
	else: # player is puppet
		set_process_unhandled_input(false)


# control the player character
func _process(delta:float)->void:
	if is_network_master(): # player controlling
		if _to_send_reliable:
			rpc("receive_reliable_inputs", _reliable_inputs)
			_reliable_inputs  = 0x0
			_to_send_reliable = false
	
	else: # puppet
		# if the object is too far, pop it to its target position
		if _target_position.distance_squared_to(self.global_transform.origin) > self.pop_threshold * self.pop_threshold:
			self.global_transform.origin = _target_position
		
		else: # slowly interpolate over time
			self.global_transform.origin = self.global_transform.origin.linear_interpolate(
				_target_position, self.network_lerp)

	# apply motion based on inputs received from the network
	move(delta)


### MOTIONS ###

# store maximum slope angle as radians
var _slope_angle:float=deg2rad(self.slope_max_angle)

# use two velocities for horizontal and vertical movements
var _velocity_horizontal:Vector3=Vector3.ZERO # (velocity in a possibly bended plane)
var _velocity_vertical:float=0 # (velocity along the vertical axis)

const STICK_TO_GROUND:float = -0.1

# move the character based on user inputs
func move(delta:float)->void:
	# find how the character should move on the surface
	var ground:Plane = get_ground_normal()
	var move:Vector3 = get_move(ground)
	var speed:float = self.speed_run if _hold_action else self.speed_walk
	_velocity_horizontal = _velocity_horizontal.linear_interpolate(move * speed, self.move_lerp)
	
	# on the floor and jumping
	if is_on_floor():
		_velocity_vertical = STICK_TO_GROUND
		if not _jump_timer.is_stopped():
			_velocity_vertical = self.jump_force
			_jump_timer.stop()
	# going up and holding the jump key -> high jump
	elif _velocity_vertical > 0 and _hold_jump:
		_velocity_vertical -= self.gravity_jump * delta
	else: # falling down
		_velocity_vertical -= self.gravity_force * delta
	
	# in all cases, limit the maximum velocity
	if _velocity_horizontal.length_squared() > self.max_speed * self.max_speed:
		_velocity_horizontal = _velocity_horizontal.normalized() * self.max_speed
	_velocity_vertical = clamp(_velocity_vertical, -self.max_speed, self.max_speed)
	
	# move the character
	var velocity:Vector3 = _velocity_horizontal + Vector3(0, _velocity_vertical, 0)
	move_and_slide(velocity, ground.normal, false, 4, _slope_angle, true)


### PHYSICS ###

# find the normal of the ground if any
func get_ground_normal()->Plane:
	var normal:Vector3
	var angle:float=PI # max angle possible
	
	# find the collision which normal is closest to the UP direction
	for i in range(get_slide_count()):
		var coll:KinematicCollision = get_slide_collision(i)
		var ang:float = coll.normal.angle_to(Vector3.UP)
		if ang < angle:
			normal = coll.normal
			angle = ang
	
	# if it is still over the maximum slope allowed, revert to just UP
	if angle > _slope_angle: normal = Vector3.UP
	return Plane(normal, 0)


### NETWORKING ###

var model:String="" # model for this player to load on peers
onready var _target_position:Vector3=self.global_transform.origin

# send player data in a single rpc call
func _send_unreliable()->void:
	rpc_unreliable("receive_unreliable", _get_unreliable_inputs(), 
		self.global_transform.origin, _velocity_horizontal, _velocity_vertical)

# receive player data
puppet func receive_unreliable(i:int, pos:Vector3, vel_h:Vector3, vel_v:float)->void:
	_set_unreliable_inputs(i)
	_target_position     = pos
	_velocity_horizontal = vel_h
	_velocity_vertical   = vel_v

puppet func receive_reliable_inputs(i:int)->void:
	if i&0x01!=0:
		emit_signal("jump")
		_jump_timer.start()
	if i&0x02!=0:
		emit_signal("action")


### INPUTS ###

# store state of keys
var _move_up    :bool=false
var _move_down  :bool=false
var _move_left  :bool=false
var _move_right :bool=false
var _hold_jump  :bool=false
var _hold_action:bool=false
onready var _jump_timer:Timer=$jump_timer

# layout:
# 0: press jump
# 1: press action
var _reliable_inputs:int=0x0
var _to_send_reliable:bool=false

# handle key presses
func _unhandled_input(e:InputEvent)->void:
	if e.is_pressed() and not e.is_echo(): # start pressing action
		if   e.is_action("move_up"   ): _move_up   =true
		elif e.is_action("move_down" ): _move_down =true
		elif e.is_action("move_left" ): _move_left =true
		elif e.is_action("move_right"): _move_right=true
		elif e.is_action("jump"):
			_reliable_inputs |= 0x1; _hold_jump = true
			_to_send_reliable = true; emit_signal("jump")
			_jump_timer.start()
		elif e.is_action("action"):
			_reliable_inputs |= 0x2; _hold_action = true
			_to_send_reliable = true; emit_signal("action")
	elif not e.is_pressed(): # just released action
		if   e.is_action("move_up"   ): _move_up    =false
		elif e.is_action("move_down" ): _move_down  =false
		elif e.is_action("move_left" ): _move_left  =false
		elif e.is_action("move_right"): _move_right =false
		elif e.is_action("jump"      ): _hold_jump  =false
		elif e.is_action("action"    ): _hold_action=false

# get how the character wants to move
func get_move(ground:Plane)->Vector3:
	var move:Vector3=Vector3.ZERO
	if _move_up   : move.z-=1
	if _move_down : move.z+=1
	if _move_left : move.x-=1
	if _move_right: move.x+=1
	if move == Vector3.ZERO: return Vector3.ZERO
	else: return ground.project(move).normalized()

# package inputs to be sent over the network
func _get_unreliable_inputs()->int:
	var i:int=0x0
	if _move_up    : i|=0x01
	if _move_down  : i|=0x02
	if _move_left  : i|=0x04
	if _move_right : i|=0x08
	if _hold_jump  : i|=0x10
	if _hold_action: i|=0x20
	return i

# apply inputs received from the network
func _set_unreliable_inputs(i:int)->void:
	_move_up    =i&0x01!=0
	_move_down  =i&0x02!=0
	_move_left  =i&0x04!=0
	_move_right =i&0x08!=0
	_hold_jump  =i&0x10!=0
	_hold_action=i&0x20!=0


### OBJECT ###

func get_class()->String: return "Player"
func is_class(name:String)->bool:
	if name == "Player": return true
	else: return .is_class(name)