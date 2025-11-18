extends Control

@export var inventory_data: InventoryData
@export var cell_size := 48

var held_item: ItemResource = null
var holding_rotated := false
var drag_sprite

func _ready() -> void:
	drag_sprite = $DragPreviewSprite
	drag_sprite.visible = false
	draw_grid()

func draw_grid():
	var grid = $GridContainer
	grid.columns = inventory_data.cols
	for child in grid.get_children():
		child.queue_free()
	
	for y in range(inventory_data.rows):
		for x in range(inventory_data.cols):
			var cell = TextureRect.new()
			cell.modulate = Color(0.8, 0.8, 0.8)
			
			cell.mouse_filter = Control.MOUSE_FILTER_PASS
			cell.connect("gui_input", Callable(self, "_on_cell_input").bind(x, y))
			
			var item = inventory_data.grid[y][x]
			if item != null:
				cell.texture = item.icon
				cell.modulate = Color.WHITE
				
			grid.add_child(cell)

func _on_cell_input(event, x, y):
	if event is InputEventMouseButton and event.pressed:
		if held_item == null:
			var item = inventory_data.grid[y][x]
			if item:
				# pick item up
				inventory_data.clear_item(item)
				held_item = item
				drag_sprite.texture = item.icon
				drag_sprite.visible = true
		else:
			# Try to place item
			if inventory_data.can_place(held_item, y, x, holding_rotated):
				inventory_data.place(held_item, y, x, holding_rotated)
				held_item = null
				drag_sprite.visible = false
				draw_grid()

func _process(_delta: float) -> void:
	if held_item:
		drag_sprite.global_position = get_global_mouse_position() - Vector2(cell_size/2.0, cell_size/2.0)
	
	if Input.is_action_just_pressed("rotate_item") and held_item:
		holding_rotated = !holding_rotated
