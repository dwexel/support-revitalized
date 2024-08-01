class_name LimbObject
extends Node3D

@onready var path = $Path3D
@onready var path_follower = $Path3D/PathFollow3D

func get_thickness() -> float:
	return 1.0
