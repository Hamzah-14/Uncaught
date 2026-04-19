class_name PotentialField
extends RefCounted

var _grid_manager: GridManager

func setup(grid_manager: GridManager) -> void:
	_grid_manager = grid_manager

# Returns the movement cost for entering a tile based on its type.
# Higher cost = Guardian naturally avoids it while fleeing.
func _tile_cost(pos: Vector2i) -> float:
	match _grid_manager.get_cell(pos):
		GridManager.CellType.RIVER_WATER: return 2.5
		GridManager.CellType.RIVER_SHORE: return 1.5
		_:                                return 1.0

# Builds a danger map using Dijkstra flood-fill from the player outward.
# Tiles closer to the player = lower danger score.
# Tile costs make hazard/slow terrain appear artificially closer to danger.
func build_field(player_grid_pos: Vector2i) -> Dictionary:
	if _grid_manager == null:
		print("PotentialField: grid_manager is null")
		return {}
	var field: Dictionary = {}
	var queue: Array = []

	queue.append([0.0, player_grid_pos])
	field[player_grid_pos] = 0.0

	while queue.size() > 0:
		# Find the lowest-cost entry without a full sort (avoids GDScript lambda overhead)
		var min_idx: int = 0
		for i in range(1, queue.size()):
			if queue[i][0] < queue[min_idx][0]:
				min_idx = i
		var current_entry = queue[min_idx]
		queue.remove_at(min_idx)
		var current_danger: float = current_entry[0]
		var current_pos: Vector2i = current_entry[1]

		for neighbor in _grid_manager.get_walkable_neighbors(current_pos):
			var new_danger: float = current_danger + _tile_cost(neighbor)

			if not field.has(neighbor) or new_danger < field[neighbor]:
				field[neighbor] = new_danger
				queue.append([new_danger, neighbor])

	return field

# Returns the safest neighboring tile for the Guardian to move to.
# Avoids dead ends — if the best tile has fewer than 2 walkable neighbors,
# fall back to the second-best tile instead.
func get_flee_goal(guardian_pos: Vector2i, field: Dictionary) -> Vector2i:
	var neighbors := _grid_manager.get_walkable_neighbors(guardian_pos)
	if neighbors.is_empty():
		return guardian_pos

	var best_tile: Vector2i = guardian_pos
	var best_score: float = -INF

	for tile in neighbors:
		var danger: float = field.get(tile, 0.0)
		var exits := _grid_manager.get_walkable_neighbors(tile).size()
		var mobility := exits * 2.0

		var edge_penalty := 0.0
		if tile.x <= 1 or tile.x >= _grid_manager.width - 2 \
				or tile.y <= 1 or tile.y >= _grid_manager.height - 2:
			edge_penalty = 4.0

		var dead_end_penalty := 0.0
		if exits <= 2:
			dead_end_penalty = 6.0

		var score := danger + mobility - edge_penalty - dead_end_penalty
		if score > best_score:
			best_score = score
			best_tile = tile

	return best_tile
