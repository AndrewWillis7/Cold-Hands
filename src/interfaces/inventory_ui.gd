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

# --- Controller Navigation State ---
var controller_active := false
var controller_row := 0
var controller_col := 0
var controller_cursor: Panel

var _last_mouse_pos := Vector2.ZERO
var _mouse_has_moved := false


func _ready() -> void:
	if inventory_data == null:
		inventory_data = InventoryData.new()

	drag_sprite = $DragPreviewSprite
	drag_sprite.visible = false
	drag_sprite.centered = true

	controller_cursor = $ControllerCursor
	controller_cursor.visible = false

	await get_tree().process_frame
	draw_grid()

	$GridLayer.position = (get_viewport_rect().size - $GridLayer.size) / 2
	$ItemLayer.position = $GridLayer.position

	_position_autosort_button()

	for pickup in get_tree().get_nodes_in_group("interactables"):
		pickup.connect("request_add_to_inventory", Callable(self, "_on_request_add_to_inventory"))


func _on_request_add_to_inventory(item):
	var unique_item = item.duplicate(true)
	var ok = add_item_from_world(unique_item)
	if ok:
		print("added!")
	else:
		print("inventory full")


func _position_autosort_button() -> void:
	var grid_pos = $GridLayer.position
	var grid_size = $GridLayer.size
	var btn := $AutosortButton
	btn.position = grid_pos + Vector2(0, grid_size.y + 12)


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
	if event is InputEventMouseButton:
		_on_cell_input(event, x, y)


# ---------------------------------------------------------
# FIND TRUE ORIGIN
# ---------------------------------------------------------

func _find_true_origin(item: ItemResource) -> Vector2i:
	for yy in range(inventory_data.rows):
		for xx in range(inventory_data.cols):
			var cd = inventory_data.grid[yy][xx]
			if cd != null and cd["item"] == item and cd.get("origin", false):
				return Vector2i(xx, yy)
	return Vector2i(-1, -1)


# ---------------------------------------------------------
# GRID + ITEM DRAWING
# ---------------------------------------------------------

func draw_grid() -> void:
	var grid = $GridLayer
	var item_layer = $ItemLayer

	for c in grid.get_children():
		c.queue_free()
	for c in item_layer.get_children():
		c.queue_free()

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
			if cd == null or not cd["origin"]:
				continue

			var item: ItemResource = cd["item"]
			var rotated: bool = cd.get("rotated", false)

			var spr := Sprite2D.new()
			spr.texture = item.icon
			spr.centered = true

			var w_cells = item.size_y if rotated else item.size_x
			var h_cells = item.size_x if rotated else item.size_y

			spr.scale = Vector2(w_cells, h_cells)
			spr.rotation_degrees = 0 if rotated else 90

			spr.position = Vector2(
				x * cell_size + (w_cells * cell_size) / 2.0,
				y * cell_size + (h_cells * cell_size) / 2.0
			)

			item_layer.add_child(spr)

			if item.max_stack_size > 1:
				var label := Label.new()
				label.text = str(item.stack_size)
				label.position = spr.position + Vector2(10, 10)
				label.add_theme_font_size_override("font_size", 14)
				item_layer.add_child(label)


# ---------------------------------------------------------
# PICKUP / PLACE
# ---------------------------------------------------------

func is_within_bounds_for_item(item: ItemResource, row: int, col: int, rot: bool) -> bool:
	var w = item.size_y if rot else item.size_x
	var h = item.size_x if rot else item.size_y
	return row >= 0 and col >= 0 and row + h <= inventory_data.rows and col + w <= inventory_data.cols


func _on_cell_input(event: InputEvent, x: int, y: int) -> void:
	var mb := event as InputEventMouseButton
	if mb == null: return
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

	var origin := _find_true_origin(item)
	original_col = origin.x
	original_row = origin.y
	original_rotated = rot

	inventory_data.clear_item(item)

	held_item = item
	holding_rotated = rot

	drag_sprite.texture = item.icon
	drag_sprite.visible = true

	_clear_preview()


