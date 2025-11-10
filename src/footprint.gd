extends Node3D

@export var lifetime := 3.0
var timer := 0.0
@onready var sprite: Sprite3D = $Sprite

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	timer += delta
	sprite.modulate.a = 1.0 - (timer / lifetime)
	if timer >= lifetime:
		queue_free()
