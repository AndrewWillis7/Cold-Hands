extends CanvasLayer

@onready var cooking_ui = $CookingUI
@onready var inventory_ui = $"../InventoryUI"
@onready var dialog_ui = $DialogBoxPopup
@onready var world_ui = $WorldUI

func hide_all_scene_nodes():
	var canvas = get_node(".") # gets self?
	if canvas:
		for node in canvas.get_children():
			if node is CanvasItem or node is Sprite2D:
				node.hide()

func open_contextual_ui(ui_type: String, ui_data: Dictionary):
	hide_all_scene_nodes()
	
	match ui_type:
		"cooking_ui":
			cooking_ui.visible = true
			cooking_ui.load_data(ui_data)
		
		"dialog_ui":
			dialog_ui.visible = true
			dialog_ui.load_data(ui_data)
			
		"inventory_ui":
			inventory_ui.visible = true
			inventory_ui.load_data(ui_data)
		
		"world_ui":
			world_ui.visible = true
			world_ui.load_data(ui_data)
			
		_:
			print("Unkown UI type:", ui_type)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	hide_all_scene_nodes()
	for interactable in get_tree().get_nodes_in_group("interactables"):
		interactable.connect("interacted", Callable(self, "open_contextual_ui"))

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("open_inventory"):
		hide_all_scene_nodes()
		print("toggled Inventory")
		inventory_ui.visible = !inventory_ui.visible