func _controller_pick_or_place() -> void:
	if controller_row < 0 or controller_col < 0:
		return

	if held_item == null:
		var cd = inventory_data.grid[controller_row][controller_col]
		if cd != null:
			_pickup_attempt(controller_col, controller_row)
		return

	_try_place()


# ---------------------------------------------------------
# PLACE + MERGE LOGIC
# ---------------------------------------------------------

func _try_place() -> void:
	if held_item == null:
		return

	var placed := false

	# --- MERGE ---
	if hover_cell_x != -1 and hover_cell_y != -1:
		var cd = inventory_data.grid[hover_cell_y][hover_cell_x]
		if cd != null:
			var other: ItemResource = cd["item"]
			if other.item_id == held_item.item_id and other.max_stack_size > 1:
				var space = other.max_stack_size - other.stack_size
				if space > 0:
					var amt = min(space, held_item.stack_size)
					other.stack_size += amt
					held_item.stack_size -= amt

					if held_item.stack_size <= 0:
						held_item = null
						drag_sprite.visible = false
						draw_grid()
						return

					draw_grid()
					return

	# --- NORMAL PLACE ---
	if hover_cell_x != -1 and hover_cell_y != -1:
		if is_within_bounds_for_item(held_item, hover_cell_y, hover_cell_x, holding_rotated):
			if inventory_data.can_place(held_item, hover_cell_y, hover_cell_x, holding_rotated):
				inventory_data.place(held_item, hover_cell_y, hover_cell_x, holding_rotated)
				placed = true

	# --- FALLBACK ---
	if not placed:
		if original_row != -1 and original_col != -1:
			if is_within_bounds_for_item(held_item, original_row, original_col, original_rotated):
				if inventory_data.can_place(held_item, original_row, original_col, original_rotated):
					inventory_data.place(held_item, original_row, original_col, original_rotated)

	held_item = null
	holding_rotated = false
	drag_sprite.visible = false

	original_row = -1
	original_col = -1

	_clear_preview()
	draw_grid()


# ---------------------------------------------------------
# STACK SPLIT
# ---------------------------------------------------------

func _attempt_stack_split(x: int, y: int) -> void:
	if x < 0 or y < 0:
		return

	var cd = inventory_data.grid[y][x]
	if cd == null: return

	var item: ItemResource = cd["item"]

	if item.max_stack_size <= 1: return
	if item.stack_size <= 1: return
	if item.size_x != 1 or item.size_y != 1: return

	var split_amt = item.stack_size / 2
	if split_amt <= 0:
		return

	var new_item := item.duplicate(true)
	new_item.stack_size = split_amt
	item.stack_size -= split_amt

	var placed := false

	for r in range(inventory_data.rows):
		for c in range(inventory_data.cols):
			if inventory_data.grid[r][c] == null:
				if inventory_data.can_place(new_item, r, c, false):
					inventory_data.place(new_item, r, c, false)
					placed = true
					break
		if placed:
			break

	if not placed:
		item.stack_size += split_amt
		print("No space for split.")
		return

	draw_grid()


# ---------------------------------------------------------
# HOVER + MOUSE INPUT
# ---------------------------------------------------------

func _update_hover_from_mouse() -> void:
	# Detect real mouse motion (ignore jitter)
	var pos = get_global_mouse_position()
	if (pos - _last_mouse_pos).length() > 1.5:
		controller_active = false
		controller_cursor.visible = false
	_last_mouse_pos = pos

	if controller_active:
		return

	var local_pos = get_local_mouse_position()
	var grid_pos = $GridLayer.position
	var p = local_pos - grid_pos

	var x = int(floor(p.x / cell_size))
	var y = int(floor(p.y / cell_size))

	if x < 0 or y < 0 or x >= inventory_data.cols or y >= inventory_data.rows:
		hover_cell_x = -1
		hover_cell_y = -1
	else:
		hover_cell_x = x
		hover_cell_y = y


