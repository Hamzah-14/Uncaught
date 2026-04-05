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

var _spawned_ember: Node3D = null
# Keep track of spawned meshes to clear them between rounds
var _spawned_tiles: Dictionary = {}


func render_grid() -> void:
	_clear_world()
	for pos in grid_manager._grid.keys():
		_on_cell_assigned(pos, grid_manager.get_cell(pos))
		
func _ready() -> void:
	if csp_generator:
		# We hook into cell_assigned to build the world live as the CSP thinks
		csp_generator.cell_assigned.connect(_on_cell_assigned)
		csp_generator.backtracked.connect(_on_backtracked)
		csp_generator.generation_started.connect(_on_generation_started)
		csp_generator.generation_complete.connect(_on_generation_complete)
		
func _on_generation_started() -> void:
	_clear_world()
	
	
func _on_cell_assigned(grid_pos: Vector2i, type: int) -> void:
	# If a tile is already here (due to backtracking), remove it first
	_remove_tile_at(grid_pos)
	
	var instance: Node3D = null
	match type:
		GridManager.CellType.FLOOR:
			if floor_mesh: instance = floor_mesh.instantiate()
		#GridManager.CellType.WALL:
			#if wall_mesh: instance = wall_mesh.instantiate()
		GridManager.CellType.SANCTUM:
			if sanctum_mesh: instance = sanctum_mesh.instantiate()
			
	if instance:
		add_child(instance)
		# Ask GridManager where this hex belongs in continuous 3D space
		instance.global_position = grid_manager.grid_to_world(grid_pos)
		_spawned_tiles[grid_pos] = instance

func _on_backtracked(grid_pos: Vector2i) -> void:
	# The CSP solver hit a dead end, visually destroy the tile
	_remove_tile_at(grid_pos)

func _remove_tile_at(grid_pos: Vector2i) -> void:
	if _spawned_tiles.has(grid_pos):
		var tile = _spawned_tiles[grid_pos]
		tile.queue_free()
		_spawned_tiles.erase(grid_pos)
func _on_generation_complete(success: bool) -> void:
	if not success:
		return # Do not spawn the Ember if the map failed to build
		
	if ember_scene:
		# 1. Instantiate the object
		_spawned_ember = ember_scene.instantiate()
		
		# 2. Add it to the 3D world
		add_child(_spawned_ember)
		
		# 3. Inject the GameManager dependency via code
		_spawned_ember.game_manager = game_manager
		
		# 4. Position it at the exact center hex
		_spawned_ember.global_position = grid_manager.grid_to_world(csp_generator._center_pos)
func _clear_world() -> void:
	for pos in _spawned_tiles.keys():
		if is_instance_valid(_spawned_tiles[pos]):
			_spawned_tiles[pos].queue_free()
	_spawned_tiles.clear()
	
	# Delete the old Ember if it exists
	if is_instance_valid(_spawned_ember):
		_spawned_ember.queue_free()
		_spawned_ember = null
