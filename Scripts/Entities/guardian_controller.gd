class_name GuardianController
extends CharacterBody3D

@export var walk_speed: float = 4.0
@export var sprint_speed: float = 7.0
@export var acceleration: float = 10.0
@export var path_update_interval: float = 0.3
@export var tag_distance: float = 1.8
@export var grid_manager_path: NodePath
@export var game_manager_path: NodePath
@export var neutral_wait_time: float = 3.0
@export var guardian_pickup_delay: float = 0.5  # guardian can grab almost immediately
@export var fruit_manager: FruitManager
var _speed_multiplier: float = 1.0
var _on_hazard: bool = false
var _hazard_recover_timer: float = 0.0
const _HAZARD_RECOVER_TIME: float = 0.8
var _hotbar_capacity: int = 0
var _hotbar: GuardianHotbar
var _powerup_eval_timer: float = 0.0
const _POWERUP_EVAL_INTERVAL: float = 2.0
var _grid_manager: GridManager
var _game_manager: GameManager
var _astar: DynamicAStar
var _state_machine: GuardianStateMachine
var _ember: EmberObject
var _potential_field: PotentialField
var _player: PlayerController
var _danger_field: Dictionary = {}
var _current_path: Array[Vector2i] = []
var _path_update_timer: float = 0.0
var _field_update_timer: float = 0.0
var _field_update_interval: float = 0.4  # Rebuild field every 0.4s
var _last_player_grid_pos: Vector2i = Vector2i.ZERO
var _player_direction: Vector2i = Vector2i.ZERO

func _ready() -> void:
	# Get references FIRST before anything uses them
	_grid_manager = get_node(grid_manager_path)
	_game_manager = get_node(game_manager_path)
	
	_player = get_tree().get_first_node_in_group("player") as PlayerController

	_potential_field = PotentialField.new()
	_potential_field.setup(_grid_manager)

	_astar = DynamicAStar.new()
	_astar.setup(_grid_manager)
	
	
	_state_machine = GuardianStateMachine.new()
	add_child(_state_machine)
	_state_machine.grid_size = Vector2i(_grid_manager.width, _grid_manager.height)
	_state_machine.grid_manager = _grid_manager

	_hotbar = GuardianHotbar.new()
	add_child(_hotbar)
	# Capacity 0 by default — set via set_hotbar_capacity() when rounds advance.

	print("Grid manager in guardian: ", _grid_manager)
	print("Potential field grid manager: ", _potential_field._grid_manager)
