# inventory_data.gd
extends Resource
class_name InventoryData

@export var rows := 6
@export var cols := 8

# Cell storage
var grid := []

func _init():
	grid.resize(rows)
	for i in range(rows):
		grid[i] = []
		grid[i].resize(cols)
		for j in range(cols):
			grid[i][j] = null

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

func place(item: ItemResource, row: int, col: int, rot: bool):
	var w = item.size_y if rot else item.size_x
	var h = item.size_x if rot else item.size_y
	
	for y in range(h):
		for x in range(w):
			grid[row + y][col + x] = item

func clear_item(item: ItemResource):
	for y in range(rows):
		for x in range(cols):
			if grid[y][x] == item:
				grid[y][x] = null
