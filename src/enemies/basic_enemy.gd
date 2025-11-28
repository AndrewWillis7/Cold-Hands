extends CharacterBody3D
class_name BaseEnemy

enum State {
	IDLE, # Wanders and stills
	CHASE, # Sees player, path towards
	ATTACK, # within attack range
	STAGGERED, # Hit Reactions, knockback
	RETREAT, # run away from the player
	DEAD # dead obviously
}
var state = State.IDLE

enum MoveDirection { IDLE, FORWARD, BACKWARD, LEFT, RIGHT }
var move_state: MoveDirection = MoveDirection.IDLE


# Variables
@onready var player: Node3D = get_tree().get_first_node_in_group("player")
@onready var danger_zone = $DangerZone # Detection area

# Animations
@onready var character_sprite: AnimatedSprite3D = $skinSprite
@onready var shirt_sprite: AnimatedSprite3D = $shirtSprite

@export var max_health := 10
var health := 10

@export var speed := 4.0
@export var attack_range := 1.5
@export var attack_cooldown := 1.0
@export var preferred_range := 5.0 # Preferred distance the enemy wants to be at
@export var retreat_range := 3.0 # Ranged enemies will retreat inside this

var attack_timer := 0.0
var player_in_range := false

@export var stagger_time := 0.3
var stagger_timer := 0.0 # Amount of time the enemy gets stunned for

# ------------------------
# Helper Methods
# ------------------------

func play_anim(name: String):
	character_sprite.play(name)
	shirt_sprite.play(name)

func update_movement_animation():
	var v = velocity
	v.y = 0  # ignore vertical movement

	if v.length() < 0.1:
		move_state = MoveDirection.IDLE
		play_anim("standForward")
		return

	# Determine facing based on dominant axis of movement
	if abs(v.z) > abs(v.x):
		if v.z < 0:
			move_state = MoveDirection.FORWARD
			play_anim("walkForward")
		else:
			move_state = MoveDirection.BACKWARD
			play_anim("walkBackward")
	else:
		if v.x > 0:
			move_state = MoveDirection.RIGHT
			character_sprite.flip_h = false
			shirt_sprite.flip_h = false
			play_anim("walkRight")
		else:
			move_state = MoveDirection.LEFT
			character_sprite.flip_h = true
			shirt_sprite.flip_h = true
			play_anim("walkRight")

# ------------------------
# State Handling
# ------------------------

# Sensing
func _on_detection_area_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = true
		state = State.CHASE

func _on_detection_area_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = false
		state = State.IDLE

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	danger_zone.connect("body_entered", Callable(self, "_on_detection_area_body_entered"))
	danger_zone.connect("body_exited", Callable(self, "_on_detection_area_body_exited"))
	health = max_health
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	
	velocity.y -= 9.8 * delta
	attack_timer = max(0, attack_timer - delta)
	
	# handle stagger
	if state == State.STAGGERED:
		stagger_state(delta)
		return
	
	update_movement_animation()
	
	match state:
		State.IDLE:
			idle_state(delta)
		State.CHASE:
			chase_state(delta)
		State.ATTACK:
			attack_state(delta)
		State.RETREAT:
			retreat_state(delta)

# ------------------------
# IDLE and STAGGER States
# ------------------------

func idle_state(_delta):
	velocity = Vector3.ZERO
	if player and player_in_range:
		state = State.CHASE
	move_and_slide()

func stagger_state(delta):
	stagger_timer -= delta
	
	# freeze movement
	velocity = Vector3.ZERO
	move_and_slide()
	
	if stagger_timer <= 0:
		# recover
		state = State.CHASE if player_in_range else State.IDLE

# ------------------------
# Movemement States
# ------------------------

func chase_state(_delta):
	# Overriden per enemy type
	pass

func attack_state(_delta):
	# Overriden per enemy type
	pass

func retreat_state(delta):
	# overridden per enemy type
	pass

func move_towards(target_pos, speed):
	var dir = (target_pos - global_position)
	dir.y = 0
	dir = dir.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	velocity.y = 0
	move_and_slide()

func move_away_from(target_pos, speed):
	var dir = (global_position - target_pos) # Reversed
	dir.y = 0
	dir = dir.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	velocity.y = 0
	move_and_slide()

# ------------------------
# Death and Damage States
# ------------------------
func take_damage(amount: int):
	if state == State.DEAD:
		return
	
	health -= amount
	if health <= 0:
		die()
		return
	
	# Stagger on hit
	stagger_timer = stagger_time
	state = State.STAGGERED

func die():
	state = State.DEAD
	velocity = Vector3.ZERO
	move_and_slide()
	print("Enemy is Dead!")
	# Drop loot, death anim, yada yada
