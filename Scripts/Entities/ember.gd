class_name EmberObject
extends Node3D

@export var neutral_wait_time: float = 3.0
@export var pickup_distance: float = 2.0

var _game_manager: GameManager
var _grid_manager: GridManager
var _arena: Node3D
var _immune_holder: Node3D = null
var _is_transferring: bool = false  # ← add this
var _is_neutral: bool = false
var _holder: Node3D = null

# Setup references (called from ArenaController)
func setup(game_manager: GameManager, grid_manager: GridManager, arena: Node3D) -> void:
	_game_manager = game_manager
	_grid_manager = grid_manager
	_arena = arena

func _physics_process(_delta: float) -> void:
	# Do nothing if already held or in neutral cooldown
	if _is_neutral or _holder != null:
		return
	
	var player = get_tree().get_first_node_in_group("player")
	var guardian = get_tree().get_first_node_in_group("guardian")
	
	# Pickup checks (distance-based, deterministic)
	if player and global_position.distance_to(player.global_position) < pickup_distance:
		_pick_up(player, GameManager.Holder.PLAYER)

	elif guardian and global_position.distance_to(guardian.global_position) < pickup_distance:
		_pick_up(guardian, GameManager.Holder.GUARDIAN)

# Attach Ember to holder
func _pick_up(target: Node3D, holder_type: GameManager.Holder) -> void:
	if _is_neutral:
		return
	_holder = target
	_game_manager.set_ember_holder(holder_type)

	# Reparent to holder
	get_parent().remove_child(self)
	target.add_child(self)

	# Position above holder (local space)
	position = Vector3(0, 2.1, 0)

	print("Ember picked up by: ", GameManager.Holder.keys()[holder_type])

# Drop Ember to nearest grid tile
func drop() -> void:
	if _holder == null:
		return
	
	# Bypass transform propagation lag — use holder position directly
	var world_pos = _holder.global_position + Vector3(0, 2.3, 0)
	
	_holder.remove_child(self)
	_arena.add_child(self)
	
	var drop_grid = _grid_manager.world_to_grid(world_pos)
	global_position = _grid_manager.grid_to_world(drop_grid, 0.5)
	
	_holder = null
	_is_neutral = true
	_game_manager.set_ember_holder(GameManager.Holder.NONE)
	print("Ember dropped at grid: ", drop_grid)
	
	await get_tree().create_timer(neutral_wait_time).timeout
	if _holder == null:
		_is_neutral = false
		
func transfer(new_holder: Node3D, holder_type: GameManager.Holder) -> void:
	if _holder == null or _is_transferring:
		return
	_is_transferring = true
	var old_holder = _holder
	_holder.remove_child(self)
	new_holder.add_child(self)
	position = Vector3(0, 2.1, 0)
	_holder = new_holder
	_immune_holder = new_holder
	_game_manager.set_ember_holder(holder_type)
	print("Ember transferred to: ", GameManager.Holder.keys()[holder_type])
	# Apply slow to whoever lost it
	if old_holder.has_method("apply_slow"):
		old_holder.apply_slow(0.2, 2.0)
	# Immunity window for new holder
	await get_tree().create_timer(1.5).timeout
	_immune_holder = null
	_is_transferring = false
func is_immune(node: Node3D) -> bool:
	if _immune_holder == node:
		return true
	# Shield makes the player immune to being tagged while active.
	if node is PlayerController and (node as PlayerController)._is_shielded:
		return true
	return false
