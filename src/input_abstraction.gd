# player_input
extends Node

func get_move_input() -> Vector2:
	var input = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_backwards") - Input.get_action_strength("move_forward")
	)
	#print("Input:", input)
	return input.normalized()

func is_vault_pressed() -> bool:
	return Input.is_action_just_pressed("vault")
