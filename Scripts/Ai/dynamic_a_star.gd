class_name DynamicAStar
extends RefCounted

var _grid_manager: GridManager

func setup(grid_manager: GridManager) -> void:
	_grid_manager = grid_manager

func find_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	if start == goal:
		return []
	
	# open_set stores [f_score, node]
	var open_set: Array = []
	var came_from: Dictionary = {}
	var g_score: Dictionary = { start: 0 }
	var f_score: Dictionary = { start: _heuristic(start, goal) }
	
	open_set.append([f_score[start], start])
	
	while open_set.size() > 0:
		open_set.sort()
		var current: Vector2i = open_set[0][1]
		open_set.pop_front()
		
		if current == goal:
			return _reconstruct_path(came_from, current)
		
		for neighbor in _grid_manager.get_walkable_neighbors(current):
			var tentative_g: float = g_score[current] + 1.0
			
			if not g_score.has(neighbor) or tentative_g < g_score[neighbor]:
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + _heuristic(neighbor, goal)
				open_set.append([f_score[neighbor], neighbor])
	
	return []

func _heuristic(a: Vector2i, b: Vector2i) -> float:
	var dq: int = b.x - a.x
	var dr: int = b.y - a.y
	return float((abs(dq) + abs(dq + dr) + abs(dr)) / 2)

func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [current]
	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)
	path.pop_front()
	return path
