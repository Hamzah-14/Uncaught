class_name DebugOverlay
extends Control

@export var grid_manager: GridManager
@export var csp_generator: CSPGenerator

# Visual state tracking
var _evaluating_cell: Vector2i = Vector2i(-1, -1)
var _backtracked_cells: Array[Vector2i] = []

# Padding to keep the grid centered and off screen edges
var padding: float = 40.0

func _ready() -> void:
	# Ensure the UI updates dynamically
	set_process(false) # We rely on signal-driven redraws, not per-frame processing
	
	if csp_generator:
		csp_generator.generation_started.connect(_on_generation_started)
		csp_generator.cell_evaluating.connect(_on_cell_evaluating)
		csp_generator.cell_assigned.connect(_on_cell_assigned)
		csp_generator.backtracked.connect(_on_backtracked)
		csp_generator.generation_complete.connect(_on_generation_complete)

# The Drawing Engine

func _draw() -> void:
	if not grid_manager or grid_manager.width == 0: 
		return

	# Calculate tile pixel size to fit the screen perfectly
	var available_size = size - Vector2(padding * 2, padding * 2)
	var cell_px = min(available_size.x / grid_manager.width, available_size.y / grid_manager.height)
	
	# Center the grid on the screen
	var grid_px_width = grid_manager.width * cell_px
	var grid_px_height = grid_manager.height * cell_px
	var offset = Vector2((size.x - grid_px_width) / 2.0, (size.y - grid_px_height) / 2.0)

	# Paint the grid
	for x in range(grid_manager.width):
		for y in range(grid_manager.height):
			var pos = Vector2i(x, y)
			var rect = Rect2(offset.x + x * cell_px, offset.y + y * cell_px, cell_px, cell_px)

			# 1. Base Tile Colors
			var type = grid_manager.get_cell(pos)
			var color = Color(0.1, 0.1, 0.1, 0.8) # Default / Empty Dark Gray

			match type:
				#GridManager.CellType.WALL:
					#color = Color.DARK_SLATE_GRAY
				GridManager.CellType.FLOOR:
					color = Color.DARK_GRAY
				GridManager.CellType.SANCTUM:
					color = Color.PURPLE
				GridManager.CellType.HAZARD_COLLAPSE:
					color = Color.ORANGE
				GridManager.CellType.HAZARD_TRAP:
					color = Color.CRIMSON
			
			draw_rect(rect, color, true) # Filled base
			draw_rect(rect, Color.BLACK, false, 1.0) # Grid outline

			# 2. Backtrack Visualizer (Flashes of red where the algorithm hit a dead end)
			if pos in _backtracked_cells:
				draw_rect(rect, Color(0.8, 0.1, 0.1, 0.6), true) 

			# 3. Active Evaluation Visualizer (Thick yellow outline showing the solver's current focus)
			if pos == _evaluating_cell:
				draw_rect(rect, Color.YELLOW, false, 3.0)

# Signal Listeners

func _on_generation_started() -> void:
	_backtracked_cells.clear()
	_evaluating_cell = Vector2i(-1, -1)
	queue_redraw()

func _on_cell_evaluating(pos: Vector2i, _domains: Array) -> void:
	_evaluating_cell = pos
	queue_redraw() # Triggers the _draw() function to update the screen

func _on_cell_assigned(pos: Vector2i, _type: int) -> void:
	_backtracked_cells.erase(pos) # Remove backtrack red if successfully assigned over
	queue_redraw()

func _on_backtracked(pos: Vector2i) -> void:
	if not _backtracked_cells.has(pos):
		_backtracked_cells.append(pos)
	queue_redraw()

func _on_generation_complete(_success: bool) -> void:
	_evaluating_cell = Vector2i(-1, -1)
	_backtracked_cells.clear()
	queue_redraw()
	
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
