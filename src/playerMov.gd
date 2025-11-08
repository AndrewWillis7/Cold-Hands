# playerMov
extends CharacterBody3D

@export var speed := 5.0
@export var jump_force := 8.0
@export var gravity := 20.0

@onready var state_machine = $"../PlayerStateMachine"
@onready var input_controller = preload("res://src/input_abstraction.gd").new()

func _physics_process(delta: float) -> void:
	state_machine.update_state(delta)

func move_character(delta):
	var input_dir = input_controller.get_move_input()
	var direction = (transform.basis.x * input_dir.x) + (transform.basis.z * input_dir.y)
	direction.y = 0
	direction = direction.normalized()
	
	if direction != Vector3.ZERO:
		# Character is moving
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed * delta)
		velocity.z = move_toward(velocity.z, 0, speed * delta)
	
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif input_controller.is_vault_pressed():
		# Vaulting
		print("Vaulted")
	
	move_and_slide()
