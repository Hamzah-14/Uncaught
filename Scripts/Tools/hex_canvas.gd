class_name HexCanvas
extends Control

signal tile_painted(grid_pos: Vector2i, type: int)
signal hovered(grid_pos: Vector2i)

const DISPLAY_SIZE: float = 28.0
const HEX_WIDTH_MULT: float = 1.7320508
const HEX_HEIGHT_MULT: float = 1.5
const GRID_W: int = 17
const GRID_H: int = 17

var grid: Dictionary = {}
var active_tool: int = 0
var _painting: bool = false
var _hovered_cell: Vector2i = Vector2i(-1, -1)

const COLORS = {
	0: Color(0.22, 0.45, 0.15),       # FLOOR - dark green
	1: Color(0.42, 0.32, 0.18),       # FLOOR_HIGH - brown
	2: Color(0.18, 0.45, 0.72),       # RIVER_WATER - blue
	3: Color(0.42, 0.72, 0.55),       # RIVER_SHORE - teal green
	4: Color(0.55, 0.45, 0.35),       # BRIDGE - tan
	5: Color(0.55, 0.25, 0.65),       # SANCTUM - purple
	6: Color(0.75, 0.22, 0.15),       # HAZARD_COLLAPSE - red
	7: Color(0.80, 0.45, 0.10),       # HAZARD_TRAP - orange
	-1: Color(0.10, 0.10, 0.10),      # EMPTY - near black
}

const TYPE_NAMES = {
	0: "FLOOR",
	1: "FLOOR_HIGH",
	2: "RIVER_WATER",
	3: "RIVER_SHORE",
	4: "BRIDGE",
	5: "SANCTUM",
	6: "HAZARD_COLLAPSE",
	7: "HAZARD_TRAP",
	-1: "EMPTY"
}

func _ready() -> void:
	set_process_input(true)
	custom_minimum_size = Vector2(
		DISPLAY_SIZE * HEX_WIDTH_MULT * (GRID_W + 0.5) + 20,
		DISPLAY_SIZE * HEX_HEIGHT_MULT * GRID_H + DISPLAY_SIZE + 20
	)
	clear()

func clear() -> void:
	grid.clear()
	for x in range(GRID_W):
		for y in range(GRID_H):
			grid[Vector2i(x, y)] = 0
	queue_redraw()

func _hex_center(col: int, row: int) -> Vector2:
	var is_odd = row % 2 == 1
	var x = 10 + (col + (0.5 if is_odd else 0.0)) * DISPLAY_SIZE * HEX_WIDTH_MULT
	var y = 10 + row * DISPLAY_SIZE * HEX_HEIGHT_MULT + DISPLAY_SIZE
	return Vector2(x, y)

func _hex_polygon(cx: float, cy: float) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in range(6):
		var angle = PI / 3.0 * i - PI / 6.0
		pts.append(Vector2(cx + DISPLAY_SIZE * cos(angle), cy + DISPLAY_SIZE * sin(angle)))
	return pts

func _world_to_grid(px: float, py: float) -> Vector2i:
	var best = Vector2i(-1, -1)
	var best_d = INF
	for row in range(GRID_H):
		for col in range(GRID_W):
			var c = _hex_center(col, row)
			var d = (px - c.x) ** 2 + (py - c.y) ** 2
			if d < best_d:
				best_d = d
				best = Vector2i(col, row)
	return best

func _draw() -> void:
	var center = Vector2i(GRID_W / 2, GRID_H / 2)
	for row in range(GRID_H):
		for col in range(GRID_W):
			var pos = Vector2i(col, row)
			var t = grid.get(pos, 0)
			var c = _hex_center(col, row)
			var poly = _hex_polygon(c.x, c.y)
			var color = COLORS.get(t, COLORS[0])
			
			# Hover highlight
			if pos == _hovered_cell:
				color = color.lightened(0.25)
			
			draw_polygon(poly, [color])
			
			# Border
			var border_color = Color(0, 0, 0, 0.3)
			if pos == _hovered_cell:
				border_color = Color(1, 1, 1, 0.8)
			for i in range(6):
				draw_line(poly[i], poly[(i + 1) % 6], border_color, 0.5)
			
			# Center marker
			if pos == center:
				draw_circle(c, 4.0, Color(1.0, 0.9, 0.1))
			
			# Coord label on hover
			if pos == _hovered_cell:
				draw_string(ThemeDB.fallback_font, c + Vector2(-10, 4), 
					str(col) + "," + str(row), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_painting = event.pressed
			if event.pressed:
				_paint_at(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var pos = _world_to_grid(event.position.x, event.position.y)
			if pos.x >= 0:
				grid[pos] = 0
				queue_redraw()
				emit_signal("tile_painted", pos, 0)
	
	elif event is InputEventMouseMotion:
		var pos = _world_to_grid(event.position.x, event.position.y)
		if pos != _hovered_cell:
			_hovered_cell = pos
			queue_redraw()
			emit_signal("hovered", pos)
		if _painting:
			_paint_at(event.position)

func _paint_at(mouse_pos: Vector2) -> void:
	var pos = _world_to_grid(mouse_pos.x, mouse_pos.y)
	if pos.x < 0:
		return
	# Protect center from being overwritten
	var center = Vector2i(GRID_W / 2, GRID_H / 2)
	if pos == center:
		return
	grid[pos] = active_tool
	queue_redraw()
	emit_signal("tile_painted", pos, active_tool)

func get_tile_counts() -> Dictionary:
	var counts = {}
	for t in TYPE_NAMES:
		counts[t] = 0
	for pos in grid:
		var t = grid[pos]
		if counts.has(t):
			counts[t] += 1
	return counts

func load_from_dict(cells: Dictionary) -> void:
	clear()
	for pos in cells:
		grid[pos] = cells[pos]
	queue_redraw()
