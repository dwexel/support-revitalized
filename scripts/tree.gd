class_name TreeObject
extends Node3D

# r refers to distance in world space between final points
# lower distanc w/ same # of cells means fewer final points

const r = 3
const k = 30

const cell_size = r / sqrt(2)

var w_cells: int
var h_cells: int
var d_cells: int

var x_hextents
var y_hextents
var z_hextents

var grid = []
var active_list: Array[Leaf] = []

class Leaf:
	var position: Vector3
	var connections: Array[Leaf]

var lines_packed: PackedVector3Array = []
var leafs_packed: Array[Leaf] = []


var mm: MultiMesh = MultiMesh.new()
var mm_instance: MultiMeshInstance3D = MultiMeshInstance3D.new()


@onready var tree_root_helper: Node3D = $TreeRootHelper
@onready var tree_size_helper: Node3D = $TreeSizeHelper


@export_category('opts')
@export var make_leafs: bool = true
@export var make_limbs: bool = true

@export_category('scenes')
@export var leaf_mesh: Mesh
@export var limb_scene: PackedScene

signal done_adding_in




func _ready():
	
	w_cells = 10
	h_cells = 10
	d_cells = 10
	
	x_hextents = (w_cells * cell_size) / 2
	y_hextents = (h_cells * cell_size) / 2
	z_hextents = (d_cells * cell_size) / 2
	
	prints(x_hextents, y_hextents, z_hextents)
	
	#grid.clear()
	#active_list.clear()
	#lines_packed.clear()
	#leafs_packed.clear()
	
	for x in w_cells:
		grid.append([])
		for y in h_cells:
			grid[x].append([])
			for z in d_cells:
				grid[x][y].append(null)
	
	var s = Leaf.new()

	#s.position = Vector3(x_hextents/2, y_hextents/2, z_hextents/2)
	s.position = tree_root_helper.transform.origin

	if not_within_bounds(s.position):
		printerr('first node is excluded from growing area...')

	#print(s.position)

	add_to_cell_grid(s)
	leafs_packed.append(s)
	active_list.append(s)
	
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
			
			if is_within_distance_r_of_existing(q_position):
				no_such_point_found = true
				continue
			
			var q = Leaf.new()
			q.position = q_position
			
			add_to_cell_grid(q)
			active_list.append(q)
			leafs_packed.append(q)
			
			lines_packed.append(x_i.position)
			lines_packed.append(q.position)
			
			x_i.connections.append(q)
			
		if no_such_point_found:
			active_list.pop_at(i)
			
	
	# instantiate visible parts
	if make_leafs:
		#mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.instance_count = leafs_packed.size()
		mm.visible_instance_count = leafs_packed.size()
		mm.mesh = leaf_mesh
		#mm.mesh = BoxMesh.new()
		#mm.mesh.size = Vector3(0.5, 0.5, 0.5)
		
		#remove_child(mm_instance)
		
		#mm_instance = MultiMeshInstance3D.new()
		
		mm_instance.multimesh = mm
		mm_instance.position = Vector3.ZERO
		add_child(mm_instance)
		
		for i: int in leafs_packed.size():

			var l: Leaf = leafs_packed[i] 
			mm.set_instance_transform(i, Transform3D(Basis(), l.position))

			var v = Tween.interpolate_value(
				0.0,
				0.1,
				i,
				leafs_packed.size(),
				Tween.TRANS_LINEAR,
				Tween.EASE_IN, 
				)
			
			await get_tree().create_timer(v).timeout
	
	if make_limbs:
		#var d = depth_of_tree(s)
		var pl = depth_of_tree_get_line(s)
		var curve = get_curve(pl.line)
		
		var limb: LimbObject = limb_scene.instantiate()
		add_child(limb)
		#limb.position = tree_root_helper.position
		#limb.global_position = tree_root_helper.global_position
		limb.path.curve = curve
		limb.setup()
	
	done_adding_in.emit()
	


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

func is_within_distance_r_of_existing(p: Vector3):
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
	

func add_to_cell_grid(l: Leaf):
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


func depth_of_tree_get_line(ll: Leaf):
	var line: PackedVector3Array = []
	var extras: Array[Leaf] = []
	while true:
		line.append(ll.position)
		var depths = ll.connections.map(func(l): return depth_of_tree(l))
		if depths.size() == 0:
			break
		var depths_sorted = depths.duplicate()
		depths_sorted.sort()
		if depths_sorted.size() >= 2 and depths_sorted[-2] > 4:
			# ercgh
			extras.append(ll.connections[depths.find(depths_sorted[-2])])
		# ergh
		ll = ll.connections[depths.find(depths_sorted[-1])]
		
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


