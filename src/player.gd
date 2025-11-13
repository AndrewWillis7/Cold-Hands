# player
extends CharacterBody3D

@export var speed := 4.0
@export var gravity := 20.0

@export var has_friction := true
@export var friction_strength := 20.0

@onready var state_machine = $"../PlayerStateMachine"
@onready var input_controller = preload("res://src/input_abstraction.gd").new()

# Character Sprite work

@onready var Head = $Head
@onready var character_sprite: AnimatedSprite3D = $skinSprite
@onready var shirt_sprite: AnimatedSprite3D = $shirtSprite
@onready var shadow = $Shadow

# Footprints
@onready var footprint_scene = preload("res://Scenes/footprints.tscn")
var last_foot_pos = Vector3.ZERO
var step_dist = 1.2 # distance before next footprint
@export var footstep_cooldown := 0.45 # seconds between steps
var footstep_timer := 0.0

# Sounds
@onready var audio_stream = $AudioStreamPlayer3D
var snow_Footstep_sound = preload("res://lib/sounds/SnowCrunch.wav")

# Interactions
var current_interactable: Area3D = null

func _on_interactable_in_range(interactable, text):
	current_interactable = interactable
	print(text)

func _on_interactable_out_of_range(interactable):
	if current_interactable == interactable:
		current_interactable = null

# onready
func _ready() -> void:
	for interactable in get_tree().get_nodes_in_group("interactables"):
		interactable.connect("player_in_range", Callable(self, "_on_interactable_in_range"))
		interactable.connect("player_out_of_range", Callable(self, "_on_interactable_out_of_range"))

# Move System
enum MoveDirection {
	IDLE,
	FORWARD,
	BACKWARD,
	LEFT,
	RIGHT
}
var move_state: MoveDirection = MoveDirection.IDLE

func _physics_process(delta: float) -> void:
	# update timer
	if footstep_timer > 0.0:
		footstep_timer = max(0.0, footstep_timer - delta)
	
	# Checks for changes in input
	state_machine.update_state(delta)
	
	# Moves the character based on input
	move_character(delta)
	
	# Changes the rendering based on movement/input
	render(delta)
	
	if Input.is_action_just_pressed("interact") and current_interactable:
		current_interactable.interact()

func trigger_footstep():
	var f = footprint_scene.instantiate()
	get_parent().add_child(f)
	f.global_position = Vector3(global_position.x, 0.25, global_position.z)
	f.rotation_degrees.y = rotation_degrees.y

	# Flip horizontally every other step
	f.scale.x = 1 if left_foot else -1
	left_foot = !left_foot
	last_foot_pos = global_position

	# Play footstep sound if not already playing
	if not audio_stream.playing:
		audio_stream.stream = snow_Footstep_sound
		audio_stream.pitch_scale = randf_range(0.95, 1.05)
		audio_stream.play()

var left_foot := true
func render(_delta):
	# footprint
	if velocity.length() > 0.1 and is_on_floor():
		if (global_position - last_foot_pos).length() > step_dist and footstep_timer <= 0.0:
			trigger_footstep()
			footstep_timer = footstep_cooldown
	
	# Head Controls
	# Head.visible = (state_machine.current_combat_state == state_machine.CombatState.AIMING)

func play_new_anim(animationName: String):
	character_sprite.play(animationName)
	shirt_sprite.play(animationName)

func move_character(delta):
	var input_dir = input_controller.get_move_input()
	var direction = (transform.basis.x * input_dir.x) + (transform.basis.z * input_dir.y)
	direction.y = 0
	direction = -direction.normalized()
	
	if direction != Vector3.ZERO:
		# Character is moving
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		
				# Determine move direction for animation
		if abs(input_dir.y) > abs(input_dir.x):
			if input_dir.y > 0:
				move_state = MoveDirection.FORWARD
				play_new_anim("walkForward")
			else:
				move_state = MoveDirection.BACKWARD
				play_new_anim("walkBackward")
		else:
			if input_dir.x > 0:
				move_state = MoveDirection.RIGHT
				character_sprite.flip_h = true
				shirt_sprite.flip_h = true
				play_new_anim("walkRight")
			else:
				move_state = MoveDirection.LEFT
				character_sprite.flip_h = false
				shirt_sprite.flip_h = false
				play_new_anim("walkRight")
	else:
		move_state = MoveDirection.IDLE
		play_new_anim("standForward")
		
		if has_friction:
			# quick deceleration for snapped stop
			velocity.x = move_toward(velocity.x, 0, friction_strength * delta)
			velocity.z = move_toward(velocity.z, 0, friction_strength * delta)
		else:
			# Slower glide for "icy" feel
			velocity.x = move_toward(velocity.x, 0, speed * delta * 0.3)
			velocity.z = move_toward(velocity.z, 0, speed * delta * 0.3)
	
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif input_controller.is_vault_pressed():
		# Vaulting
		print("Vaulted")
	
	# Debug: print the current move state
	#print(MoveDirection.keys()[move_state])
	
	move_and_slide()