func _physics_process(delta: float) -> void:
	#print("Ember ref:", _ember, "Holder:", _game_manager._current_holder)
	if _ember == null:
		_ember = get_tree().get_first_node_in_group("ember") as EmberObject
	if _player == null or _ember == null:
		return

	# Powerup evaluation — runs every 2 seconds
	_powerup_eval_timer -= delta
	if _powerup_eval_timer <= 0.0:
		_powerup_eval_timer = _POWERUP_EVAL_INTERVAL
		evaluate_powerup_use()

	var my_grid_pos: Vector2i = _grid_manager.world_to_grid(global_position)
	var player_grid_pos: Vector2i = _grid_manager.world_to_grid(_player.global_position)

	# Track player movement direction
	_player_direction = player_grid_pos - _last_player_grid_pos
	_last_player_grid_pos = player_grid_pos

	var distance_to_player := _hex_distance(my_grid_pos, player_grid_pos)
	var player_holds_ember := _game_manager._current_holder == GameManager.Holder.PLAYER
	var guardian_holds_ember := _game_manager._current_holder == GameManager.Holder.GUARDIAN
	var player_visible: bool = true
	var score_deficit := _game_manager._player_score - _game_manager._guardian_score
	
	_state_machine.update_sensors(
		player_visible,
		player_holds_ember,
		guardian_holds_ember,
		distance_to_player,
		player_grid_pos,
		_player_direction,
		_game_manager._time_remaining,
		score_deficit
	)
	# Rebuild danger field periodically when Guardian holds Ember
	if _game_manager._current_holder == GameManager.Holder.GUARDIAN:
		_field_update_timer -= delta
		if _field_update_timer <= 0.0:
			_field_update_timer = _field_update_interval
			_danger_field = _potential_field.build_field(player_grid_pos)
	
	# Update path periodically
	_path_update_timer -= delta
	if _path_update_timer <= 0.0:
		_path_update_timer = path_update_interval

		var goal: Vector2i = player_grid_pos  # safe fallback
		match _game_manager._current_holder:
			GameManager.Holder.NONE:
				# Nobody has Ember → go to Ember
				if _ember != null:
					goal = _grid_manager.world_to_grid(_ember.global_position)

			GameManager.Holder.PLAYER:
				# Player has Ember → chase player
				goal = _state_machine.get_goal()

			GameManager.Holder.GUARDIAN:
				# Use potential field to flee from player
				if not _danger_field.is_empty():
					var flee = _potential_field.get_flee_goal(my_grid_pos, _danger_field)
					_state_machine.flee_goal = flee  # ← add this line
					goal = flee
				else:
					goal = my_grid_pos  # stand still until field builds
			
			# Debug here
		#print("Holder: ", _game_manager._current_holder)
		#print("Goal: ", goal)
		#print("My pos: ", my_grid_pos)
		#print("Path size: ", _current_path.size())
		#print("Danger field size: ", _danger_field.size())
		_current_path = _astar.find_path(my_grid_pos, goal)
	_follow_path(delta, my_grid_pos)

	# Hazard tile tracking
	var cell := _grid_manager.get_cell(my_grid_pos)
	if cell == GridManager.CellType.HAZARD_TRAP:
		if not _on_hazard:
			_on_hazard = true
			_hazard_recover_timer = 0.0
			apply_slow(0.35, 999)
	else:
		if _on_hazard:
			_on_hazard = false
			_hazard_recover_timer = _HAZARD_RECOVER_TIME

	# Lerp slow multiplier back after leaving hazard
	if _hazard_recover_timer > 0.0:
		_hazard_recover_timer -= delta
		var t := 1.0 - (_hazard_recover_timer / _HAZARD_RECOVER_TIME)
		_slow_multiplier = lerpf(0.65, 1.0, t)
		if _hazard_recover_timer <= 0.0:
			_slow_multiplier = 1.0

	# Gravity
	if is_on_floor():
		velocity.y = -1.0  # keeps player grounded on uneven terrain
	else:
		velocity.y -= 9.8 * delta
	
	# Smooth step-up over height differences
	#velocity.y = move_toward(velocity.y, -9.8, 9.8 * delta)
	move_and_slide()
	_handle_tag()

# Follow computed A* path
func _follow_path(delta: float, my_grid_pos: Vector2i) -> void:
	if _current_path.is_empty():
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		return

	var next_grid: Vector2i = _current_path[0]
	var next_world: Vector3 = _grid_manager.grid_to_world(next_grid, global_position.y)
	var to_target: Vector3 = next_world - global_position
	to_target.y = 0.0

	if to_target.length() < 0.2:
		_current_path.pop_front()
		return

	var direction := to_target.normalized()
	var speed := sprint_speed if _state_machine.current_mode == GuardianStateMachine.Mode.AGGRESSIVE else walk_speed
	var terrain_mult = _grid_manager.get_speed_multiplier(my_grid_pos)
	speed *= _slow_multiplier * _speed_multiplier * terrain_mult
	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	
# Hex distance helper
func _hex_distance(a: Vector2i, b: Vector2i) -> float:
	var aa := _offset_to_axial(a)
	var bb := _offset_to_axial(b)

	var dq: int = bb.x - aa.x
	var dr: int = bb.y - aa.y

	return float((abs(dq) + abs(dq + dr) + abs(dr)) / 2)

func _offset_to_axial(pos: Vector2i) -> Vector2i:
	var q: int = pos.x - (pos.y - (pos.y & 1)) / 2
	var r: int = pos.y
	return Vector2i(q, r)

func _handle_tag() -> void:
	if _ember == null:
		return
	if _game_manager._current_holder != GameManager.Holder.PLAYER:
		return
	if _ember.is_immune(_player):  # ← check if PLAYER is immune, not self
		return
	if global_position.distance_to(_player.global_position) <= tag_distance:
		_ember.transfer(self, GameManager.Holder.GUARDIAN)
var _slow_multiplier: float = 1.0

func apply_slow(amount: float, duration: float) -> void:
	_slow_multiplier = 1.0 - amount
	await get_tree().create_timer(duration).timeout
	_slow_multiplier = 1.0

func apply_speed_boost(multiplier: float, duration: float) -> void:
	_speed_multiplier = multiplier
	await get_tree().create_timer(duration).timeout
	_speed_multiplier = 1.0

