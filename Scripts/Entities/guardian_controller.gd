class_name GuardianController
extends CharacterBody3D

@export var walk_speed: float = 4.0
@export var sprint_speed: float = 7.0

# Node references — set these in the Godot Inspector
@export var grid_manager_path: NodePath
@export var game_manager_path: NodePath

var _grid_manager: GridManager
var _game_manager: GameManager
var _astar: DynamicAStar
var _state_machine: GuardianStateMachine

var _current_path: Array[Vector2i] = []
var _path_update_timer: float = 0.0
var _path_update_interval: float = 0.3

var _player: PlayerController
var _can_move: bool = true

func _ready() -> void:
	# Get references
	_grid_manager = get_node(grid_manager_path)
	_game_manager = get_node(game_manager_path)
	
	# Find player in scene
	_player = get_tree().get_first_node_in_group("player")
	
	# Set up A*
	_astar = DynamicAStar.new()
	_astar.setup(_grid_manager)
	
	# Set up state machine
	_state_machine = GuardianStateMachine.new()
	add_child(_state_machine)

func _physics_process(delta: float) -> void:
	if not _can_move or _player == null:
		return
	
	# 1. Get positions on grid
	var my_grid_pos: Vector2i = _grid_manager.world_to_grid(global_position)
	var player_grid_pos: Vector2i = _grid_manager.world_to_grid(_player.global_position)
	
	# 2. Check line of sight to player
	var player_visible: bool = _check_line_of_sight()
	
	# 3. Calculate distance in tiles
	var distance: float = float((abs(player_grid_pos.x - my_grid_pos.x) 
		+ abs(player_grid_pos.y - my_grid_pos.y)))
	
	# 4. Get player movement direction
	var player_dir: Vector2i = Vector2i(
		sign(_player.velocity.x),
		sign(_player.velocity.z)
	)
	
	# 5. Check ember possession from GameManager
	var player_holds_ember: bool = (
		_game_manager._current_holder == GameManager.Holder.PLAYER
	)
	var guardian_holds_ember: bool = (
		_game_manager._current_holder == GameManager.Holder.GUARDIAN
	)
	
	# 6. Feed all sensor data into state machine
	_state_machine.update_sensors(
		player_visible,
		player_holds_ember,
		guardian_holds_ember,
		distance,
		player_grid_pos,
		player_dir
	)
	
	# 7. Replan path periodically
	_path_update_timer += delta
	if _path_update_timer >= _path_update_interval:
		_path_update_timer = 0.0
		var goal: Vector2i = _state_machine.get_goal()
		_current_path = _astar.find_path(my_grid_pos, goal)
	
	# 8. Move along path
	_follow_path(delta)

func _follow_path(delta: float) -> void:
	if _current_path.is_empty():
		velocity = Vector3.ZERO
		move_and_slide()
		return
	
	# Get next tile target in world space
	var next_tile: Vector2i = _current_path[0]
	var target_world: Vector3 = _grid_manager.grid_to_world(next_tile, global_position.y)
	
	# Move toward it
	var direction: Vector3 = (target_world - global_position)
	direction.y = 0.0
	
	var speed: float = sprint_speed if (
		_state_machine.current_mode == GuardianStateMachine.Mode.AGGRESSIVE
	) else walk_speed
	
	if direction.length() > 0.1:
		velocity.x = direction.normalized().x * speed
		velocity.z = direction.normalized().z * speed
		look_at(global_position + Vector3(direction.x, 0, direction.z), Vector3.UP)
	else:
		# Reached this tile, move to next
		_current_path.pop_front()
		velocity.x = 0
		velocity.z = 0
	
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	
	move_and_slide()

func _check_line_of_sight() -> bool:
	if _player == null:
		return false
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position,
		_player.global_position
	)
	query.exclude = [self]
	query.collision_mask = 1 # Only check environment layer
	
	var result = space_state.intersect_ray(query)
	# If nothing blocks the ray, we can see the player
	return result.is_empty()

# Called by power-ups
func freeze(duration: float) -> void:
	_can_move = false
	await get_tree().create_timer(duration).timeout
	_can_move = true
