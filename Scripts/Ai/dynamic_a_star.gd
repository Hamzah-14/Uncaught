class_name DynamicAStar
extends RefCounted

var _grid_manager: GridManager

func setup(grid_manager: GridManager) -> void:
	_grid_manager = grid_manager

func find_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	if start == goal:
		return []

	var actual_goal = goal if _grid_manager.is_walkable(goal) else _nearest_walkable(goal, start)
	if actual_goal == Vector2i(-1, -1):
		return []

	var open_set: Array = []
	var open_lookup: Dictionary = {}
	var came_from: Dictionary = {}
	var g_score: Dictionary = {start: 0.0}
	var f_score: Dictionary = {start: _heuristic(start, actual_goal)}
	open_set.append([f_score[start], start])
	open_lookup[start] = true

	while open_set.size() > 0:
		open_set.sort_custom(func(a, b): return a[0] < b[0])
		var current: Vector2i = open_set[0][1]
		open_set.pop_front()
		open_lookup.erase(current)

		if current == actual_goal:
			return _reconstruct_path(came_from, current)

		for neighbor in _grid_manager.get_walkable_neighbors(current):
			var tentative_g: float = g_score[current] + 1.0
			if not g_score.has(neighbor) or tentative_g < g_score[neighbor]:
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + _heuristic(neighbor, actual_goal)
				if not open_lookup.has(neighbor):
					open_set.append([f_score[neighbor], neighbor])
					open_lookup[neighbor] = true
	return []

func _nearest_walkable(target: Vector2i, fallback_toward: Vector2i) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_dist: float = 999.0
	# Search in expanding ring — check neighbors of target
	for neighbor in _grid_manager.get_all_neighbors(target):
		if _grid_manager.is_walkable(neighbor):
			var d = _heuristic(neighbor, fallback_toward)
			if d < best_dist:
				best_dist = d
				best = neighbor
	return best
func _heuristic(a: Vector2i, b: Vector2i) -> float:
	var aq := _offset_to_axial(a)
	var bq := _offset_to_axial(b)

	var dq: int = bq.x - aq.x
	var dr: int = bq.y - aq.y

	return float((abs(dq) + abs(dq + dr) + abs(dr)) / 2)

func _offset_to_axial(pos: Vector2i) -> Vector2i:
	var q: int = pos.x - (pos.y - (pos.y & 1)) / 2
	var r: int = pos.y
	return Vector2i(q, r)

func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [current]

	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)

	path.pop_front()
	return path
