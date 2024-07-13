#extends Node3D
#
#@export_group("Properties")
#@export var target: Node
#
#@export_group("Zoom")
#@export var zoom_minimum = 16
#@export var zoom_maximum = 4
#@export var zoom_speed = 10
#
#@export_group("Rotation")
#@export var rotation_speed = 120
#
#var camera_rotation:Vector3
#var zoom = 10
#
#@onready var camera = $Camera
#
#func _ready():
	#
	#camera_rotation = rotation_degrees # Initial rotation
	#
	#pass
#
#func _physics_process(delta):
	#
	## Set position and rotation to targets
	#
	#self.position = self.position.lerp(target.position, delta * 4)
	#rotation_degrees = rotation_degrees.lerp(camera_rotation, delta * 6)
	#
	#camera.position = camera.position.lerp(Vector3(0, 0, zoom), 8 * delta)
	#
	#handle_input(delta)
#
## Handle input
#
#func handle_input(delta):
	#
	## Rotation
	#
	#var input := Vector3.ZERO
	#
	#input.y = Input.get_axis("camera_left", "camera_right")
	#input.x = Input.get_axis("camera_up", "camera_down")
	#
	#camera_rotation += input.limit_length(1.0) * rotation_speed * delta
	#camera_rotation.x = clamp(camera_rotation.x, -80, -10)
	#
	## Zooming
	#
	#zoom += Input.get_axis("zoom_in", "zoom_out") * zoom_speed * delta
	#zoom = clamp(zoom, zoom_maximum, zoom_minimum)


extends Camera3D
@export var cam_distance = 10
@onready var target_node: Node3D = get_parent()

#const camera_angle = (Vector3.UP + Vector3.BACK * sqrt(2) + Vector3.RIGHT)
#const camera_angle_flat =  (Vector3.BACK * sqrt(2) + Vector3.RIGHT)

const camera_angle = (Vector3.UP + Vector3.BACK + Vector3.RIGHT)
const camera_angle_flat =  (Vector3.BACK + Vector3.RIGHT)




func _ready():
	size = 10
	fov = 25
	projection = Camera3D.PROJECTION_ORTHOGONAL
	set_as_top_level(true)
	

func _physics_process(_delta):
	
	var target_pos: Vector3 = target_node.global_transform.origin
	var camera_target_pos = target_pos + camera_angle * cam_distance
	var camera_current_pos: Vector3 = global_transform.origin
	
	look_at_from_position(
		lerp(camera_current_pos, camera_target_pos, _delta),
		target_pos,
		Vector3.UP
	)

