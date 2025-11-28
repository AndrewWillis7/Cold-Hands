extends BaseEnemy
class_name HybridEnemy

@export var aggressive_speed := 6.0

func chase_state(_delta):
	if not player:
		return
	
	var dist = global_position.distance_to(player.global_position)
	
	# In ranged Attack range?
	if dist <= attack_range:
		state = State.ATTACK
		return
	
	#always push forward
	move_towards(player.global_position, aggressive_speed)

func attack_state(_delta):
	if attack_timer == 0:
		fire_shot()
		attack_timer = attack_cooldown
	
	# If the player escapes, chase them again
	var dist = global_position.distance_to(player.global_position)
	if dist > attack_range:
		state = State.CHASE
	

func retreat_state(delta):
	# doesn't retreat
	move_and_slide()

func fire_shot():
	print("Hybrid Enemy shoots the player!")
