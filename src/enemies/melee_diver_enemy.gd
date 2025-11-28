extends BaseEnemy
class_name MeleeDiverEnemy

@export var dash_speed := 8.0
@export var retreat_after_attack := 3.0
@export var retreat_speed := 4.0

func chase_state(_delta):
	if not player:
		return
	
	var dist = global_position.distance_to(player.global_position)
	
	if dist <= attack_range:
		state = State.ATTACK
		return
	
	# close fast with aggression
	move_towards(player.global_position, dash_speed)

func attack_state(_delta):
	if attack_timer == 0:
		perform_attack()
		attack_timer = attack_cooldown
		
		# Immediatly retreat after attacking
		state = State.RETREAT
		return
	
	state = State.CHASE

func retreat_state(delta):
	if not player:
		return
	
	# back away for a moment
	move_away_from(player.global_position, retreat_speed)
	
	var dist = global_position.distance_to(player.global_position)
	
	#once we've created space we can dash again
	if dist >= retreat_after_attack:
		state = State.CHASE

func perform_attack():
	print("A Melee Diver Slashes at the player!")