func _draw_hover_item_highlight(x: int, y: int) -> void:
	var cd = inventory_data.grid[y][x]
	if cd == null: return

	var item: ItemResource = cd["item"]
	var rot: bool = cd.get("rotated", false)

	var o = _find_true_origin(item)
	var w = item.size_y if rot else item.size_x
	var h = item.size_x if rot else item.size_y

	for dy in range(h):
		for dx in range(w):
			var row = o.y + dy
			var col = o.x + dx
			if row < 0 or col < 0: continue
			if row >= inventory_data.rows or col >= inventory_data.cols: continue

			var idx = row * inventory_data.cols + col
			var cell = $GridLayer.get_child(idx)
			var s = cell.get_meta("style")
			s.border_color = Color.WHITE
			cell.add_theme_stylebox_override("panel", s)


func _clear_preview() -> void:
	for cell in $GridLayer.get_children():
		var s = cell.get_meta("style")
		s.border_color = Color(0.15, 0.15, 0.15)
		cell.add_theme_stylebox_override("panel", s)


func _draw_placement_preview() -> void:
	if held_item == null: return
	if hover_cell_x == -1 or hover_cell_y == -1: return

	var w = held_item.size_y if holding_rotated else held_item.size_x
	var h = held_item.size_x if holding_rotated else held_item.size_y

	var ok = (
		is_within_bounds_for_item(held_item, hover_cell_y, hover_cell_x, holding_rotated)
		and inventory_data.can_place(held_item, hover_cell_y, hover_cell_x, holding_rotated)
	)

	var col = Color(0.3, 1, 0.3) if ok else Color(1, 0.3, 0.3)

	for dy in range(h):
		for dx in range(w):
			var row = hover_cell_y + dy
			var colm = hover_cell_x + dx

			if row < 0 or colm < 0: continue
			if row >= inventory_data.rows or colm >= inventory_data.cols: continue

			var idx = row * inventory_data.cols + colm
			var cell = $GridLayer.get_child(idx)
			var s = cell.get_meta("style")
			s.border_color = col
			cell.add_theme_stylebox_override("panel", s)


# ---------------------------------------------------------
# DRAG PREVIEW
# ---------------------------------------------------------

func _update_drag_preview() -> void:
	if held_item == null: return

	drag_sprite.texture = held_item.icon

	var w = held_item.size_y if holding_rotated else held_item.size_x
	var h = held_item.size_x if holding_rotated else held_item.size_y

	drag_sprite.scale = Vector2(w, h)
	drag_sprite.rotation_degrees = 0 if holding_rotated else 90

	var pos: Vector2
	if hover_cell_x != -1 and hover_cell_y != -1:
		var gp = $GridLayer.position
		pos = gp + Vector2(
			hover_cell_x * cell_size + cell_size / 2,
			hover_cell_y * cell_size + cell_size / 2
		)
	else:
		pos = get_local_mouse_position()

	drag_sprite.position = pos


# ---------------------------------------------------------
# CONTROLLER NAVIGATION
# ---------------------------------------------------------

func _activate_controller_mode() -> void:
	controller_active = true
	controller_cursor.visible = true
	hover_cell_x = controller_col
	hover_cell_y = controller_row
	_update_controller_cursor()


func _update_controller_cursor() -> void:
	var gx = $GridLayer.position.x + controller_col * cell_size
	var gy = $GridLayer.position.y + controller_row * cell_size
	controller_cursor.position = Vector2(gx, gy)


func _controller_move(dx: int, dy: int) -> void:
	controller_active = true
	controller_cursor.visible = true

	controller_row = clamp(controller_row + dy, 0, inventory_data.rows - 1)
	controller_col = clamp(controller_col + dx, 0, inventory_data.cols - 1)

	hover_cell_x = controller_col
	hover_cell_y = controller_row

	_update_controller_cursor()


