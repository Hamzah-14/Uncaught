class_name EmberObject
extends Area3D

@export var neutral_wait_time: float = 3.0
@export var pickup_distance: float = 2.0

var _game_manager: GameManager
var _grid_manager: GridManager
var _is_neutral: bool = false
var _holder = null

func setup(game_manager: GameManager, grid_manager: GridManager) -> void:
	_game_manager = game_manager
	_grid_manager = grid_manager

func _ready() -> void:
	pass

func _physics_process(_delta: float) -> void:
	if _is_neutral or _holder != null:
		return
	
	var player = get_tree().get_first_node_in_group("player")
	var guardian = get_tree().get_first_node_in_group("guardian")
	
	if player and global_position.distance_to(player.global_position) < pickup_distance:
		print("Player picked up ember!")
		_pick_up(player, GameManager.Holder.PLAYER)
	elif guardian and global_position.distance_to(guardian.global_position) < pickup_distance:
		print("Guardian picked up ember!")
		_pick_up(guardian, GameManager.Holder.GUARDIAN)

func _pick_up(target: Node3D, holder_type: GameManager.Holder) -> void:
	_holder = target
	_game_manager.set_ember_holder(holder_type)
	var old_parent = get_parent()
	old_parent.remove_child(self)
	target.add_child(self)
	position = Vector3(0, 1.5, 0)
	print("Ember picked up by: ", GameManager.Holder.keys()[holder_type])

func drop() -> void:
	if _holder == null:
		return
	var arena = get_tree().get_root().get_node("Arena")
	_holder.remove_child(self)
	arena.add_child(self)
	var drop_pos = _grid_manager.world_to_grid(global_position)
	global_position = _grid_manager.grid_to_world(drop_pos, 0.5)
	_holder = null
	_is_neutral = true
	_game_manager.set_ember_holder(GameManager.Holder.NONE)
	await get_tree().create_timer(neutral_wait_time).timeout
	_is_neutral = false
