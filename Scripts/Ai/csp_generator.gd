class_name CSPGenerator
extends Node

# --- Signals for the Debug Overlay ---
signal generation_started
signal cell_evaluating(grid_pos: Vector2i, possible_values: Array)
signal cell_assigned(grid_pos: Vector2i, type: int)
signal backtracked(grid_pos: Vector2i)
signal constraint_failed(reason: String)
signal generation_complete(success: bool)

@export var grid_manager: GridManager
@export var width: int = 17
@export var height: int = 17

var _unassigned_cells: Array[Vector2i] = []
var _domains: Dictionary = {}
var _center_pos: Vector2i
var _sanctum_center: Vector2i
var _sanctum_tiles: Array[Vector2i] = []
var debug_mode: bool = false
func _ready() -> void:
	randomize()
	_center_pos = Vector2i(width / 2, height / 2)

# Generation Pipeline
func generate_arena() -> void:
	emit_signal("generation_started")
	grid_manager.clear_grid()
	
	_initialize_variables_and_domains()
	
	var success: bool = await _backtracking_search()
	
	if success:
		if _verify_global_connectivity():
			emit_signal("generation_complete", true)
			print("Arena Generation Successful. Fully connected.")
		else:
			emit_signal("constraint_failed", "Global connectivity validation failed.")
			emit_signal("generation_complete", false)
	else:
		emit_signal("constraint_failed", "Solver exhausted all domains.")
		emit_signal("generation_complete", false)

func _initialize_variables_and_domains() -> void:
	_unassigned_cells.clear()
	_domains.clear()
	_sanctum_tiles.clear()
	_center_pos = Vector2i(width / 2, height / 2)

func _is_consistent(_pos: Vector2i, _value: int) -> bool:
	return true

#func _initialize_variables_and_domains() -> void:
	#_unassigned_cells.clear()
	#_domains.clear()
	#_sanctum_tiles.clear()
	#
	## 1. Pick a valid Sanctum Center (Not at edges, not at Ember center)
	#_sanctum_center = _get_valid_sanctum_center()
	#
	## 2. Get all hexes within a radius of 2 (Creates a solid hexagonal chunk of 19 tiles)
	#_sanctum_tiles = _get_hexes_in_radius(_sanctum_center, 2)
	#
	#for x in range(width):
		#for y in range(height):
			#var pos = Vector2i(x, y)
			#
			## Pre-assign Ember Center
			#if pos == _center_pos:
				#grid_manager.set_cell(pos, GridManager.CellType.FLOOR)
				#continue
				#
			## Pre-assign the Sanctum Zone block
			#if pos in _sanctum_tiles:
				## We will make the outermost ring Void Edges later, for now, mark the block
				#grid_manager.set_cell(pos, GridManager.CellType.SANCTUM)
				#emit_signal("cell_assigned", pos, GridManager.CellType.SANCTUM)
				#continue
				#
			#_unassigned_cells.append(pos)
			#
			## Edges are walls
			#if x == 0 or x == width - 1 or y == 0 or y == height - 1:
				#_domains[pos] = [GridManager.CellType.WALL]
			#else:
				## Tighter Domain: More floors, grouped walls, and sprinkled hazards
				#_domains[pos] = [
					#GridManager.CellType.FLOOR, GridManager.CellType.FLOOR, GridManager.CellType.FLOOR,
					#GridManager.CellType.WALL, GridManager.CellType.WALL,
					#GridManager.CellType.HAZARD_COLLAPSE, GridManager.CellType.HAZARD_TRAP
				#]
#
#func _get_valid_sanctum_center() -> Vector2i:
	## Keep it away from the extreme edges and the absolute center
	#var padding = 4
	#var valid_x = randi_range(padding, width - padding - 1)
	#var valid_y = randi_range(padding, height - padding - 1)
	#var candidate = Vector2i(valid_x, valid_y)
	#
	## If it spawned exactly on the Ember, shift it
	#if candidate == _center_pos:
		#candidate.x += 3
		#
	#return candidate
#
#func _get_hexes_in_radius(center: Vector2i, radius: int) -> Array[Vector2i]:
	#var results: Array[Vector2i] = [center]
	#var current_ring: Array[Vector2i] = [center]
	#
	## Expanding ring search for hex grids
	#for r in range(radius):
		#var next_ring: Array[Vector2i] = []
		#for hex in current_ring:
			#var neighbors = grid_manager.get_all_neighbors(hex) # Temporarily fetches all adjacent
			#for n in neighbors:
				#if not results.has(n):
					#results.append(n)
					#next_ring.append(n)
		#current_ring = next_ring
	#return results
# ------------------------------------------------------------------------------
# Backtracking Solver
# ------------------------------------------------------------------------------
func _backtracking_search() -> bool:
	if _unassigned_cells.is_empty():
		return true 
		
	var current_var: Vector2i = _unassigned_cells.pop_front()
	var current_domain: Array = _domains[current_var].duplicate()
	current_domain.shuffle() 
	
	emit_signal("cell_evaluating", current_var, current_domain)
	
	for value in current_domain:
		if _is_consistent(current_var, value):
			grid_manager.set_cell(current_var, value)
			emit_signal("cell_assigned", current_var, value)
			
			if await _backtracking_search():
				return true
				
			# Backtrack
			grid_manager.set_cell(current_var, GridManager.CellType.EMPTY)
			emit_signal("backtracked", current_var)
			if debug_mode:
				await get_tree().process_frame
			
	_unassigned_cells.push_front(current_var)
	return false

# Constraints & Validation
#func _is_consistent(pos: Vector2i, value: int) -> bool:
	#var neighbors = grid_manager.get_all_neighbors(pos) # <-- FIXED HERE
	#
	#if value == GridManager.CellType.WALL:
		#var wall_count = 0
		#for n in neighbors:
			#if grid_manager.get_cell(n) == GridManager.CellType.WALL:
				#wall_count += 1
		#
		## Hexagons have 6 neighbors. If 3 are walls, placing a 4th makes a severe choke point.
		#if wall_count >= 3: 
			#return false
			#
	#if value == GridManager.CellType.FLOOR:
		#var wall_count = 0
		#for n in neighbors:
			#if grid_manager.get_cell(n) == GridManager.CellType.WALL:
				#wall_count += 1
				#
		## Prevent dead ends (a floor surrounded by 5 walls)
		#if wall_count >= 5:
			#return false
			#
	#return true

func _count_existing_cells(type: int) -> int:
	var count = 0
	for x in range(width):
		for y in range(height):
			if grid_manager.get_cell(Vector2i(x, y)) == type:
				count += 1
	return count

## Runs a Breadth-First Search (BFS) to ensure every floor/sanctum tile can reach the center Ember.
func _verify_global_connectivity() -> bool:
	var reachable_tiles: Array[Vector2i] = []
	var queue: Array[Vector2i] = [_center_pos]
	var visited: Dictionary = {_center_pos: true}
	
	# BFS Traversal
	while not queue.is_empty():
		var current = queue.pop_front()
		reachable_tiles.append(current)
		
		var neighbors = grid_manager.get_walkable_neighbors(current)
		for n in neighbors:
			if not visited.has(n):
				visited[n] = true
				queue.push_back(n)
				
	# Check if reachable tiles matches total walkable tiles
	var total_walkable = 0
	for x in range(width):
		for y in range(height):
			var type = grid_manager.get_cell(Vector2i(x, y))
			if type != GridManager.CellType.EMPTY:
				total_walkable += 1
				
	return reachable_tiles.size() == total_walkable
