class_name TreeObject
extends Node3D

# todo
# make this asyncronous somehow
# prevent too sharply bends in the ropse



# r refers to distance in world space between final points
# lower distanc w/ same # of cells means fewer final points

const r = 3
const k = 10

const cell_size = r / sqrt(2)

var w_cells: int
var h_cells: int
var d_cells: int

var x_hextents: float
var y_hextents: float
var z_hextents: float


class Leaf:
	var position: Vector3
	var connections: Array[Leaf]

var leafs_packed: Array[Leaf] = []
var structure_root_s: Leaf = null


@onready var tree_root_helper: Node3D = $TreeRootHelper



@export_category('opts')
@export var make_leafs: bool = true
@export var make_limbs: bool = true

@export_category('scenes')
@export var leaf_mesh: Mesh
@export var limb_scene: PackedScene





func from_spherical_annulus_around(p: Vector3):
	#var x = randf() - 0.5
	#var y = randf() - 0.5
	#var z = randf() - 0.5
	
	var x = randfn(0, 1)
	var y = randfn(0, 1)
	var z = randfn(0, 1)
	
	var radius = randf_range(r, 2*r)
	return p + Vector3(x, y, z).normalized() * radius

func not_within_bounds(p: Vector3):
	if p.x < 0: return true
	if p.x > x_hextents: return true
	if p.y < 0: return true
	if p.y > y_hextents: return true
	if p.z < 0: return true
	if p.z > z_hextents: return true
	
	for a: AABB in do_not_build_space:
		if a.has_point(p):
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
					if q.position.distance_to(p) < r:
						return true
	
	return false
	

func insert_to_cell_grid(grid: Array, l: Leaf):
	var c_x = floor(l.position.x / cell_size)
	var c_y = floor(l.position.y / cell_size)
	var c_z = floor(l.position.z / cell_size)
	
	grid[c_x][c_y][c_z] = l


func depth_of_tree(leaf: Leaf):
	if not leaf:
		return 0
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




func build():
	
	w_cells = 10
	h_cells = 10
	d_cells = 10
	
	# x_hextents = (w_cells * cell_size) / 2
	# y_hextents = (h_cells * cell_size) / 2
	# z_hextents = (d_cells * cell_size) / 2
	
	x_hextents = (w_cells * cell_size)
	y_hextents = (h_cells * cell_size)
	z_hextents = (d_cells * cell_size)
	
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

	s.position = tree_root_helper.transform.origin

	if not_within_bounds(s.position):
		
		# higlight built in funcs

		printerr('first node is excluded from growing area...')
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
			
	structure_root_s = s
	return s
	



var do_not_build_space = []
@onready var mm_instance = $MultiMeshInstance3D


func _ready():
	
	
	var siblings = get_parent().get_children()
	
	for s in siblings:
		if s.is_in_group('DoNotBuild'):
			var o = s.get_aabb()
			# limitation of aabb
			print(o)
			
			do_not_build_space.append(AABB(s.position + o.position, o.size))
	
	#do_not_build_space.append($TreeSizeHelper.get_aabb())


	var s = build()
	
	if not s:
		printerr("huhh")
		return null
	
	
	# change shape but...
	# have the start node be predictable still
	
	
	#for l in leafs_packed:
		#var factor = (l.position.y / y_hextents)
		#factor = factor ** 3
		#
		#l.position.y = y_hextents * (1.0 - factor)

	
	print(global_position)
	print(tree_root_helper.position)
	print(s.position)
	
	if make_leafs:
		var mm: MultiMesh = MultiMesh.new()
		
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.instance_count = leafs_packed.size()
		mm.visible_instance_count = leafs_packed.size()
		mm.mesh = leaf_mesh
		
		mm_instance.multimesh = mm
		
		# as added
		# each position relative to ... zero
		mm_instance.position = Vector3.ZERO 
		
		
		var y_space = y_hextents
		
		
		for i: int in leafs_packed.size():
			var l: Leaf = leafs_packed[i] 
			
			#mm.set_instance_transform(i, Transform3D(Basis().rotated(Vector3.UP, randf_range(0, 6)), l.position))
			mm.set_instance_transform(i, Transform3D(Basis(), l.position))
			
			

			var v = Tween.interpolate_value(
				0.0,
				0.1,
				i,
				leafs_packed.size(),
				Tween.TRANS_BACK,
				Tween.EASE_IN, 
			)
			
			await get_tree().create_timer(v).timeout
	
	
	
	if not make_limbs:
		return
	
	
	var longest_pl = depth_of_tree_get_line(s)
	var curve = get_curve(longest_pl.line)
	
	print(curve.get_point_position(0))
	
	var limb = limb_scene.instantiate()
	add_child(limb)
	limb.position = Vector3.ZERO
	limb.get_node("Path3D").curve = curve
	
	
	print('done1')
	done_readying.emit()

signal done_readying




func _on_button_pressed():
	get_tree().reload_current_scene()
