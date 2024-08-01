extends Node

@onready var player: Node3D = $/root/Main/Player


func _ready():
	var save = ResourceLoader.load("res://data/save.tres")
	
	if not save:
		save = Save.new()
		save.save_location = player.position
		ResourceSaver.save(save, "res://data/save.tres")
		
	if save:
		print(save.save_location)
		player.position = save.save_location
		


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	#print(player)
	pass


func _on_body_entered(body):
	if body == player:		
		var save = Save.new()
		save.save_location = player.position
		ResourceSaver.save(save, "res://data/save.tres")
