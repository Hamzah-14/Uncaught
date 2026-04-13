class_name TerrainGenerator
extends Node

@export var grid_manager: GridManager
@export var width: int = 17
@export var height: int = 17

var _center: Vector2i
var _river_tiles: Array[Vector2i] = []
var _high_tiles: Array[Vector2i] = []

func generate() -> void:
	_center = Vector2i(width / 2, height / 2)
	grid_manager.clear_grid()
	
	# Layer 1 — flood all as FLOOR
	for x in range(width):
		for y in range(height):
			grid_manager.set_cell(Vector2i(x, y), GridManager.CellType.FLOOR)
	
	# Layer 2 — elevation blobs
	_generate_elevation()
	
	# Layer 3 — river
	_generate_river()
	
	# Layer 4 — bridges over river
	_generate_bridges()
	
	# Layer 5 — sanctum (placed by ArenaController after this)
	# Layer 6 — hazards
	_scatter_hazards()
	
	# Layer 7 — protect center
	grid_manager.set_cell(_center, GridManager.CellType.FLOOR)
	
	# Layer 8 — connectivity check, fix if broken
	_ensure_connectivity()

# --- Elevation ---
func _generate_elevation() -> void:
	var num_blobs = randi_range(1, 2)  # was 2-3
	var padding = 3
	
	for i in range(num_blobs):
		var seed_x = randi_range(padding, width - padding - 1)
		var seed_y = randi_range(padding, height - padding - 1)
		var seed = Vector2i(seed_x, seed_y)
		
		if seed.distance_to(Vector2(_center)) < 5:  # was 4, push further from center
			continue
		
		var blob = _get_hexes_in_radius(seed, 1)  # was randi_range(1,2), cap at 1
		for tile in blob:
			if _in_bounds(tile) and tile != _center:
				grid_manager.set_cell(tile, GridManager.CellType.FLOOR_HIGH)
				_high_tiles.append(tile)

# --- River ---
func _generate_river() -> void:
	_river_tiles.clear()
	var water_tiles: Array[Vector2i] = []
	
	# Always go left to right for clean horizontal rivers
	# Pick entry row avoiding center
	var entry_y = randi_range(3, _center.y - 3) if randf() > 0.5 else randi_range(_center.y + 3, height - 4)
	var current = Vector2i(0, entry_y)
	
	var prev_dy = 0  # momentum — reduces zigzag
	var max_steps = width * 3
	var steps = 0
	
	while current.x < width and steps < max_steps:
		steps += 1
		
		# Skip center zone
		if current.distance_to(Vector2(_center)) > 2:
			water_tiles.append(current)
		
		# Bias strongly toward moving right
		var dx = 1
		var dy = 0
		
		var r = randf()
		if r < 0.25:
			# Slight curve — maintain momentum to avoid zigzag
			dy = prev_dy if randf() > 0.4 else (1 if randf() > 0.5 else -1)
		
		prev_dy = dy
		current = Vector2i(
			clampi(current.x + dx, 0, width - 1),
			clampi(current.y + dy, 0, height - 1)
		)
	
	# Set water core
	for tile in water_tiles:
		if _in_bounds(tile) and tile.distance_to(Vector2(_center)) > 2:
			grid_manager.set_cell(tile, GridManager.CellType.RIVER_WATER)
			_river_tiles.append(tile)
	
	# After building waterPath, add a parallel strip
	var extra_water: Array[Vector2i] = []
	for tile in water_tiles:
		var below = Vector2i(tile.x, tile.y + 1)
		if _in_bounds(below) and below.distance_to(Vector2(_center)) > 2:
			extra_water.append(below)

	for tile in extra_water:
		grid_manager.set_cell(tile, GridManager.CellType.RIVER_WATER)
		_river_tiles.append(tile)
		water_tiles.append(tile)  # include in shore calculation
	# Shore = one tile outward from water, only on FLOOR tiles
	var shore_candidates: Array[Vector2i] = []
	for tile in water_tiles:
		for n in grid_manager.get_all_neighbors(tile):
			if _in_bounds(n) and grid_manager.get_cell(n) == GridManager.CellType.FLOOR:
				if not shore_candidates.has(n):
					shore_candidates.append(n)
	
	for tile in shore_candidates:
		grid_manager.set_cell(tile, GridManager.CellType.RIVER_SHORE)
		_river_tiles.append(tile)
# --- Bridges ---
func _generate_bridges() -> void:
	if _river_tiles.is_empty():
		return
	
	var water_only: Array[Vector2i] = []
	for t in _river_tiles:
		if grid_manager.get_cell(t) == GridManager.CellType.RIVER_WATER:
			water_only.append(t)
	
	if water_only.is_empty():
		return
	
	# Sort by x so bridges are evenly spread left to right
	water_only.sort_custom(func(a, b): return a.x < b.x)
	
	var bridge_count = 3
	var segment = water_only.size() / (bridge_count + 1)
	
	for i in range(bridge_count):
		var idx = clampi(segment * (i + 1), 0, water_only.size() - 1)
		var anchor = water_only[idx]
		
		# Bridge the anchor and immediate river neighbors
		grid_manager.set_cell(anchor, GridManager.CellType.BRIDGE)
		for n in grid_manager.get_all_neighbors(anchor):
			if _in_bounds(n):
				var cell = grid_manager.get_cell(n)
				if cell == GridManager.CellType.RIVER_WATER or cell == GridManager.CellType.RIVER_SHORE:
					grid_manager.set_cell(n, GridManager.CellType.BRIDGE)
					break # <-- ADD THIS to stop the clumping!

# --- Hazards ---
func _scatter_hazards() -> void:
	var hazard_count = randi_range(6, 10)
	var placed = 0
	var attempts = 0
	
	while placed < hazard_count and attempts < 200:
		attempts += 1
		var rx = randi_range(1, width - 2)
		var ry = randi_range(1, height - 2)
		var pos = Vector2i(rx, ry)
		
		if grid_manager.get_cell(pos) != GridManager.CellType.FLOOR:
			continue
		if pos.distance_to(_center) < 3:
			continue
		
		var type = GridManager.CellType.HAZARD_COLLAPSE if randf() > 0.4 else GridManager.CellType.HAZARD_TRAP
		grid_manager.set_cell(pos, type)
		placed += 1

# --- Connectivity fix ---
func _ensure_connectivity() -> void:
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [_center]
	visited[_center] = true
	
	while not queue.is_empty():
		var current = queue.pop_front()
		for n in grid_manager.get_walkable_neighbors(current):
			if not visited.has(n):
				visited[n] = true
				queue.push_back(n)
	
	# Any walkable tile not reached — convert to FLOOR and connect
	for x in range(width):
		for y in range(height):
			var pos = Vector2i(x, y)
			var cell = grid_manager.get_cell(pos)
			if cell == GridManager.CellType.RIVER_WATER or cell == GridManager.CellType.RIVER_SHORE or cell == GridManager.CellType.BRIDGE:
				continue
			if grid_manager.is_walkable(pos) and not visited.has(pos):
				# Find nearest visited tile and punch a floor path to it
				grid_manager.set_cell(pos, GridManager.CellType.FLOOR)

# --- Helpers ---
func _in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height

func _get_hexes_in_radius(center: Vector2i, radius: int) -> Array[Vector2i]:
	var results: Array[Vector2i] = [center]
	var frontier: Array[Vector2i] = [center]
	
	for _r in range(radius):
		var next: Array[Vector2i] = []
		for hex in frontier:
			for n in grid_manager.get_all_neighbors(hex):
				if not results.has(n):
					results.append(n)
					next.append(n)
		frontier = next
	return results
