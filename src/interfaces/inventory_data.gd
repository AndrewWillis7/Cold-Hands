extends Resource
class_name InventoryData

@export var rows := 6
@export var cols := 8

# grid[y][x] = {
#   "item": ItemResource,
#   "origin": bool,
#   "rotated": bool
# }
var grid := []


func _init() -> void:
	grid.resize(rows)
	for y in range(rows):
		grid[y] = []
		grid[y].resize(cols)
		for x in range(cols):
			grid[y][x] = null


func can_place(item: ItemResource, row: int, col: int, rot: bool) -> bool:
	var w = item.size_y if rot else item.size_x
	var h = item.size_x if rot else item.size_y

	if row + h > rows or col + w > cols:
		return false

	for y in range(h):
		for x in range(w):
			if grid[row + y][col + x] != null:
				return false

	return true


func place(item: ItemResource, row: int, col: int, rot: bool) -> void:
	var w = item.size_y if rot else item.size_x
	var h = item.size_x if rot else item.size_y

	for y in range(h):
		for x in range(w):
			var is_origin := (y == 0 and x == 0)

			grid[row + y][col + x] = {
				"item": item,
				"origin": is_origin,
				"rotated": rot
			}


func clear_item(item: ItemResource) -> void:
	for y in range(rows):
		for x in range(cols):
			var cd = grid[y][x]
			if cd != null and cd["item"] == item:
				grid[y][x] = null

func force_place_for_testing(item: ItemResource) -> void:
	if can_place(item, 0, 0, false):
		place(item, 0, 0, false)
	else:
		push_warning("Couldn't place test item at 0,0")
