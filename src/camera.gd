extends Camera3D

@export var follow_target: NodePath
@export var default_offset := Vector3(0, 3, -10)
@export var combat_offset := Vector3(0, 7, -12)  # replaces aim_offset
@export var smooth_speed := 10.0

var target: Node3D
var current_offset := Vector3.ZERO

@onready var snow_shader = $"../SnowVolume/Volume".get_surface_override_material(0)
@onready var snow_shader_hb = $"../SnowVolume"
@onready var state_machine = $"../../PlayerStateMachine"


func _ready() -> void:
	target = $"../../CharacterBody3D"
	current_offset = default_offset


func _process(delta: float) -> void:
	if not target:
		return

	# --- Read combat activity from state machine
	var combat_active = state_machine.current_combat_state != state_machine.CombatState.NONE

	# Decide camera offset based on combat mode
	var desired_offset = combat_offset if combat_active else default_offset

	# Smoothly transition
	current_offset = current_offset.lerp(desired_offset, delta * smooth_speed)

	# Follow the target
	var desired_position = target.global_transform.origin + current_offset
	global_transform.origin = desired_position

	# Look at the player
	look_at(target.global_transform.origin, Vector3.UP)
