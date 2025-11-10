extends Camera3D

@export var follow_target: NodePath
@export var default_offset := Vector3(0, 3, -10)
@export var aim_offset := Vector3(0, 12, -1) # higher & directly above for top-down
@export var smooth_speed := 10.0

var target: Node3D
var current_offset := Vector3.ZERO

@onready var state_machine = $"../../PlayerStateMachine"

func _ready() -> void:
	target = $"../../CharacterBody3D"
	current_offset = default_offset

func _process(delta: float) -> void:
	if not target:
		return

	# --- Access player's state machine
	if state_machine:
		var aiming = state_machine.current_combat_state == state_machine.CombatState.AIMING
		var desired_offset = aim_offset if aiming else default_offset
		current_offset = current_offset.lerp(desired_offset, delta * smooth_speed)

	# --- Follow the player with smoothed offset
	var desired_position = target.global_transform.origin + current_offset
	global_transform.origin = global_transform.origin.lerp(desired_position, delta * smooth_speed)

	# --- Always look at player
	look_at(target.global_transform.origin, Vector3.UP)
