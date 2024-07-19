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

# tree climbing

var snapped: bool
var last_collision_Object: CSGPolygon3D
var path: Path3D
var path_follow: PathFollow3D
var progress: float


var jump_single = true
var jump_double = true

var coins = 0



@onready var particles_trail = $ParticlesTrail
@onready var sound_footsteps = $SoundFootsteps
@onready var model = $Character
@onready var animation = $Character/AnimationPlayer
@onready var camera = $Camera
@onready var marker = $Marker


func _physics_process(delta):
	model.scale = model.scale.lerp(Vector3(1, 1, 1), delta * 10)


	if snapped:
		handle_controls_snapped(delta)
		
		if Vector2(movement_velocity.z, movement_velocity.x).length() > 0:
			rotation_direction = Vector2(movement_velocity.z, movement_velocity.x).angle()
			
		rotation.y = lerp_angle(rotation.y, rotation_direction, delta * 10)
		
		# progress += delta
		progress = fposmod(progress, 1.0)

		# set position to the pathffolower




	if not snapped:
		handle_controls(delta)
		handle_gravity(delta)
		handle_effects(delta)

		var applied_velocity: Vector3
		applied_velocity = velocity.lerp(movement_velocity, delta * 10)
		applied_velocity.y = -gravity
		velocity = applied_velocity
		
		if move_and_slide():
			if check_for_tree():
				return

		
		if Vector2(velocity.z, velocity.x).length() > 0:
			rotation_direction = Vector2(velocity.z, velocity.x).angle()
			
		rotation.y = lerp_angle(rotation.y, rotation_direction, delta * 10)
		
		
		# Falling/respawning
		if position.y < -10:
			get_tree().reload_current_scene()
		
		# Animation for scale (jumping and landing)
		#model.scale = model.scale.lerp(Vector3(1, 1, 1), delta * 10)
		
		# Animation when landing
		if is_on_floor() and gravity > 2 and !previously_floored:
			if last_collision_Object:
				# is keptss
				last_collision_Object.use_collision = true

				# is not kepts
				# state of the palyer

				path = null
				path_follow = null


			
			model.scale = Vector3(1.25, 0.75, 1.25)
			Audio.play("res://sounds/land.ogg")
		
		previously_floored = is_on_floor()


func handle_controls_snapped(delta):
	var input := Vector3.ZERO
	
	input.x = Input.get_axis("move_left", "move_right")
	input.z = Input.get_axis("move_forward", "move_back")

	var angle = Basis.looking_at(camera.world_angle)
	input = -(angle * input)
	
	if input.length() > 1:
		input = input.normalized()
	
	movement_velocity = input * movement_speed * delta

	# move on tree
	# fmod
	progress = progress + input.z * delta
	

	print(progress)




	if Input.is_action_just_pressed("jump"):
		if jump_single or jump_double:
			snapped = false
			jump()


func check_for_tree():

	#or double jump?
	if not previously_floored:
		for i in get_slide_collision_count():
			for ii in get_slide_collision(i).get_collision_count():
				var v = get_slide_collision(i).get_collider(ii)
				if v is CSGPolygon3D:

					last_collision_Object = v
					v.use_collision = false
				
					jump_single = true
					jump_double = true
				
					snapped = true
				
					#var _path_follow: PathFollow3D = v.get_node(^"../Path3D/PathFollow3D")
					# var _path: Path3D = v.get_node(^"../Path3D")

					path_follow = v.get_node(^"../Path3D/PathFollow3D")
					path = v.get_node(^"../Path3D")


					assert(path_follow)
					assert(path)

					# snap pieces into place
					

					#var local_vec = global_position - path.global_position
					#
					#var offset = path.curve.get_closest_offset(local_vec)
					#var length = path.curve.get_baked_length()
					#
					# path_follow.progress = 0
					
					#No
					#reparent(path_follow)

					# todo change cam angle
					
					# don't execute the rest of the function
					return true

	return false





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





func handle_controls(delta):
	var input := Vector3.ZERO
	
	input.x = Input.get_axis("move_left", "move_right")
	input.z = Input.get_axis("move_forward", "move_back")
	
	var camera_angle = Basis.looking_at(camera.world_angle)
	input = -(camera_angle * input)
	
	if input.length() > 1:
		input = input.normalized()
	
	movement_velocity = input * movement_speed * delta
	
	if Input.is_action_just_pressed("jump"):
		if jump_single or jump_double:
			jump()
	
	if Input.is_action_just_pressed("action_1"):
		spawn_tree()
		

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


func collect_coin():
	coins += 1
	coin_collected.emit(coins)



@onready var marker_original_pos = marker.position

func spawn_tree():
	marker.visible = true
	marker.top_level = true
	
	marker.get_node("Area3D").connect('body_exited', is_player)
	

func is_player(body):
	marker.get_node("Area3D").disconnect('body_exited', is_player)

	if body == self:
		await get_tree().create_timer(1).timeout

		spawn_tree_real(marker.global_position)
		
		marker.visible = false
		marker.top_level = false
		marker.position = marker_original_pos
		


func spawn_tree_real(p: Vector3):

	
	#return
	
	var tree: TreeObject = tree_scene.instantiate()
	get_parent().add_child(tree)
	
	await tree.done_readying
	
	
	print('done2')
	#tree.global_position = p
	
	get_tree().create_tween().tween_property(tree, "global_position", p, 3)
	


