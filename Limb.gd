class_name LimbObject
extends Node3D

@onready var path = $Path3D
@onready var collision_shape = $Area3D/CollisionShape3D



func setup():
	var min_z = 1000000
	var max_z = -1000000
	var min_x = 1000000
	var max_x = -1000000
	
	var points: PackedVector3Array = path.curve.get_baked_points()
	
	for p in points:
		if p.z < min_z:
			min_z = p.z
		if p.z > max_z:
			max_z = p.z
		if p.x < min_x:
			min_x = p.x
		if p.x > max_x:
			max_x = p.x
	
	collision_shape.shape.size = Vector3(
		abs(min_x - max_x), 
		10, 
		abs(min_z - max_z)
	)
