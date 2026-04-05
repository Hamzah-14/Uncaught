class_name GridManager
extends Node

@export var cell_size: float = 1.155 # The 'radius' of the hexagon
@export var width: int = 20
@export var height: int = 20
enum CellType { EMPTY, FLOOR, WALL, SANCTUM, HAZARD_COLLAPSE, HAZARD_VOID, HAZARD_TRAP }

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
	# 1. Convert Cartesian to fractional Axial coordinates (q, r)
	var q_frac: float = (world_pos.x * (sqrt(3.0)/3.0) - world_pos.z / 3.0) / cell_size
	var r_frac: float = (world_pos.z * (2.0/3.0)) / cell_size
	
	# 2. Round to the nearest hex center (Axial rounding)
	var s_frac: float = -q_frac - r_frac
	
	var q: int = roundi(q_frac)
	var r: int = roundi(r_frac)
	var s: int = roundi(s_frac)
	
	var q_diff: float = abs(q - q_frac)
	var r_diff: float = abs(r - r_frac)
	var s_diff: float = abs(s - s_frac)
	
	if q_diff > r_diff and q_diff > s_diff:
		q = -r - s
	elif r_diff > s_diff:
		r = -q - s
		
	# 3. Convert Axial (q, r) back to Odd-R offset (col, row)
	var col: int = q + (r - (r & 1)) / 2
	var row: int = r
	
	# Clamp to map boundaries just in case physics pushes an entity out of bounds
	col = clampi(col, 0, width - 1)
	row = clampi(row, 0, height - 1)
	
	return Vector2i(col, row)
# ------------------------------------------------------------------------------
# Grid State Management
# ------------------------------------------------------------------------------

func set_cell(grid_pos: Vector2i, type: int) -> void:
	_grid[grid_pos] = type

func get_cell(grid_pos: Vector2i) -> int:
	return _grid.get(grid_pos, CellType.EMPTY)

func is_walkable(grid_pos: Vector2i) -> bool:
	var type: int = get_cell(grid_pos)
	return type != CellType.WALL and type != CellType.EMPTY

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
