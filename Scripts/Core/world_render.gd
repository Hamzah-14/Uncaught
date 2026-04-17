class_name WorldRenderer
extends Node3D

@export var game_manager: GameManager
@export var grid_manager: GridManager
@export var csp_generator: CSPGenerator
@export var ember_scene: PackedScene
@export_category("KayKit Hex Assets")
@export var floor_mesh: PackedScene
@export var wall_mesh: PackedScene
@export var sanctum_mesh: PackedScene
@export var floor_high_mesh: PackedScene
@export var bridge_mesh: PackedScene
@export var hazard_collapse_mesh: PackedScene
@export var hazard_trap_mesh: PackedScene
@export var river_shore_mesh: PackedScene
@export var river_water_mesh: PackedScene

var _spawned_ember: Node3D = null
var _spawned_tiles: Dictionary = {}

func _ready() -> void:
	if csp_generator:
		csp_generator.cell_assigned.connect(_on_cell_assigned)
		csp_generator.backtracked.connect(_on_backtracked)
		csp_generator.generation_started.connect(_on_generation_started)
		csp_generator.generation_complete.connect(_on_generation_complete)

func render_grid() -> void:
	_clear_world()
	for pos in grid_manager._grid.keys():
		_on_cell_assigned(pos, grid_manager.get_cell(pos))

func _on_generation_started() -> void:
	_clear_world()

func _on_cell_assigned(grid_pos: Vector2i, type: int) -> void:
	_remove_tile_at(grid_pos)

	var instance: Node3D = null
	var y_offset: float = 0.0

	match type:
		GridManager.CellType.BLOCKED:
			if floor_high_mesh: instance = floor_high_mesh.instantiate()
		GridManager.CellType.FLOOR:
			if floor_mesh: instance = floor_mesh.instantiate()
		GridManager.CellType.FLOOR_HIGH:
			if floor_high_mesh: instance = floor_high_mesh.instantiate()
		GridManager.CellType.RIVER_SHORE:
			if river_shore_mesh: instance = river_shore_mesh.instantiate()
		GridManager.CellType.RIVER_WATER:
			if river_water_mesh: instance = river_water_mesh.instantiate()
			y_offset = -0.1
		GridManager.CellType.BRIDGE:
			if bridge_mesh: instance = bridge_mesh.instantiate()
			y_offset = 0.0
		GridManager.CellType.SANCTUM:
			if sanctum_mesh: instance = sanctum_mesh.instantiate()
		GridManager.CellType.HAZARD_COLLAPSE:
			if hazard_collapse_mesh: instance = hazard_collapse_mesh.instantiate()
			elif floor_mesh: instance = floor_mesh.instantiate()
		GridManager.CellType.HAZARD_TRAP:
			if hazard_trap_mesh: instance = hazard_trap_mesh.instantiate()
			elif floor_mesh: instance = floor_mesh.instantiate()

	if instance:
		add_child(instance)
		instance.global_position = grid_manager.grid_to_world(grid_pos, y_offset)
		_spawned_tiles[grid_pos] = instance

func _on_backtracked(grid_pos: Vector2i) -> void:
	_remove_tile_at(grid_pos)

func _on_generation_complete(success: bool) -> void:
	if not success:
		return
	if ember_scene:
		_spawned_ember = ember_scene.instantiate()
		add_child(_spawned_ember)
		_spawned_ember.game_manager = game_manager
		_spawned_ember.global_position = grid_manager.grid_to_world(csp_generator._center_pos)

func _remove_tile_at(grid_pos: Vector2i) -> void:
	if _spawned_tiles.has(grid_pos):
		_spawned_tiles[grid_pos].queue_free()
		_spawned_tiles.erase(grid_pos)

func _clear_world() -> void:
	for pos in _spawned_tiles.keys():
		if is_instance_valid(_spawned_tiles[pos]):
			_spawned_tiles[pos].queue_free()
	_spawned_tiles.clear()
