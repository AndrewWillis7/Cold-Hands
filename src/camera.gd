extends Camera3D

@export var follow_target: NodePath
@export var offset := Vector3(0, 3, -10)
@export var smooth_speed := 5.0

var target

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	target = get_node(follow_target)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not target:
		return
	var desired_position = target.global_transform.origin + offset
	global_transform.origin = global_transform.origin.lerp(desired_position, delta * smooth_speed)
	look_at(target.global_transform.origin, Vector3.UP)
