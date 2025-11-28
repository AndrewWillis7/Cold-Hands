extends Node

enum State { IDLE, MOVE, VAULT }
enum CombatState { NONE, COMBAT, AIMING, SHOOTING }

var current_state = State.IDLE
var current_combat_state = CombatState.NONE

@onready var player = $"../CharacterBody3D"


func _ready():
	# Hook into the player's combat signals
	player.connect("combat_ready", Callable(self, "_on_combat_ready"))
	player.connect("combat_over", Callable(self, "_on_combat_over"))


# -------------------------
#   MAIN UPDATE
# -------------------------
func update_state(delta):
	if current_combat_state != CombatState.NONE:
		_update_combat_inputs()

	match current_state:
		State.IDLE:
			idle_state(delta)
		State.MOVE:
			move_state(delta)
		_:
			push_error("Unknown state: %s" % str(current_state))


# -------------------------
#   COMBAT INPUT LOGIC
# -------------------------
func _update_combat_inputs():
	var combat_input = player.input_controller.get_combat_input()

	# Inside combat mode: inputs can push into AIM or SHOOT
	if combat_input["shoot"]:
		current_combat_state = CombatState.SHOOTING
	elif combat_input["aim"]:
		current_combat_state = CombatState.AIMING
	else:
		# Stay in COMBAT base state until the player leaves danger zone
		current_combat_state = CombatState.COMBAT


# Called when combat bubble activates
func _on_combat_ready():
	# Enter base combat state
	current_combat_state = CombatState.COMBAT
	print("Entered Combat State")


# Called when last enemy leaves danger zone
func _on_combat_over():
	# Reset combat state fully
	current_combat_state = CombatState.NONE

func enter_combat_mode():
	current_combat_state = CombatState.COMBAT
	# Optional: reset AIM/SHOOT on first entry
	print("StateMachine: Combat mode entered")


func exit_combat_mode():
	current_combat_state = CombatState.NONE
	print("StateMachine: Combat mode exited")


# -------------------------
#   NON-COMBAT MOVEMENT STATES
# -------------------------
func idle_state(_delta):
	var input_dir = player.input_controller.get_move_input()

	if input_dir.length() > 0.1:
		current_state = State.MOVE


func move_state(_delta):
	var input_dir = player.input_controller.get_move_input()

	if input_dir.length() < 0.1:
		current_state = State.IDLE
