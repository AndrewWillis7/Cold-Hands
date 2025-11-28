extends BaseEnemy
class_name HybridEnemy

@export var aggressive_speed := 6.0
@export var min_combat_distance := 2.5   # How close the hybrid is willing to get
@export var max_attack_distance := 6.0   # When to shoot (your old attack_range)

func chase_state(_delta):
	if not player:
		return

	var dist = global_position.distance_to(player.global_position)

	# 1. Too close → back up slightly
	if dist < min_combat_distance:
		state = State.RETREAT
		return

	# 2. In firing range → shoot
	if dist <= attack_range:
		state = State.ATTACK
		return

	# 3. Otherwise → close the distance aggressively
	move_towards(player.global_position, aggressive_speed)

func attack_state(delta):
	if attack_timer == 0:
		fire_shot()
		attack_timer = attack_cooldown

	# Evaluate positioning after firing
	var dist = global_position.distance_to(player.global_position)

	if dist < min_combat_distance:
		state = State.RETREAT
	elif dist > attack_range:
		state = State.CHASE
	

func retreat_state(delta):
	if not player:
		return

	var dist = global_position.distance_to(player.global_position)

	# back up
	move_away_from(player.global_position, aggressive_speed * 0.75)

	# once we've created space → return to chase
	if dist > min_combat_distance:
		state = State.CHASE

func fire_shot():
	print("Hybrid Enemy shoots the player!")
