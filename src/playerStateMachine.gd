extends Node

enum State {IDLE, MOVE, VAULT}
enum CombatState {NONE, SHOOTING, AIMING}

var current_state = State.IDLE
var current_combat_state = CombatState.NONE

@onready var player = $"../CharacterBody3D"

func update_state(delta):
	var combat_input = player.input_controller.get_combat_input()
	update_combat_state(combat_input)
	
	match current_state:
		State.IDLE:
			idle_state(delta)
		State.MOVE:
			move_state(delta)
		_:
			push_error("Unknown state: %s" % str(current_state))

func update_combat_state(combat_input: Dictionary) -> void:
	if combat_input["shoot"]:
		current_combat_state = CombatState.SHOOTING
	elif combat_input["aim"]:
		current_combat_state = CombatState.AIMING
	else:
		current_combat_state = CombatState.NONE

func idle_state(_delta):
	var input_dir = player.input_controller.get_move_input()
	if input_dir.length() > 0.1:
		current_state = State.MOVE

func move_state(_delta):
	var input_dir = player.input_controller.get_move_input()
	if input_dir.length() < 0.1:
		current_state = State.IDLE