func apply_phase_dash() -> void:
	var dir := Vector3(velocity.x, 0.0, velocity.z).normalized()
	if dir == Vector3.ZERO:
		return
	global_position += dir * _grid_manager.cell_size * 2.0

func freeze(duration: float) -> void:
	set_physics_process(false)
	velocity = Vector3.ZERO
	await get_tree().create_timer(duration).timeout
	set_physics_process(true)

func set_hotbar_capacity(n: int) -> void:
	_hotbar_capacity = n
	_hotbar.set_capacity(n)
	print("Guardian hotbar capacity set to ", n)

func collect_powerup(type: String) -> void:
	var added := _hotbar.try_add(type)
	if added:
		print("Guardian collected: ", type, " → hotbar")
	else:
		print("Guardian collect skipped: ", type, " (duplicate or hotbar full/at capacity 0)")

func evaluate_powerup_use() -> void:
	if _hotbar == null or _player == null or _game_manager == null:
		return

	var my_grid_pos := _grid_manager.world_to_grid(global_position)
	var player_grid_pos := _grid_manager.world_to_grid(_player.global_position)
	var distance_to_player := _hex_distance(my_grid_pos, player_grid_pos)
	var player_holds_ember := _game_manager._current_holder == GameManager.Holder.PLAYER
	var guardian_holds_ember := _game_manager._current_holder == GameManager.Holder.GUARDIAN

	# Dot product of player's last movement against the guardian→player vector.
	# Positive means the player is moving further away from the guardian.
	var to_player := Vector2(float(player_grid_pos.x - my_grid_pos.x),
							 float(player_grid_pos.y - my_grid_pos.y))
	var player_dir := Vector2(float(_player_direction.x), float(_player_direction.y))
	var player_moving_away := player_dir.dot(to_player) > 0.0

	var is_chasing := _state_machine.current_mode == GuardianStateMachine.Mode.CHASE \
					or _state_machine.current_mode == GuardianStateMachine.Mode.AGGRESSIVE
	var is_fleeing := _state_machine.current_mode == GuardianStateMachine.Mode.FLEE

	# Rule 1: PHASE_DASH — close the gap while chasing (3–6 tiles) or escape when
	# fleeing and player is right behind (< 3 tiles).
	if _hotbar.has_type("phase_dash") and \
			((is_chasing and distance_to_player >= 3.0 and distance_to_player <= 6.0) or \
			 (is_fleeing and distance_to_player < 3.0)):
		if _hotbar.use_slot("phase_dash"):
			apply_phase_dash()
			print("Guardian used: Phase Dash")
	# Rule 2: FREEZE — player has ember and has put distance between themselves and us.
	elif _hotbar.has_type("freeze") and player_holds_ember and distance_to_player > 4.0:
		if _hotbar.use_slot("freeze"):
			_player.freeze(2.5)
			print("Guardian used: Freeze — Player frozen for 2.5s")
	# Rule 3: SLOW_FIELD — player has ember and is actively running away.
	elif _hotbar.has_type("slow_field") and player_holds_ember and player_moving_away:
		if _hotbar.use_slot("slow_field"):
			_player.apply_slow(0.3, 3.0)
			print("Guardian used: Slow Trap — Player slowed 30% for 3s")
	# Rule 4: SPEED_BOOST — guardian has ember and player is dangerously close.
	elif _hotbar.has_type("speed_boost") and guardian_holds_ember and distance_to_player < 5.0:
		if _hotbar.use_slot("speed_boost"):
			apply_speed_boost(1.5, 4.0)
			print("Guardian used: Speed Boost — 1.5x speed for 4s")
	# Rule 5: FRUIT_WIPE — player has ember and has fruits to rely on (≥ 2 active).
	elif _hotbar.has_type("fruit_wipe") and player_holds_ember and \
			fruit_manager != null and fruit_manager._active_count >= 2:
		if _hotbar.use_slot("fruit_wipe"):
			fruit_manager.wipe_fruits()
			print("Guardian used: Fruit Wipe — all fruits cleared")
	# Rule 6: PULL — player has ember and has opened a gap.
	elif _hotbar.has_type("pull") and player_holds_ember and distance_to_player > 5.0:
		if _hotbar.use_slot("pull"):
			_player.apply_pull(global_position)
			print("Guardian used: Pull — player yanked toward guardian")
