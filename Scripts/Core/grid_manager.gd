class_name GridManager
extends Node

@export var cell_size: float = 1.155 # The 'radius' of the hexagon
@export var width: int = 17
@export var height: int = 17
enum CellType { EMPTY, FLOOR, FLOOR_HIGH, RIVER_SHORE, RIVER_WATER, BRIDGE, SANCTUM, HAZARD_COLLAPSE, HAZARD_VOID, HAZARD_TRAP }

var _grid: Dictionary = {}

# Constants for Pointy-Topped Hexagon math
const HEX_WIDTH_MULT: float = 1.7320508 # sqrt(3)
const HEX_HEIGHT_MULT: float = 1.5

# Hexagonal Coordinate Translation (Odd-R Offset)
## Converts discrete Hex Grid coordinate to 3D World Position
func grid_to_world(grid_pos: Vector2i, y_elevation: float = 0.0) -> Vector3:
	# If the row (y) is odd, we offset the column (x) by 0.5
	var is_odd_row: bool = (grid_pos.y % 2 != 0)
	var offset: float = 0.5 if is_odd_row else 0.0
	
	var world_x: float = (grid_pos.x + offset) * (cell_size * HEX_WIDTH_MULT)
	var world_z: float = grid_pos.y * (cell_size * HEX_HEIGHT_MULT)
	
	return Vector3(world_x, y_elevation, world_z)

## Converts a continuous 3D world position back to a discrete Hex Grid coordinate.
func world_to_grid(world_pos: Vector3) -> Vector2i:
	# Invert: world_z = row * cell_size * HEX_HEIGHT_MULT
	var row: int = roundi(world_pos.z / (cell_size * HEX_HEIGHT_MULT))
	row = clampi(row, 0, height - 1)
	
	# Invert: world_x = (col + offset) * cell_size * HEX_WIDTH_MULT
	var is_odd_row: bool = (row % 2 != 0)
	var offset: float = 0.5 if is_odd_row else 0.0
	var col: int = roundi(world_pos.x / (cell_size * HEX_WIDTH_MULT) - offset)
	col = clampi(col, 0, width - 1)
	
	return Vector2i(col, row)
	
# Grid State Management
func set_cell(grid_pos: Vector2i, type: int) -> void:
	_grid[grid_pos] = type

func get_cell(grid_pos: Vector2i) -> int:
	return _grid.get(grid_pos, CellType.EMPTY)

func is_walkable(grid_pos: Vector2i) -> bool:
	var type: int = get_cell(grid_pos)
	return type != CellType.EMPTY

func clear_grid() -> void:
	_grid.clear()

# ------------------------------------------------------------------------------
# AI Utility: 6-Way Hex Adjacency
# ------------------------------------------------------------------------------

func get_walkable_neighbors(grid_pos: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	var is_odd_row: bool = abs(grid_pos.y % 2) == 1
	var directions: Array[Vector2i]
	
	# The neighbors change depending on whether the row is shifted
	if is_odd_row:
		directions = [
			Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
			Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 1)
		]
	else:
		directions = [
			Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, -1),
			Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
		]
		
	for dir in directions:
		var target_pos: Vector2i = grid_pos + dir
		if is_walkable(target_pos):
			neighbors.append(target_pos)
			
	return neighbors
	
func get_all_neighbors(grid_pos: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	var is_odd_row: bool = abs(grid_pos.y % 2) == 1
	var directions: Array[Vector2i]
	
	if is_odd_row:
		directions = [
			Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
			Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 1)
		]
	else:
		directions = [
			Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, -1),
			Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
		]
		
	for dir in directions:
		# Just return the mathematical coordinates, regardless of what's there
		neighbors.append(grid_pos + dir)
			
	return neighbors
	
func get_speed_multiplier(grid_pos: Vector2i) -> float:
	match get_cell(grid_pos):
		CellType.RIVER_SHORE: return 0.65
		CellType.RIVER_WATER: return 0.4
		CellType.FLOOR_HIGH: return 0.75
		CellType.BRIDGE: return 1.0
		_: return 1.0
