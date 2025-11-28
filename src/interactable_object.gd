extends Area3D

@export var prompt_text := "Press E to Interact"
@export var interaction_action := "interact"

@export var IS_PICKUP := false
@export var item_to_pickup: ItemResource

@onready var label: Label3D = $Label3D

# string can be like (cooking_menu, dialog_menu, card_game_menu, etc...)
@export var ui_type: String = "none"
@export var ui_data: Dictionary = {}

signal interacted
signal request_add_to_inventory(item)
signal player_in_range(interactable: Area3D, text: String)
signal player_out_of_range(interactable: Area3D)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)
	add_to_group("interactables")
	
	label.visible = false
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.text = prompt_text

func _on_body_entered(body):
	if body.is_in_group("player"):
		label.visible = true
		player_in_range.emit(self, prompt_text)

func _on_body_exited(body):
	if body.is_in_group("player"):
		label.visible = false
		player_out_of_range.emit(self)

func interact():
	if not IS_PICKUP:
		print("Interacted with object: ", name)
		interacted.emit(ui_type, ui_data)
		
	if IS_PICKUP and (item_to_pickup != null):
		emit_signal("request_add_to_inventory", item_to_pickup)
		print("Attempt to Pickup item")
