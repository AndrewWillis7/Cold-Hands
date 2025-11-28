# player
extends CharacterBody3D

@export var speed := 4.0
@export var gravity := 20.0

@export var has_friction := true
@export var friction_strength := 30.0

@export var aim_assist_strength := 0.5
var cone_aim_dir := Vector3.FORWARD  # smooth rotation direction
@export var aim_smoothness := 15.0   # higher = faster rotation


@onready var state_machine = $"../PlayerStateMachine"
@onready var input_controller = preload("res://src/input_abstraction.gd").new()

# Character Sprite work

@onready var character_sprite: AnimatedSprite3D = $skinSprite
@onready var shirt_sprite: AnimatedSprite3D = $shirtSprite
@onready var shadow = $Shadow
@onready var weapon_sprite: Sprite3D = $weaponSprite

# Combat
@onready var danger_zone: Area3D = $DangerZone
var enemies_in_range: int = 0

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

# Signals
signal combat_ready
signal combat_over

func _on_interactable_in_range(interactable, text):
	current_interactable = interactable
	print(text)

func _on_interactable_out_of_range(interactable):
	if current_interactable == interactable:
		current_interactable = null

# onready
func _ready() -> void:
	danger_zone.body_entered.connect(_on_danger_zone_entered)
	danger_zone.body_exited.connect(_on_danger_zone_exited)

	$Sky.visible = true

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
		
	if Input.is_action_just_pressed("shoot") and (state_machine.current_combat_state != state_machine.CombatState.NONE):
		shoot()

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
			var foot_scaler := 0.5 if state_machine.current_combat_state == state_machine.CombatState.AIMING else 1.0
			footstep_timer = footstep_cooldown / foot_scaler
	
	# Cursor Controls
	get_node("../Cursor").attacking = (state_machine.current_combat_state == state_machine.CombatState.AIMING)
	
	gun_active_aim()

func play_new_anim(animation_name: String):
	var anim_speed := 0.5 if state_machine.current_combat_state == state_machine.CombatState.AIMING else 1.0
	character_sprite.speed_scale = anim_speed
	shirt_sprite.speed_scale = anim_speed
	
	character_sprite.play(animation_name)
	shirt_sprite.play(animation_name)


func move_character(delta):
	var input_dir = input_controller.get_move_input()
	var direction = (transform.basis.x * input_dir.x) + (transform.basis.z * input_dir.y)
	direction.y = 0
	direction = -direction.normalized()
	
	if direction != Vector3.ZERO:
		# Character is moving
		var realSpeed = speed if state_machine.current_combat_state != state_machine.CombatState.AIMING else speed / 2; 
		velocity.x = direction.x * realSpeed
		velocity.z = direction.z * realSpeed
		
				# Determine move direction for animation
		if abs(input_dir.y) > abs(input_dir.x):
			if input_dir.y > 0:
				move_state = MoveDirection.FORWARD
				play_new_anim("walkForward")
				weapon_sprite.position.z = 0.1
				weapon_sprite.position.y = 1.5
			else:
				move_state = MoveDirection.BACKWARD
				play_new_anim("walkBackward")
				weapon_sprite.position.z = -0.1
				weapon_sprite.position.y = 1.5
		else:
			if input_dir.x > 0:
				move_state = MoveDirection.RIGHT
				character_sprite.flip_h = true
				shirt_sprite.flip_h = true
				weapon_sprite.position.y = -50
				play_new_anim("walkRight")
			else:
				move_state = MoveDirection.LEFT
				character_sprite.flip_h = false
				shirt_sprite.flip_h = false
				weapon_sprite.position.y = -50

				play_new_anim("walkRight")
	else:
		move_state = MoveDirection.IDLE
		play_new_anim("standForward")
		weapon_sprite.position.z = 0.1
		weapon_sprite.position.y = 1.5
		
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

# Combat Stuff 

