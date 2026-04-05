class_name ArenaController
extends Node3D

@export var csp_generator: CSPGenerator
@export var game_manager: GameManager
@export var grid_manager: GridManager
@export var world_render: WorldRenderer

var _retry_count: int = 0
var _max_retries: int = 5

func _ready() -> void:
	call_deferred("_start_sequence")

func _start_sequence() -> void:
	print("Generating flat test arena...")
	for x in range(grid_manager.width):
		for y in range(grid_manager.height):
			grid_manager.set_cell(Vector2i(x, y), GridManager.CellType.FLOOR)
	grid_manager.set_cell(Vector2i(5, 5), GridManager.CellType.WALL)
	grid_manager.set_cell(Vector2i(5, 6), GridManager.CellType.WALL)
	grid_manager.set_cell(Vector2i(5, 7), GridManager.CellType.WALL)
	world_render.render_grid()
	
	# Spawn ember
	var ember_scene = preload("res://Scenes/Ember.tscn")
	var ember = ember_scene.instantiate()
	add_child(ember)
	ember.collision_mask = 0xFFFFFFFF
	var center = Vector2i(grid_manager.width / 2, grid_manager.height / 2)
	ember.global_position = grid_manager.grid_to_world(center, 0.5)
	ember.setup(game_manager, grid_manager)
	ember.add_to_group("ember")
	
	# Spawn first freeze powerup then keep respawning
	_spawn_freeze()
	
	game_manager.start_bout()

func _spawn_freeze() -> void:
	var freeze_scene = preload("res://Scenes/Entities/FreezePowerup.tscn")
	var freeze = freeze_scene.instantiate()
	add_child(freeze)
	# Random position on the map
	var rx = randi_range(3, grid_manager.width - 3)
	var ry = randi_range(3, grid_manager.height - 3)
	freeze.global_position = grid_manager.grid_to_world(Vector2i(rx, ry), 0.5)
	# When collected, wait 15 seconds then respawn
	freeze.collected.connect(_on_freeze_collected)

func _on_freeze_collected() -> void:
	print("Freeze collected - respawning in 15 seconds...")
	await get_tree().create_timer(15.0).timeout
	_spawn_freeze()

func _on_generation_complete(success: bool) -> void:
	if success:
		print("Coliseum rebuilt successfully. Starting Bout.")
		game_manager.start_bout()
	else:
		_retry_count += 1
		if _retry_count >= _max_retries:
			push_error("CRITICAL: Arena generation failed max retries. Map layout is broken.")
			return
		print("Arena generation failed constraints. Retrying (", _retry_count, "/", _max_retries, ")...")
		csp_generator.generate_arena()