# ---------------------------------------------------------
# AUTOSORT
# ---------------------------------------------------------

func autosort_inventory() -> void:
	var items: Array = []
	var seen := {}

	for y in range(inventory_data.rows):
		for x in range(inventory_data.cols):
			var cd = inventory_data.grid[y][x]
			if cd == null: continue
			if cd["origin"]:
				var item = cd["item"]
				if not seen.has(item):
					seen[item] = true
					items.append(item)

	for it in items:
		inventory_data.clear_item(it)

	items.sort_custom(func(a, b):
		return (a.size_x * a.size_y) > (b.size_x * b.size_y)
	)

	for item in items:
		var placed := false

		for col in range(inventory_data.cols):
			for row in range(inventory_data.rows):

				if is_within_bounds_for_item(item, row, col, false) and inventory_data.can_place(item, row, col, false):
					inventory_data.place(item, row, col, false)
					placed = true
					break

				if is_within_bounds_for_item(item, row, col, true) and inventory_data.can_place(item, row, col, true):
					inventory_data.place(item, row, col, true)
					placed = true
					break

			if placed: break

		if not placed:
			print("Autosort failed:", item)

	draw_grid()
	_clear_preview()


# ---------------------------------------------------------
# ADD FROM WORLD
# ---------------------------------------------------------

func add_item_from_world(item: ItemResource) -> bool:
	if item.max_stack_size > 1 and item.size_x == 1 and item.size_y == 1:
		for row in range(inventory_data.rows):
			for col in range(inventory_data.cols):
				var cd = inventory_data.grid[row][col]
				if cd == null: continue
				if cd["origin"]:
					var ex: ItemResource = cd["item"]
					if ex.item_id == item.item_id:
						var space = ex.max_stack_size - ex.stack_size
						if space > 0:
							var a = min(space, item.stack_size)
							ex.stack_size += a
							item.stack_size -= a
							if item.stack_size <= 0:
								draw_grid()
								return true

	for row in range(inventory_data.rows):
		for col in range(inventory_data.cols):
			if is_within_bounds_for_item(item, row, col, false) and inventory_data.can_place(item, row, col, false):
				inventory_data.place(item, row, col, false)
				draw_grid()
				return true

			if is_within_bounds_for_item(item, row, col, true) and inventory_data.can_place(item, row, col, true):
				inventory_data.place(item, row, col, true)
				draw_grid()
				return true

	return false


# ---------------------------------------------------------
# MAIN LOOP
# ---------------------------------------------------------

func _process(_delta: float) -> void:
	_update_hover_from_mouse()

	# Controller navigation
	if Input.is_action_just_pressed("ui_inventory_up"):
		_activate_controller_mode()
		_controller_move(0, -1)

	if Input.is_action_just_pressed("ui_inventory_down"):
		_activate_controller_mode()
		_controller_move(0, 1)

	if Input.is_action_just_pressed("ui_inventory_left"):
		_activate_controller_mode()
		_controller_move(-1, 0)

	if Input.is_action_just_pressed("ui_inventory_right"):
		_activate_controller_mode()
		_controller_move(1, 0)

	if Input.is_action_just_pressed("ui_inventory_select"):
		_controller_pick_or_place()

	if Input.is_action_just_pressed("split_stack"):
		_attempt_stack_split(hover_cell_x, hover_cell_y)

	# Dragging visuals
	if held_item != null:
		_clear_preview()
		_update_drag_preview()
		_draw_placement_preview()
	else:
		_clear_preview()
		if hover_cell_x != -1 and hover_cell_y != -1:
			_draw_hover_item_highlight(hover_cell_x, hover_cell_y)

	if Input.is_action_just_pressed("rotate_item") and held_item != null:
		holding_rotated = !holding_rotated
		_update_drag_preview()
