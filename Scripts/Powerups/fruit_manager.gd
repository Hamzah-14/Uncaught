class_name FruitManager
extends Node

@export var grid_manager: GridManager
@export var max_fruits: int = 3
@export var respawn_delay: float = 22.0
@export var pickup_distance: float = 1.5
@export var stamina_restore_amount: float = 20.0  # flat stamina restored on pickup

var _fruits: Array[Dictionary] = []
var _active_count: int = 0
var _player: PlayerController
var _fruit_spawn_blocked: bool = false

func setup(gm: GridManager) -> void:
	grid_manager = gm
	_player = get_tree().get_first_node_in_group("player") as PlayerController
	for i in max_fruits:
		_spawn_one()

func _process(_delta: float) -> void:
	if grid_manager == null:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as PlayerController
	if _player == null:
		return

	var to_remove: Array[int] = []

	for i in range(_fruits.size()):
		var fruit: Dictionary = _fruits[i]
		if not is_instance_valid(fruit["node"]):
			to_remove.append(i)
			continue
		if _player.global_position.distance_to(fruit["node"].global_position) <= pickup_distance:
			_player.restore_stamina(stamina_restore_amount)
			fruit["node"].queue_free()
			to_remove.append(i)
			print("Fruit collected — stamina restored +", stamina_restore_amount)

	for i in range(to_remove.size() - 1, -1, -1):
		_fruits.remove_at(to_remove[i])
		_active_count -= 1
		get_tree().create_timer(respawn_delay).timeout.connect(_spawn_one)

func _spawn_one() -> void:
	if _fruit_spawn_blocked:
		return
	if _active_count >= max_fruits:
		return
	var pos: Vector2i = _random_walkable_pos()
	if pos == Vector2i(-1, -1):
		return

	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 0.3, 0.3)
	node.mesh = box

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.88, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.45, 0.0)
	node.material_override = mat

	node.add_to_group("fruit")
	add_child(node)
	node.global_position = grid_manager.grid_to_world(pos, 0.4)

	_fruits.append({"node": node})
	_active_count += 1

# Removes all active fruit nodes immediately, blocks respawns for 3 seconds.
# Called by the guardian's FRUIT_WIPE powerup.
func wipe_fruits() -> void:
	for fruit in _fruits:
		if is_instance_valid(fruit["node"]):
			fruit["node"].queue_free()
	_fruits.clear()
	_active_count = 0
	_fruit_spawn_blocked = true
	_unblock_after_delay()
	print("Fruit Wipe — all fruits cleared, respawn blocked for 3s")

func _unblock_after_delay() -> void:
	await get_tree().create_timer(3.0).timeout
	_fruit_spawn_blocked = false

func _random_walkable_pos() -> Vector2i:
	var center := Vector2i(grid_manager.width / 2, grid_manager.height / 2)
	var occupied: Array[Vector2i] = []
	for fruit in _fruits:
		if is_instance_valid(fruit["node"]):
			occupied.append(grid_manager.world_to_grid(fruit["node"].global_position))

	var candidates: Array[Vector2i] = []
	for x in range(2, grid_manager.width - 2):
		for y in range(2, grid_manager.height - 2):
			var pos := Vector2i(x, y)
			if grid_manager.is_walkable(pos) and pos != center and pos not in occupied:
				candidates.append(pos)

	if candidates.is_empty():
		return Vector2i(-1, -1)
	return candidates[randi() % candidates.size()]
