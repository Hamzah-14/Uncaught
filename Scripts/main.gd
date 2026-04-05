class_name ArenaController
extends Node3D

@export var csp_generator: CSPGenerator
@export var game_manager: GameManager
@export var grid_manager: GridManager
@export var world_render: WorldRenderer
 
var _retry_count: int = 0
var _max_retries: int = 5 # Failsafe

func _ready() -> void:
	# call_deferred ensures all child nodes (UI, renderers) are fully initialized 
	# before we start blasting them with signals.
	call_deferred("_start_sequence")

func _start_sequence() -> void:
	print("Generating flat test arena...")
	for x in range(grid_manager.width):
		for y in range(grid_manager.height):
			grid_manager.set_cell(Vector2i(x, y), GridManager.CellType.FLOOR)
			print(grid_manager.grid_to_world(Vector2i(grid_manager.width, grid_manager.height)))
			#if x == 0 or x == grid_manager.width - 1 or y == 0 or y == grid_manager.height - 1:
				#grid_manager.set_cell(Vector2i(x, y), GridManager.CellType.WALL)
			#else:
				#grid_manager.set_cell(Vector2i(x, y), GridManager.CellType.FLOOR)
	#
	world_render.render_grid()
	game_manager.start_bout()
	print("Test floor built.")
	
#func _start_sequence() -> void:
	#print("Sequence Initiated: Rebuilding Coliseum...")
	#_retry_count = 0
	## Listen for when the CSP finishes its job
	#csp_generator.generation_complete.connect(_on_generation_complete)
	## Turn the key. This will trigger the DebugOverlay and WorldRenderer.
	#csp_generator.generate_arena()

func _on_generation_complete(success: bool) -> void:
	if success:
		print("Coliseum rebuilt successfully. Starting Bout.")
		game_manager.start_bout()
	else:
		_retry_count += 1
		if _retry_count >= _max_retries:
			push_error("CRITICAL: Arena generation failed max retries. Map layout is broken.")
			return # Halt execution so the engine doesn't freeze
			
		print("Arena generation failed constraints. Retrying (", _retry_count, "/", _max_retries, ")...")
		csp_generator.generate_arena()
