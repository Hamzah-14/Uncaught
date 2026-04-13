class_name PotentialField
extends RefCounted

var _grid_manager: GridManager

func setup(grid_manager: GridManager) -> void:
	_grid_manager = grid_manager

# Builds a danger map across the whole grid using Dijkstra flood-fill
# from the player outward. Tiles closer to player = higher danger.
func build_field(player_grid_pos: Vector2i) -> Dictionary:
	if _grid_manager == null:
		print("PotentialField: grid_manager is null")
		return {}
	var field: Dictionary = {}
	var queue: Array = []
	
	# Player tile starts at danger 0 — maximum danger
	# All other tiles get higher values as distance increases
	queue.append([0.0, player_grid_pos])
	field[player_grid_pos] = 0.0
	
	while queue.size() > 0:
		# Sort by danger score ascending — process closest first
		queue.sort_custom(func(a, b): return a[0] < b[0])
		var current_entry = queue.pop_front()
		var current_danger: float = current_entry[0]
		var current_pos: Vector2i = current_entry[1]
		
		for neighbor in _grid_manager.get_walkable_neighbors(current_pos):
			var new_danger: float = current_danger + 1.0
			
			# Only update if we found a shorter path to this tile
			if not field.has(neighbor) or new_danger < field[neighbor]:
				field[neighbor] = new_danger
				queue.append([new_danger, neighbor])
	
	return field

# Given Guardian's position and the danger field,
# returns the safest neighboring tile to move to
func get_flee_goal(guardian_pos: Vector2i, field: Dictionary) -> Vector2i:
	var neighbors = _grid_manager.get_walkable_neighbors(guardian_pos)
	
	if neighbors.is_empty():
		return guardian_pos
	
	var best_tile: Vector2i = guardian_pos
	var best_score: float = -1.0
	
	for neighbor in neighbors:
		# Higher danger value = further from player = safer
		var score: float = field.get(neighbor, 0.0)
		
		if score > best_score:
			best_score = score
			best_tile = neighbor
	
	return best_tile
