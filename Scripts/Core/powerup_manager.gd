class_name PowerupManager
extends Node

enum PowerupType { FREEZE, SLOW_FIELD, SPEED_BOOST, SHIELD, PHASE_DASH, FRUIT_WIPE, PULL }

@export var grid_manager: GridManager
@export var max_active: int = 3
@export var respawn_delay: float = 15.0
@export var pickup_distance: float = 1.5

var _powerups: Array[Dictionary] = []
var _active_count: int = 0
var _player: PlayerController
var _guardian: GuardianController
var _current_round: int = 1

func setup(gm: GridManager) -> void:
	grid_manager = gm
	_player = get_tree().get_first_node_in_group("player") as PlayerController
	_guardian = get_tree().get_first_node_in_group("guardian") as GuardianController
	for i in max_active:
		_spawn_one()

func set_round(n: int) -> void:
	_current_round = n

func _process(_delta: float) -> void:
	if grid_manager == null:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as PlayerController
	if _guardian == null:
		_guardian = get_tree().get_first_node_in_group("guardian") as GuardianController

	var to_remove: Array[int] = []

	for i in range(_powerups.size()):
		var pup: Dictionary = _powerups[i]
		if not is_instance_valid(pup["node"]):
			to_remove.append(i)
			continue
		var collector: Node = _nearest_in_range(pup["node"].global_position, pickup_distance)
		if collector != null:
			# Guardian-only types are completely invisible to the player —
			# skip collection, removal, and respawn entirely.
			if collector == _player and pup["type"] in [PowerupType.FRUIT_WIPE, PowerupType.PULL]:
				continue
			_apply_collectible(pup["type"], collector)
			pup["node"].queue_free()
			to_remove.append(i)

	# Remove in reverse so earlier indices stay valid
	for i in range(to_remove.size() - 1, -1, -1):
		_powerups.remove_at(to_remove[i])
		_active_count -= 1
		get_tree().create_timer(respawn_delay).timeout.connect(_spawn_one)

func _apply_collectible(type: PowerupType, collector: Node) -> void:
	var is_player := collector == _player
	var who: String = "player" if is_player else "guardian"

	match type:
		PowerupType.FREEZE:
			if collector.has_method("collect_powerup"):
				collector.collect_powerup("freeze")
			print("FREEZE collected by ", who)

		PowerupType.SLOW_FIELD:
			if collector.has_method("collect_powerup"):
				collector.collect_powerup("slow_field")
			print("SLOW TRAP collected by ", who, " — stored in hotbar")

		PowerupType.SPEED_BOOST:
			if collector.has_method("collect_powerup"):
				collector.collect_powerup("speed_boost")
			print("SPEED BOOST collected by ", who, " — 1.5x for 4s")

		PowerupType.SHIELD:
			# Player-only — guardian collecting it has no effect.
			if not is_player:
				print("SHIELD picked up by guardian — no effect")
				return
			if collector.has_method("collect_powerup"):
				collector.collect_powerup("shield")
			print("SHIELD collected by player — stored in hotbar")

		PowerupType.PHASE_DASH:
			if collector.has_method("collect_powerup"):
				collector.collect_powerup("phase_dash")
			print("PHASE DASH collected by ", who, " — stored in hotbar")

		PowerupType.FRUIT_WIPE:
			# Guardian-only — player cannot collect this.
			if is_player:
				print("Fruit Wipe is Guardian only")
				return
			if collector.has_method("collect_powerup"):
				collector.collect_powerup("fruit_wipe")
			print("FRUIT WIPE collected by guardian — stored in hotbar")

		PowerupType.PULL:
			# Guardian-only.
			if collector.has_method("collect_powerup"):
				collector.collect_powerup("pull")
			print("PULL collected by guardian — stored in hotbar")

func _nearest_in_range(pos: Vector3, radius: float) -> Node:
	if _player and _player.global_position.distance_to(pos) <= radius:
		return _player
	if _guardian and _guardian.global_position.distance_to(pos) <= radius:
		return _guardian
	return null

func _spawn_one() -> void:
	if _active_count >= max_active:
		return
	var pos: Vector2i = _random_walkable_pos()
	if pos == Vector2i(-1, -1):
		return

	# Build the eligible type pool. FRUIT_WIPE is rare — only available from round 2.
	# SHIELD is rare (half weight); PHASE_DASH is equal weight to common types.
	var pool: Array = [
		PowerupType.FREEZE,      PowerupType.FREEZE,
		PowerupType.SLOW_FIELD,  PowerupType.SLOW_FIELD,
		PowerupType.SPEED_BOOST, PowerupType.SPEED_BOOST,
		PowerupType.PHASE_DASH,  PowerupType.PHASE_DASH,
		PowerupType.SHIELD,
	]
	if _current_round >= 2:
		pool.append(PowerupType.FRUIT_WIPE)
		pool.append(PowerupType.PULL)

	var type: PowerupType = pool[randi() % pool.size()] as PowerupType

	var node := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	node.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	match type:
		PowerupType.FREEZE:
			mat.albedo_color = Color(0.4, 0.9, 1.0)
			mat.emission = Color(0.2, 0.5, 1.0)
		PowerupType.SLOW_FIELD:
			mat.albedo_color = Color(1.0, 0.85, 0.1)
			mat.emission = Color(0.8, 0.5, 0.0)
		PowerupType.SPEED_BOOST:
			mat.albedo_color = Color(0.2, 1.0, 0.4)
			mat.emission = Color(0.0, 0.7, 0.2)
		PowerupType.SHIELD:
			mat.albedo_color = Color(1.0, 1.0, 1.0)
			mat.emission = Color(0.6, 0.6, 0.8)
		PowerupType.PHASE_DASH:
			mat.albedo_color = Color(0.7, 0.2, 1.0)
			mat.emission = Color(0.4, 0.0, 0.8)
		PowerupType.FRUIT_WIPE:
			mat.albedo_color = Color(1.0, 0.15, 0.15)
			mat.emission = Color(0.8, 0.0, 0.0)
		PowerupType.PULL:
			mat.albedo_color = Color(1.0, 0.45, 0.1)
			mat.emission = Color(0.9, 0.25, 0.0)
	node.material_override = mat

	add_child(node)
	node.global_position = grid_manager.grid_to_world(pos, 0.5)

	_powerups.append({"type": type, "node": node})
	_active_count += 1

func _random_walkable_pos() -> Vector2i:
	var center := Vector2i(grid_manager.width / 2, grid_manager.height / 2)
	var occupied: Array[Vector2i] = []
	for pup in _powerups:
		if is_instance_valid(pup["node"]):
			occupied.append(grid_manager.world_to_grid(pup["node"].global_position))

	var candidates: Array[Vector2i] = []
	for x in range(2, grid_manager.width - 2):
		for y in range(2, grid_manager.height - 2):
			var pos := Vector2i(x, y)
			if grid_manager.is_walkable(pos) and pos != center and pos not in occupied:
				candidates.append(pos)

	if candidates.is_empty():
		return Vector2i(-1, -1)
	return candidates[randi() % candidates.size()]
