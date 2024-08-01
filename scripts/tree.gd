@tool
class_name TreeObject
extends Node3D

# todo
# make this asyncronous somehow
# prevent too sharply bends in the ropse


#------------


# r refers to distance in world space between final points
# lower distanc w/ same # of cells means fewer final points

# controls density of the tree

@export var r_distance: float = 3:
	set(value):
		r_distance = value
		if Engine.is_editor_hint():
			build()

const k = 10

var cell_size = r_distance / sqrt(2)

# size in cells of the final tree
# controls size of tree

@export var w_cells: int = 10
@export var h_cells: int = 10
@export var d_cells: int = 10

#@onready var x_hextents: float = (w_cells * cell_size)
#@onready var y_hextents: float = (h_cells * cell_size)
#@onready var z_hextents: float = (d_cells * cell_size)

var x_hextents: float = (w_cells * cell_size)
var y_hextents: float = (h_cells * cell_size)
var z_hextents: float = (d_cells * cell_size)


class Leaf:
	var position: Vector3
	var connections: Array[Leaf]


#--------------------------------


@onready var tree_root_helper: Node3D = $TreeRootHelper



@export_category('opts')
@export var make_leafs: bool = true
@export var make_limbs: bool = true
@export var time_for_leafs: float 
@export var rotate_leafs: bool
@export var root_pos: Vector3:
	set(value):
		# node.. loaded in tool mode?
		if Engine.is_editor_hint():
			tree_root_helper.position = value
			root_pos = value

const prune_lev = 0

@export_category('scenes')
@export var leaf_mesh: Mesh
@export var limb_scene: PackedScene
@export var build_button: bool = false:
	set(value):
		build_button = false
		if Engine.is_editor_hint():
			build()





func from_spherical_annulus_around(p: Vector3):
	#var x = randf() - 0.5
	#var y = randf() - 0.5
	#var z = randf() - 0.5
	
	var x = randfn(0, 1)
	var y = randfn(0, 1)
	var z = randfn(0, 1)
	
	var radius = randf_range(r_distance, 2*r_distance)
	return p + Vector3(x, y, z).normalized() * radius


func not_within_bounds(p: Vector3): # p is relative to parent
	if p.x < 0: return true
	if p.x > x_hextents: return true
	if p.y < 0: return true
	if p.y > y_hextents: return true
	if p.z < 0: return true
	if p.z > z_hextents: return true

	var globally_positioned_point = global_position + p

	for a: AABB in do_not_build_space:
		if a.has_point(globally_positioned_point):
			return true

func is_within_distance_r_of_existing(grid: Array, p: Vector3):
	var cell_x = floor(p.x / cell_size)
	var cell_y = floor(p.y / cell_size)
	var cell_z = floor(p.z / cell_size)
	
	for c_x in range(max(cell_x - 2, 0), min(cell_x + 3, w_cells)):
		for c_y in range(max(cell_y - 2, 0), min(cell_y + 3, h_cells)):
			for c_z in range(max(cell_z - 2, 0), min(cell_z + 3, d_cells)):
				var q = grid[c_x][c_y][c_z]
				if q:
					# hm
					if q.position.distance_to(p) < r_distance:
						return true
	
	return false
	

func insert_to_cell_grid(grid: Array, l: Leaf):
	var c_x = floor(l.position.x / cell_size)
	var c_y = floor(l.position.y / cell_size)
	var c_z = floor(l.position.z / cell_size)
	
	grid[c_x][c_y][c_z] = l


func depth_of_tree(leaf: Leaf):
	var maxdepth = 0
	for l in leaf.connections:
		maxdepth = max(maxdepth, depth_of_tree(l))
	return maxdepth + 1

func sort(a, b):
	if a[1] > b[1]:
		return true
	return false

func depth_of_tree_get_line(ll: Leaf):
	var line: PackedVector3Array = []
	var extras: Array[Leaf] = []
	
	while true:
		line.append(ll.position)
		
		var depths = ll.connections.map(func(l): return [l, depth_of_tree(l)])
	
		if depths.size() == 0:
			break
		
		depths.sort_custom(sort)
		
		ll = depths[0][0]
		
		if depths.size() > 1:
			extras.append(depths[1][0])
			pass
			
	return {line = line, extras = extras}
	