func get_joystick_aim_vector() -> Vector2:
	# Raw axis read
	var x = Input.get_action_strength("aim_right")
	var y = Input.get_action_strength("aim_up")  # DO NOT invert here
	
	# Most controllers report up as NEGATIVE Y
	# so when player pushes stick up, y becomes -1.
	# Fix that by inverting AFTER reading:
	y = -y

	var v = Vector2(x, y)

	# Deadzone
	var deadzone := 0.25
	if v.length() < deadzone:
		return Vector2.ZERO

	return v.normalized()


func joystick_vector_to_world_point(dir: Vector2) -> Vector3:
	if dir == Vector2.ZERO:
		return global_position  # no aim

	# var cam := get_viewport().get_camera_3d()

	# Project forward from player in joystick direction
	var forward = Vector3(dir.x, 0, dir.y)

	# Place aim target several meters away
	return global_position + forward.normalized() * 20.0


func gun_active_aim():
	var in_combat = (state_machine.current_combat_state != state_machine.CombatState.NONE)
	$AimCone.visible = in_combat
	if not in_combat:
		return

	# Read joystick
	var stick = get_joystick_aim_vector()
	var target_point: Vector3

	if stick != Vector2.ZERO:
		target_point = joystick_vector_to_world_point(stick)
	else:
		target_point = get_aim_target()

	# Smooth aim
	var desired_dir = (target_point - global_position)
	desired_dir.y = 0
	desired_dir = desired_dir.normalized()

	# This smooths rotation and stops jitter
	cone_aim_dir = cone_aim_dir.slerp(desired_dir, get_process_delta_time() * aim_smoothness)

	# Finally rotate cone
	$AimCone.point_towards(global_position + cone_aim_dir * 10.0)



func shoot():
	var aim_point = get_aim_target()
	var aim_dir = (aim_point - global_position).normalized()
	var hit_enemies = $AimCone.enemies_in_aim_cone(global_position, aim_dir, $AimCone.distance, $AimCone.angle_degrees)
	print("Shot!", hit_enemies)
	for e in hit_enemies:
		e.take_damage(1)


func _on_danger_zone_entered(body):
	if body.is_in_group("enemy"):
		enemies_in_range += 1

		# First enemy entering starts combat
		if enemies_in_range == 1:
			emit_signal("combat_ready")
			# Optional: notify your state machine
			state_machine.enter_combat_mode()


func _on_danger_zone_exited(body):
	if body.is_in_group("enemy"):
		enemies_in_range = max(0, enemies_in_range - 1)

		# If all enemies are gone, end combat
		if enemies_in_range == 0:
			emit_signal("combat_over")
			state_machine.exit_combat_mode()

func get_mouse_world_point() -> Vector3:
	var vp = get_viewport()
	var cam = vp.get_camera_3d()

	var mouse_pos = vp.get_mouse_position()
	var from = cam.project_ray_origin(mouse_pos)
	var dir = cam.project_ray_normal(mouse_pos)

	# intersect with world plane y = global_position.y (player's height)
	var t = (global_position.y - from.y) / dir.y
	return from + dir * t


func get_aim_target() -> Vector3:
	var stick = get_joystick_aim_vector()

	# -------------------------
	# Joystick overrides mouse
	# -------------------------
	if stick != Vector2.ZERO:
		return joystick_vector_to_world_point(stick)

	# -------------------------
	# Otherwise use mouse aim
	# -------------------------
	var mouse_aim = get_mouse_world_point()
	var best_target = null
	var best_dist = 999.0

	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not (enemy is BaseEnemy):
			continue
		if enemy.state == enemy.State.DEAD:
			continue
		
		var to_enemy = enemy.global_position - global_position
		to_enemy.y = 0
		
		var dist = to_enemy.length()
		if dist > 10.0:
			continue
		
		var mouse_dir = (mouse_aim - global_position).normalized()
		var enemy_dir = to_enemy.normalized()
		
		var dot = mouse_dir.dot(enemy_dir)
		
		if dot > 0.85 and dist < best_dist:
			best_dist = dist
			best_target = enemy
	
	if best_target:
		return best_target.global_position.lerp(mouse_aim, aim_assist_strength)

	return mouse_aim
