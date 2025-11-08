# playerStateMachine.gd
extends Node

enum State {IDLE, MOVE, VAULT}
var current_state = State.IDLE

@onready var player = $"../CharacterBody3D"

func update_state(delta):
	match current_state:
		State.IDLE:
			idle_state(delta)
		State.MOVE:
			move_state(delta)

func idle_state(delta):
	# Check for movement then swap state
	var input_dir = player.input_controller.get_move_input()
	if input_dir.length() > 0.1:
		current_state = State.MOVE

func move_state(delta):
	# Check for movement then swap state
	var input_dir = player.input_controller.get_move_input()
	if input_dir.length() < 0.1:
		current_state = State.IDLE