func get_curve(polyline: PackedVector3Array):
	var curve: Curve3D = Curve3D.new()
	
	for i in polyline.size():
		if i == 0:
			curve.add_point(polyline[i])
			continue
		if i == polyline.size() - 1:
			curve.add_point(polyline[i])
			continue
		
		var current = polyline[i]
		var next = polyline[i + 1]
		var pos = ((next - current) / 2) + current
		curve.add_point(pos, (current - pos), (next - pos))

	return curve


func prune(list: Array[Leaf], leaf: Leaf):
	var maxdepth = 0
	
	for l in leaf.connections:
		maxdepth = max(maxdepth, prune(list, l))
	
	if maxdepth > prune_lev: # set up
		list.append(leaf)
		
	return maxdepth + 1





func build_data():

	# check if necessary
	x_hextents = (w_cells * cell_size)
	y_hextents = (h_cells * cell_size)
	z_hextents = (d_cells * cell_size)


	# shoud I return this?
	var leafs_packed: Array[Leaf] = []

	
	# type this for real
	var grid = []
	var active_list: Array[Leaf] = []

	for x in w_cells:
		grid.append([])
		for y in h_cells:
			grid[x].append([])
			for z in d_cells:
				grid[x][y].append(null)
	
	var s = Leaf.new()

	# check this exists

	# s.position = tree_root_helper.transform.origin

	s.position = $TreeRootHelper.transform.origin

	if not_within_bounds(s.position):
		printerr('first node {0} is excluded from growing area... '.format([s.position]))
		return null

	insert_to_cell_grid(grid, s)
	active_list.append(s)
	leafs_packed.append(s)
	
	while not active_list.is_empty():
		var i = randi() % active_list.size()
		var x_i = active_list[i]
		var x_i_position = x_i.position
		
		var no_such_point_found = false
		
		for _i in k:
			var q_position = from_spherical_annulus_around(x_i_position)
			
			if not_within_bounds(q_position):
				no_such_point_found = true
				continue
			
			if is_within_distance_r_of_existing(grid, q_position):
				no_such_point_found = true
				continue
			
			var q = Leaf.new()
			q.position = q_position
			
			insert_to_cell_grid(grid, q)
			active_list.append(q)
			leafs_packed.append(q)
						
			x_i.connections.append(q)
			
		if no_such_point_found:
			active_list.pop_at(i)

	return s
	



# globally positioned boxes
var do_not_build_space = []

@onready var mm_instance = $MultiMeshInstance3D


func update_build_space():
	for node in get_parent().get_children():
		if node is DoNotBuild:
			do_not_build_space.append(node.get_aabb())

static func is_in_build_space(n: Node, global_point: Vector3):
	#var sp: Array[AABB] = []

	for node in n.get_parent().get_children():
		if node is DoNotBuild:
			if node.get_aabb().has_point(global_point):
				return true
			#sp.append(node.get_aabb())
	
	return false


func build():
	# remove limbs
	for node: Node in get_children():
		if node.has_node('Path3D'):
			node.free()

	update_build_space()

	var s = build_data()

	if not s:
		Audio.play("res://sounds/jump.ogg")
		return null

	var some_leafs: Array[Leaf] = [] 

	prune(some_leafs, s)

	# change shape but...
	# have the start node be predictable still

	
	if make_leafs:
		var mm: MultiMesh = MultiMesh.new()
		
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.instance_count = some_leafs.size()
		mm.visible_instance_count = some_leafs.size()
		mm.mesh = leaf_mesh
		
		mm_instance.multimesh = mm
		mm_instance.position = Vector3.ZERO 
						
		for i: int in some_leafs.size():
			var l: Leaf = some_leafs[i] 
			
			var bas
			if rotate_leafs:
				bas = Basis().rotated(Vector3.UP, randf_range(0, 6))
			else:
				bas = Basis()

			mm.set_instance_transform(i, Transform3D(bas, l.position))
			
			var v = Tween.interpolate_value(
				0.0,
				#0.1,
				time_for_leafs,
				i,
				some_leafs.size(),
				Tween.TRANS_BACK,
				Tween.EASE_IN, 
			)
			
			await get_tree().create_timer(v).timeout
	
	if make_limbs:
		var limb: LimbObject = limb_scene.instantiate()
		
		var longest_pl = depth_of_tree_get_line(s)
		var curve = get_curve(longest_pl.line)
		
		add_child(limb)
		limb.get_node(^"Path3D").curve = curve
		
