extends Node
# Cursor Code

@onready var reticle = $reticle
@onready var mainCursor = $mainCursor

@export var lerp_speed := 20.0
@export var aim_speed := 5.0

@export var attacking = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# hide the System Cursor (with mobile fallback
	if OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	mainCursor.play("default")
	reticle.play("default")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	reticle.visible = attacking
	
	var target = get_viewport().get_mouse_position()
	mainCursor.position = mainCursor.position.lerp(target, delta * lerp_speed)
	reticle.position = reticle.position.lerp(target, delta * aim_speed)

func set_cursor_state(state: String):
	mainCursor.play(state)
	

func set_combat_mode(state: bool):
	attacking = state
