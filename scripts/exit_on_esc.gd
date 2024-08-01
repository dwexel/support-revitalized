extends Node3D

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

func _ready():
	# refresh the tree node
	# todo should be called treee ndoe
	var tree: TreeObject = $Tree
	remove_child(tree)
	
