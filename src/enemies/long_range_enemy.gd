extends BaseEnemy
class_name LongRangeEnemy

@export var shoot_range := 10.0

func chase_state(_delta):
	if not player:
		return
	
	var dist = global_position.distance_to(player.global_position)
	
	#if too close then run
	if dist < retreat_range:
		state = State.RETREAT
		return
	
	# if far enough, shoot
	if dist <= shoot_range:
		state = State.ATTACK
		return
	
	# Otherwise move closer until preferred distance
	move_towards(player.global_position, speed)

func retreat_state(_delta):
	if not player:
		return
	
	var dist = global_position.distance_to(player.global_position)
	
	# if we restored enough distance, shoot again
	if dist > preferred_range:
		state = State.ATTACK
		return
	
	move_away_from(player.global_position, speed * 1.5)

func attack_state(_delta):
	if attack_timer == 0:
		shoot_projectile()
		attack_timer = attack_cooldown
	
	# If too close, then flee
	var dist = global_position.distance_to(player.global_position)
	if dist < retreat_range:
		state = State.RETREAT
	else:
		state = State.CHASE

func shoot_projectile():
	print("A long-range enemy shoots a projectile!")
