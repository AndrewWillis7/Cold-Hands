extends Node3D
class_name AimCone

@export var angle_degrees := 45.0
@export var distance := 6.0
@export var segments := 32

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D


func _ready():
	_update_mesh()


func point_towards(world_point: Vector3):
	var to_target = world_point - global_position
	to_target.y = 0
	look_at(global_position + to_target, Vector3.UP)


func _update_mesh():
	var mesh := ImmediateMesh.new()
	mesh.clear_surfaces()

	var rad = deg_to_rad(angle_degrees)
	var half = rad / 2.0

	# Precompute all ring vertices
	var verts: Array = []
	for i in range(segments + 1):
		var t = lerp(-half, half, float(i) / segments)
		var x = sin(t) * distance
		var z = cos(t) * distance
		verts.append(Vector3(x, 0, -z))

	# Build triangles manually
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(segments):
		var center = Vector3.ZERO
		var v1 = verts[i]
		var v2 = verts[i + 1]

		# center triangle vertex
		mesh.surface_set_uv(Vector2(0, 0))
		mesh.surface_add_vertex(center)

		# vertex v1
		mesh.surface_set_uv(Vector2(v1.length() / distance, 0))
		mesh.surface_add_vertex(v1)

		# vertex v2
		mesh.surface_set_uv(Vector2(v2.length() / distance, 0))
		mesh.surface_add_vertex(v2)


	mesh.surface_end()

	mesh_instance.mesh = mesh

func set_cone_color(inner: Color, outer: Color):
	var mat = mesh_instance.get_active_material(0)
	if mat:
		mat.set("shader_parameter/inner_color", inner)
		mat.set("shader_parameter/outer_color", outer)

func update_cone_visual(has_targets: bool):
	if has_targets:
		set_cone_color(Color(1, 0.2, 0.2, 0.8), Color(1, 0.0, 0.0, 0.0))
	else:
		set_cone_color(Color(0.6, 0.6, 0.6, 0.6), Color(0.6, 0.6, 0.6, 0.0))

func enemies_in_aim_cone(origin: Vector3, aim_dir: Vector3, max_dist: float, angle_deg: float) -> Array:
	var hits = []
	var half_angle = deg_to_rad(angle_deg / 2.0)
	
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not (enemy is BaseEnemy):
			continue
		
		if enemy.state == enemy.State.DEAD:
			continue
		
		var to_enemy = enemy.global_position - origin
		to_enemy.y = 0
		var dist = to_enemy.length()
		
		if dist > max_dist:
			continue
		
		var dir_norm = to_enemy.normalized()
		var angle = acos(clamp(aim_dir.dot(dir_norm), -1.0, 1.0))
		
		if angle <= half_angle:
			hits.append(enemy)
		update_cone_visual(hits.size() > 0)
	return hits
