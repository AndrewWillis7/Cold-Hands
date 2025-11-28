extends Control

@export var inventory_data: InventoryData
@export var cell_size := 48

var held_item: ItemResource = null
var holding_rotated := false

var drag_sprite: Sprite2D
var hover_cell_x := -1
var hover_cell_y := -1

var original_row := -1
var original_col := -1
var original_rotated := false


func _ready() -> void:
	if inventory_data == null:
		inventory_data = InventoryData.new()

	drag_sprite = $DragPreviewSprite
	drag_sprite.visible = false
	drag_sprite.centered = true

	var test_item: ItemResource = load("res://lib/items/test_gun.tres")
	inventory_data.force_place_for_testing(test_item)

	await get_tree().process_frame
	draw_grid()

	$GridLayer.position = (get_viewport_rect().size - $GridLayer.size) / 2
	$ItemLayer.position = $GridLayer.position


# ---------------------------------------------------------
# CELL SCRIPT
# ---------------------------------------------------------

func _attach_cell_script(cell: Panel, x: int, y: int) -> void:
	var script := GDScript.new()
	script.source_code = "extends Panel
func _gui_input(event):
	get_parent().get_parent()._cell_input_router(event, %d, %d)
" % [x, y]
	script.reload()
	cell.set_script(script)


func _cell_input_router(event: InputEvent, x: int, y: int) -> void:
	if event is InputEventMouseMotion:
		hover_cell_x = x
		hover_cell_y = y

		if held_item == null:
			_clear_preview()
			_draw_hover_item_highlight(x, y)

	if event is InputEventMouseButton:
		_on_cell_input(event, x, y)


# ---------------------------------------------------------
# GRID + ITEM DRAWING
# ---------------------------------------------------------

func draw_grid() -> void:
	var grid = $GridLayer
	var item_layer = $ItemLayer

	for c in grid.get_children(): c.queue_free()
	for c in item_layer.get_children(): c.queue_free()

	grid.columns = inventory_data.cols

	for y in range(inventory_data.rows):
		for x in range(inventory_data.cols):
			var cell := Panel.new()
			cell.custom_minimum_size = Vector2(cell_size, cell_size)

			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.3, 0.3, 0.3)
			style.border_color = Color(0.15, 0.15, 0.15)
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2

			cell.add_theme_stylebox_override("panel", style)
			cell.set_meta("style", style)
			cell.mouse_filter = Control.MOUSE_FILTER_STOP

			_attach_cell_script(cell, x, y)
			grid.add_child(cell)

	_draw_items()


func _draw_items() -> void:
	var item_layer = $ItemLayer

	for y in range(inventory_data.rows):
		for x in range(inventory_data.cols):

			var cd = inventory_data.grid[y][x]
			if cd == null: continue
			if !cd["origin"]: continue

			var item: ItemResource = cd["item"]
			var rotated: bool = cd.get("rotated", false)

			# use Sprite2D
			var spr := Sprite2D.new()
			spr.texture = item.icon
			spr.centered = true

			# footprint
			var w_cells = item.size_y if rotated else item.size_x
			var h_cells = item.size_x if rotated else item.size_y

			# scale by grid cells, NOT texture size
			spr.scale = Vector2(w_cells, h_cells)

			# rotation
			spr.rotation_degrees = 0 if rotated else 90

			# position → center of footprint
			spr.position = Vector2(
				x * cell_size + (w_cells * cell_size) / 2.0,
				y * cell_size + (h_cells * cell_size) / 2.0
			)

			item_layer.add_child(spr)


# ---------------------------------------------------------
# PICKUP / PLACE
# ---------------------------------------------------------

func is_within_bounds_for_item(item: ItemResource, row: int, col: int, rot: bool) -> bool:
	var w = item.size_y if rot else item.size_x
	var h = item.size_x if rot else item.size_y

	return (
		row >= 0 and
		col >= 0 and
		row + h <= inventory_data.rows and
		col + w <= inventory_data.cols
	)


func _on_cell_input(event: InputEvent, x: int, y: int) -> void:
	if not (event is InputEventMouseButton): return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT: return

	if mb.pressed:
		if held_item == null:
			_pickup_attempt(x, y)
	else:
		if held_item != null:
			_try_place()


func _pickup_attempt(x: int, y: int) -> void:
	var cd = inventory_data.grid[y][x]
	if cd == null: return

	var item: ItemResource = cd["item"]
	var rot: bool = cd.get("rotated", false)

	original_row = y
	original_col = x
	original_rotated = rot

	inventory_data.clear_item(item)

	held_item = item
	holding_rotated = rot

	drag_sprite.texture = item.icon
	drag_sprite.visible = true

	_clear_preview()
	draw_grid()


