extends CharacterBody3D

signal coin_collected

@export_subgroup("Components")
@export var view: Node3D
@export var tree_scene: PackedScene

@export_subgroup("Properties")
@export var movement_speed = 250
@export var jump_strength = 7

var movement_velocity: Vector3
var rotation_direction: float
var gravity = 0

var previously_floored = false

var jump_single = true
var jump_double = true

var coins = 0

@onready var particles_trail = $ParticlesTrail
@onready var sound_footsteps = $SoundFootsteps
@onready var model = $Character
@onready var animation = $Character/AnimationPlayer
@onready var camera = $Camera

# Functions

func _physics_process(delta):
	
	# Handle functions
	
	handle_controls(delta)
	handle_gravity(delta)
	
	handle_effects(delta)
	
	# Movement

	var applied_velocity: Vector3
	
	applied_velocity = velocity.lerp(movement_velocity, delta * 10)
	applied_velocity.y = -gravity
	
	velocity = applied_velocity
	move_and_slide()
	
	# Rotation
	
	if Vector2(velocity.z, velocity.x).length() > 0:
		rotation_direction = Vector2(velocity.z, velocity.x).angle()
		
	rotation.y = lerp_angle(rotation.y, rotation_direction, delta * 10)
	
	# Falling/respawning
	
	if position.y < -10:
		get_tree().reload_current_scene()
	
	# Animation for scale (jumping and landing)
	
	model.scale = model.scale.lerp(Vector3(1, 1, 1), delta * 10)
	
	# Animation when landing
	
	if is_on_floor() and gravity > 2 and !previously_floored:
		model.scale = Vector3(1.25, 0.75, 1.25)
		Audio.play("res://sounds/land.ogg")
	
	previously_floored = is_on_floor()

# Handle animation(s)

func handle_effects(delta):
	
	particles_trail.emitting = false
	sound_footsteps.stream_paused = true
	
	if is_on_floor():
		var horizontal_velocity = Vector2(velocity.x, velocity.z)
		var speed_factor = horizontal_velocity.length() / movement_speed / delta
		if speed_factor > 0.05:
			animation.play("walk", 0, speed_factor)
				
			if speed_factor > 0.3:
				sound_footsteps.stream_paused = false
				sound_footsteps.pitch_scale = speed_factor
				
			if speed_factor > 0.75:
				particles_trail.emitting = true
				
		else:
			animation.play("idle", 0)
	else:
		animation.play("jump", 0)

# Handle movement input

func handle_controls(delta):
	
	# Movement
	
	var input := Vector3.ZERO
	
	input.x = Input.get_axis("move_left", "move_right")
	input.z = Input.get_axis("move_forward", "move_back")
	
	#input = input.rotated(Vector3.UP, view.rotation.y)
	#var camera_angle = Basis.looking_at((Vector3.BACK * sqrt(2) + Vector3.RIGHT), Vector3.UP)
	var camera_angle = Basis.looking_at(camera.camera_angle_flat)
	input = -(camera_angle * input)
	
	if input.length() > 1:
		input = input.normalized()
		
	movement_velocity = input * movement_speed * delta
	
	# Jumping
	
	if Input.is_action_just_pressed("jump"):
		
		if jump_single or jump_double:
			jump()
	
	if Input.is_action_just_pressed("action_1"):
		spawn_tree()
# Handle gravity

func handle_gravity(delta):
	
	gravity += 25 * delta
	
	if gravity > 0 and is_on_floor():
		
		jump_single = true
		gravity = 0

# Jumping

func jump():
	
	Audio.play("res://sounds/jump.ogg")
	
	gravity = -jump_strength
	
	model.scale = Vector3(0.5, 1.5, 0.5)
	
	if jump_single:
		jump_single = false;
		jump_double = true;
	else:
		jump_double = false;

func spawn_tree():
	var i: TreeObject = tree_scene.instantiate()
	get_parent().add_child(i)
	
	#await get_tree().create_timer(1).timeout
	#await i.done_adding_in
	
	# position tree to plabyer
	#i.global_position = global_position
	#i.global_position -= i.tree_root_helper.position
	
	get_tree().create_tween().tween_property(
		i, 
		"global_position", 
		global_position - i.tree_root_helper.position, 
		4
	)
	
	
	

# Collecting coins

func collect_coin():
	coins += 1
	coin_collected.emit(coins)