func _try_place() -> void:
	if held_item == null: return

	var placed := false

	if hover_cell_x != -1 and hover_cell_y != -1:
		if is_within_bounds_for_item(held_item, hover_cell_y, hover_cell_x, holding_rotated):
			if inventory_data.can_place(held_item, hover_cell_y, hover_cell_x, holding_rotated):
				inventory_data.place(held_item, hover_cell_y, hover_cell_x, holding_rotated)
				placed = true

	if not placed:
		inventory_data.place(held_item, original_row, original_col, original_rotated)

	held_item = null
	holding_rotated = false
	drag_sprite.visible = false

	original_row = -1
	original_col = -1
	original_rotated = false

	_clear_preview()
	draw_grid()


# ---------------------------------------------------------
# HOVER HIGHLIGHT
# ---------------------------------------------------------

func _draw_hover_item_highlight(x: int, y: int) -> void:
	var cd = inventory_data.grid[y][x]
	if cd == null: return

	var item: ItemResource = cd["item"]
	var rotated: bool = cd.get("rotated", false)

	var origin_x := x
	var origin_y := y

	if !cd["origin"]:
		for yy in range(inventory_data.rows):
			for xx in range(inventory_data.cols):
				var other = inventory_data.grid[yy][xx]
				if other != null and other["item"] == item and other["origin"]:
					origin_x = xx
					origin_y = yy
					break

	var w = item.size_y if rotated else item.size_x
	var h = item.size_x if rotated else item.size_y

	for dy in range(h):
		for dx in range(w):
			var row = origin_y + dy
			var col = origin_x + dx
			if row < 0 or col < 0: continue
			if row >= inventory_data.rows or col >= inventory_data.cols: continue

			var idx = row * inventory_data.cols + col
			var cell = $GridLayer.get_child(idx)
			var style: StyleBoxFlat = cell.get_meta("style")

			style.border_color = Color.WHITE
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2

			cell.add_theme_stylebox_override("panel", style)


# ---------------------------------------------------------
# PREVIEW (holding)
# ---------------------------------------------------------

func _clear_preview() -> void:
	for cell in $GridLayer.get_children():
		var style: StyleBoxFlat = cell.get_meta("style")
		style.border_color = Color(0.15, 0.15, 0.15)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		cell.add_theme_stylebox_override("panel", style)


func _draw_placement_preview() -> void:
	if held_item == null: return
	if hover_cell_x == -1 or hover_cell_y == -1: return
	if not is_within_bounds_for_item(held_item, hover_cell_y, hover_cell_x, holding_rotated): return

	var w = held_item.size_y if holding_rotated else held_item.size_x
	var h = held_item.size_x if holding_rotated else held_item.size_y

	var valid = inventory_data.can_place(held_item, hover_cell_y, hover_cell_x, holding_rotated)
	var col = Color(0.3, 1, 0.3) if valid else Color(1, 0.3, 0.3)

	for dy in range(h):
		for dx in range(w):
			var row = hover_cell_y + dy
			var colm = hover_cell_x + dx
			if row < 0 or colm < 0: continue
			if row >= inventory_data.rows or colm >= inventory_data.cols: continue

			var idx = row * inventory_data.cols + colm
			var cell = $GridLayer.get_child(idx)
			var style: StyleBoxFlat = cell.get_meta("style")

			style.border_color = col
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2

			cell.add_theme_stylebox_override("panel", style)


# ---------------------------------------------------------
# DRAG PREVIEW (Sprite2D)
# ---------------------------------------------------------

func _update_drag_preview() -> void:
	if held_item == null: return

	drag_sprite.texture = held_item.icon

	var w_cells = held_item.size_y if holding_rotated else held_item.size_x
	var h_cells = held_item.size_x if holding_rotated else held_item.size_y

	drag_sprite.rotation_degrees = 0 if holding_rotated else 90
	drag_sprite.scale = Vector2(w_cells, h_cells)

	var pos: Vector2
	if hover_cell_x != -1 and hover_cell_y != -1:
		var grid_pos = $GridLayer.global_position
		pos = grid_pos + Vector2(
			hover_cell_x * cell_size + cell_size / 2,
			hover_cell_y * cell_size + cell_size / 2
		)
	else:
		pos = get_global_mouse_position()

	drag_sprite.global_position = pos

	_clear_preview()
	_draw_placement_preview()


# ---------------------------------------------------------
# MAIN LOOP
# ---------------------------------------------------------

func _process(_delta: float) -> void:
	if held_item != null:
		_update_drag_preview()

	if Input.is_action_just_pressed("rotate_item") and held_item != null:
		holding_rotated = !holding_rotated
		_update_drag_preview()
