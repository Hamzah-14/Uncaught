class_name GuardianController
extends CharacterBody3D

@export var walk_speed: float = 4.2
@export var sprint_speed: float = 7.35
var _base_walk_speed: float = 4.2
var _base_sprint_speed: float = 7.35
@export var acceleration: float = 11.5
@export var path_update_interval: float = 0.3
@export var tag_distance: float = 1.8
@export var grid_manager_path: NodePath
@export var game_manager_path: NodePath
@export var neutral_wait_time: float = 3.0
@export var guardian_pickup_delay: float = 0.5  # guardian can grab almost immediately
@export var fruit_manager: FruitManager
@export var powerup_manager: PowerupManager
var _speed_multiplier: float = 1.0
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
var _flee_stuck_timer: float = 0.0
var _last_flee_pos: Vector2i = Vector2i.ZERO
var _field_update_interval: float = 0.4
var _last_player_grid_pos: Vector2i = Vector2i.ZERO
var _player_direction: Vector2i = Vector2i.ZERO
var _prev_player_direction: Vector2i = Vector2i.ZERO
# Phase Dash cooldown and distance-delta tracking
var _phase_dash_cooldown: float = 0.0
var _prev_sampled_distance: float = 0.0
var _distance_sample_timer: float = 0.0
var _player_closing_fast: bool = false
# Proactive powerup seeking
var _powerup_seek_timer: float = 0.0
const _POWERUP_SEEK_INTERVAL: float = 1.0
var _seeking_powerup_pos: Vector2i = Vector2i(-1, -1)
var _spawn_position: Vector3
var _sprite: AnimatedSprite3D
var _player_camp_timer: float = 0.0
var _player_camp_pos: Vector2i = Vector2i(-1, -1)
var _is_flanking: bool = false
const _CAMP_THRESHOLD: float = 2.5
var _use_item_anim_timer: float = 0.0
var _spawn_anim_timer: float = 1.0  # flag only — zeroed by animation_finished signal
var _spawn_anim: String = "Rig_Medium_General/Spawn_Ground"
var _tree_boost_mult: float = 1.0
var _on_collapse_tile: bool = false
var _collapse_burst_active: bool = false
var _collapse_burst_timer: float = 0.0
var _collapse_burst_mult: float = 1.2
var _collapse_cooldown_timer: float = 0.0
var _seeking_collapse_tile: Vector2i = Vector2i(-1, -1)
var _current_round: int = 1
@onready var _anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var _barbarian: Node3D = get_node_or_null("Barbarian")

func _ready() -> void:
	_base_walk_speed = walk_speed
	_base_sprint_speed = sprint_speed
	# Get references FIRST before anything uses them
	_grid_manager = get_node(grid_manager_path)
	_game_manager = get_node(game_manager_path)
	_spawn_position = global_position
	_sprite = get_node_or_null("AnimatedSprite3D")
	
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

	if _anim_player:
		_anim_player.animation_finished.connect(_on_animation_finished)

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

	# Phase Dash cooldown tick
	if _phase_dash_cooldown > 0.0:
		_phase_dash_cooldown -= delta

	# Collapse burst + cooldown ticks
	if _collapse_cooldown_timer > 0.0:
		_collapse_cooldown_timer -= delta
	if _collapse_burst_active:
		_collapse_burst_timer -= delta
		if _collapse_burst_timer <= 0.0:
			_collapse_burst_active = false

	# Powerup seeking tick
	_powerup_seek_timer += delta
	if _powerup_seek_timer >= _POWERUP_SEEK_INTERVAL:
		_powerup_seek_timer = 0.0
		_evaluate_powerup_seeking()

	var my_grid_pos: Vector2i = _grid_manager.world_to_grid(global_position)
	var player_grid_pos: Vector2i = _grid_manager.world_to_grid(_player.global_position)

	# Track player movement direction
	_prev_player_direction = _player_direction
	_player_direction = player_grid_pos - _last_player_grid_pos
	_last_player_grid_pos = player_grid_pos

	var distance_to_player := _hex_distance(my_grid_pos, player_grid_pos)

	# Force immediate repath when player jukes sharply while close
	var dir_a := Vector2(float(_player_direction.x), float(_player_direction.y))
	var dir_b := Vector2(float(_prev_player_direction.x), float(_prev_player_direction.y))
	if dir_a.length() > 0.01 and dir_b.length() > 0.01 \
			and dir_a.normalized().dot(dir_b.normalized()) < -0.2 \
			and distance_to_player <= 4.0:
		_path_update_timer = 0.0

	# Collapse tile step-on — trigger burst when Guardian walks onto one
	if _grid_manager.get_cell(my_grid_pos) == GridManager.CellType.HAZARD_COLLAPSE:
		if not _on_collapse_tile and not _collapse_burst_active and _collapse_cooldown_timer <= 0.0:
			_on_collapse_tile = true
			_collapse_burst_active = true
			_collapse_burst_timer = 2.0
			_collapse_cooldown_timer = 12.0
			_seeking_collapse_tile = Vector2i(-1, -1)
			print("Guardian stepped on collapse tile — burst %.2fx for 2s" % _collapse_burst_mult)
	else:
		_on_collapse_tile = false

	# Sample distance every 0.5s to detect if player is closing in fast
	_distance_sample_timer += delta
	if _distance_sample_timer >= 0.5:
		_player_closing_fast = (_prev_sampled_distance - distance_to_player) > 1.0
		_prev_sampled_distance = distance_to_player
		_distance_sample_timer = 0.0

	var player_holds_ember := _game_manager._current_holder == GameManager.Holder.PLAYER
	var guardian_holds_ember := _game_manager._current_holder == GameManager.Holder.GUARDIAN
	var player_visible: bool = true

	# Player camping detection — triggers flanking when player holds ember and camps near BLOCKED
	if player_holds_ember:
		var was_flanking := _is_flanking
		if _is_player_near_blocked(player_grid_pos):
			if _player_camp_pos == player_grid_pos:
				_player_camp_timer += delta
			else:
				_player_camp_pos = player_grid_pos
				_player_camp_timer = 0.0
			_is_flanking = _player_camp_timer >= _CAMP_THRESHOLD
			if _is_flanking and not was_flanking:
				print("GUARDIAN FLANKING: player camping near obstacle, routing around")
		else:
			_player_camp_timer = 0.0
			_is_flanking = false
	else:
		_player_camp_timer = 0.0
		_is_flanking = false
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
		_path_update_timer = _get_dynamic_path_interval(distance_to_player)

		var goal: Vector2i = player_grid_pos  # safe fallback
		match _game_manager._current_holder:
			GameManager.Holder.NONE:
				# Nobody has Ember → go to Ember
				if _ember != null:
					goal = _grid_manager.world_to_grid(_ember.global_position)

			GameManager.Holder.PLAYER:
				# Player has Ember → chase or flank if camping near obstacle
				if _is_flanking:
					goal = _get_flank_goal(my_grid_pos, player_grid_pos)
				else:
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
		# Clear stale collapse target if tile is no longer a collapse tile
		if _seeking_collapse_tile != Vector2i(-1, -1) \
				and _grid_manager.get_cell(_seeking_collapse_tile) != GridManager.CellType.HAZARD_COLLAPSE:
			_seeking_collapse_tile = Vector2i(-1, -1)

		# Proactive seeking override — redirect toward a valued powerup if one was chosen
		if _seeking_powerup_pos != Vector2i(-1, -1):
			if powerup_manager and powerup_manager.has_powerup_at(_seeking_powerup_pos):
				goal = _seeking_powerup_pos
			else:
				_seeking_powerup_pos = Vector2i(-1, -1)
		# Collapse tile override — lower priority, single-cycle only
		elif _seeking_collapse_tile != Vector2i(-1, -1):
			if not _collapse_burst_active and _collapse_cooldown_timer <= 0.0:
				goal = _seeking_collapse_tile
				print("Guardian detour to collapse tile — burst incoming")
			_seeking_collapse_tile = Vector2i(-1, -1)
		else:
			_evaluate_collapse_seeking(my_grid_pos, goal, player_grid_pos, distance_to_player)
		_current_path = _astar.find_path(my_grid_pos, goal)
	_tree_boost_mult = 1.25 if _is_adjacent_to_blocked_g(my_grid_pos) else 1.0
	_follow_path(delta, my_grid_pos)

	# Stuck detection — only active while fleeing
	if _state_machine.current_mode == GuardianStateMachine.Mode.FLEE:
		if my_grid_pos == _last_flee_pos:
			_flee_stuck_timer += delta
		else:
			_flee_stuck_timer = 0.0
			_last_flee_pos = my_grid_pos
		if _flee_stuck_timer >= 1.5:
			_flee_stuck_timer = 0.0
			_path_update_timer = 0.0
			_danger_field.clear()
	else:
		_flee_stuck_timer = 0.0
		_last_flee_pos = my_grid_pos

	# Gravity
	if is_on_floor():
		velocity.y = -1.0  # keeps player grounded on uneven terrain
	else:
		velocity.y -= 9.8 * delta
	move_and_slide()

	# Drive 2D sprite if present
	if _sprite:
		var is_moving := Vector2(velocity.x, velocity.z).length() > 0.1
		_sprite.play("walk" if is_moving else "Idle")
		if velocity.x < -0.1:
			_sprite.flip_h = true
		elif velocity.x > 0.1:
			_sprite.flip_h = false

	if _use_item_anim_timer > 0.0:
		_use_item_anim_timer -= delta
	# spawn anim duration driven by animation_finished signal, not a timer
	_update_animation()
	_handle_tag()

func _get_dynamic_path_interval(distance_to_player: float) -> float:
	if _game_manager._current_holder == GameManager.Holder.PLAYER:
		if distance_to_player <= 3.0:
			return 0.16
		elif distance_to_player <= 6.0:
			return 0.22
	return path_update_interval

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
	speed *= _slow_multiplier * _speed_multiplier * _tree_boost_mult * terrain_mult
	if _collapse_burst_active:
		speed *= _collapse_burst_mult
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

func _update_animation() -> void:
	if _anim_player == null:
		return
	var moving := Vector2(velocity.x, velocity.z).length() > 0.1
	var target_anim: String
	if _spawn_anim_timer > 0.0:
		target_anim = _spawn_anim
	elif _use_item_anim_timer > 0.0:
		target_anim = "Rig_Medium_General/Use_Item"
	elif moving:
		var is_fast := _state_machine.current_mode == GuardianStateMachine.Mode.AGGRESSIVE \
				or _state_machine.current_mode == GuardianStateMachine.Mode.FLEE
		target_anim = "Running_B" if is_fast else "Walking_B"
	else:
		target_anim = "Rig_Medium_General/Idle_B"
	if _anim_player.current_animation != target_anim:
		_anim_player.play(target_anim)
	if _barbarian != null and (velocity.x != 0.0 or velocity.z != 0.0):
		var target_angle := atan2(velocity.x, velocity.z)
		_barbarian.rotation.y = lerp_angle(_barbarian.rotation.y, target_angle, 0.15)

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name in ["Rig_Medium_General/Spawn_Air", "Rig_Medium_General/Spawn_Ground"]:
		_spawn_anim_timer = 0.0

func reset_to_spawn() -> void:
	global_position = _spawn_position
	velocity = Vector3.ZERO
	_spawn_anim_timer = 1.0  # flag only — actual end driven by animation_finished
	_spawn_anim = "Rig_Medium_General/Spawn_Air"

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
	var dist := _grid_manager.cell_size * 2.0 * 1.732 if _grid_manager else 4.0
	var new_pos := global_position + dir * dist
	if _grid_manager:
		var grid_pos := _grid_manager.world_to_grid(new_pos)
		grid_pos.x = clampi(grid_pos.x, 1, _grid_manager.width - 2)
		grid_pos.y = clampi(grid_pos.y, 1, _grid_manager.height - 2)
		new_pos = _grid_manager.grid_to_world(grid_pos, global_position.y)
	global_position = new_pos

func freeze(duration: float) -> void:
	set_physics_process(false)
	velocity = Vector3.ZERO
	await get_tree().create_timer(duration).timeout
	set_physics_process(true)

func configure_for_round(round_num: int, capacity: int) -> void:
	_current_round = round_num
	_hotbar_capacity = capacity
	_hotbar.set_capacity(capacity)
	var speed_mult := pow(1.1, round_num - 1)
	walk_speed = _base_walk_speed * speed_mult
	sprint_speed = _base_sprint_speed * speed_mult
	_collapse_burst_mult = 1.2 + (round_num - 1) * 0.15
	print("[Guardian] Round %d — speed x%.2f, hotbar capacity %d, collapse burst %.2fx" % [round_num, speed_mult, capacity, _collapse_burst_mult])

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

	# Rule 0: PULL near hazard — highest priority. If player is adjacent to a hazard trap,
	# pull them onto it immediately.
	if _hotbar.has_type("pull") and player_holds_ember and distance_to_player <= 4.0 \
			and _get_adjacent_hazard_trap(player_grid_pos):
		if _hotbar.use_slot("pull"):
			_player.apply_pull(global_position)
			_use_item_anim_timer = 0.8
			print("Guardian pulling player toward hazard trap")
		return

	# Rule 1: PHASE_DASH — strategic use only, with cooldown.
	# Chase: medium range (4-7 tiles) with a long path, close the gap efficiently.
	# Flee: player closing in fast AND already dangerously close (< 4 tiles).
	if _hotbar.has_type("phase_dash") and _phase_dash_cooldown <= 0.0:
		var dash_chase := is_chasing and distance_to_player >= 3.0 and \
				distance_to_player <= 8.0 and _current_path.size() > 4
		var dash_flee := is_fleeing and (_player_closing_fast or distance_to_player < 3.0)
		if dash_chase or dash_flee:
			if _hotbar.use_slot("phase_dash"):
				apply_phase_dash()
				_phase_dash_cooldown = 3.0
				_use_item_anim_timer = 0.8
				print("Guardian used: Phase Dash (", "chase" if dash_chase else "flee", ")")
	# Rule 2: FREEZE — player has ember and has put distance between themselves and us.
	elif _hotbar.has_type("freeze") and player_holds_ember and distance_to_player > 4.0:
		if _hotbar.use_slot("freeze"):
			_player.freeze(2.5)
			_use_item_anim_timer = 0.8
			print("Guardian used: Freeze — Player frozen for 2.5s")
	# Rule 3: SLOW_FIELD — player has ember and is actively running away.
	elif _hotbar.has_type("slow_field") and player_holds_ember and player_moving_away:
		if _hotbar.use_slot("slow_field"):
			_player.apply_slow(0.3, 3.0)
			_use_item_anim_timer = 0.8
			print("Guardian used: Slow Trap — Player slowed 30% for 3s")
	# Rule 4: SPEED_BOOST — guardian has ember and player is dangerously close.
	elif _hotbar.has_type("speed_boost") and guardian_holds_ember and distance_to_player < 5.0:
		if _hotbar.use_slot("speed_boost"):
			apply_speed_boost(1.5, 4.0)
			_use_item_anim_timer = 0.8
			print("Guardian used: Speed Boost — 1.5x speed for 4s")
	# Rule 5: FRUIT_WIPE — player has ember and has fruits to rely on (≥ 2 active).
	elif _hotbar.has_type("fruit_wipe") and player_holds_ember and \
			fruit_manager != null and fruit_manager._active_count >= 2:
		if _hotbar.use_slot("fruit_wipe"):
			fruit_manager.wipe_fruits()
			_use_item_anim_timer = 0.8
			print("Guardian used: Fruit Wipe — all fruits cleared")
	# Rule 6: PULL — player has ember and has opened a gap.
	elif _hotbar.has_type("pull") and player_holds_ember and distance_to_player > 5.0:
		if _hotbar.use_slot("pull"):
			_player.apply_pull(global_position)
			_use_item_anim_timer = 0.8
			print("Guardian used: Pull — player yanked toward guardian")

func _get_adjacent_hazard_trap(target_pos: Vector2i) -> bool:
	for neighbor in _grid_manager.get_walkable_neighbors(target_pos):
		if _grid_manager.get_cell(neighbor) == GridManager.CellType.HAZARD_TRAP:
			return true
	return false

func _is_adjacent_to_blocked_g(pos: Vector2i) -> bool:
	var is_odd := (pos.y & 1) == 1
	var offsets: Array[Vector2i]
	if is_odd:
		offsets = [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	else:
		offsets = [Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]
	for off in offsets:
		if _grid_manager.get_cell(pos + off) == GridManager.CellType.FLOOR_HIGH:
			return true
	return false

func _is_player_near_blocked(player_pos: Vector2i) -> bool:
	var is_odd := (player_pos.y & 1) == 1
	var offsets: Array[Vector2i]
	if is_odd:
		offsets = [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	else:
		offsets = [Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]
	for off in offsets:
		if _grid_manager.get_cell(player_pos + off) == GridManager.CellType.FLOOR_HIGH:
			return true
	return false

func _get_flank_goal(my_pos: Vector2i, player_pos: Vector2i) -> Vector2i:
	var walkable := _grid_manager.get_walkable_neighbors(player_pos)
	if walkable.is_empty():
		return player_pos
	var best: Vector2i = walkable[0]
	var best_dist: float = _hex_distance(my_pos, best)
	for n in walkable:
		var d := _hex_distance(my_pos, n)
		if d > best_dist:
			best_dist = d
			best = n
	return best

func _evaluate_collapse_seeking(my_grid_pos: Vector2i, main_goal: Vector2i, player_grid_pos: Vector2i, distance_to_player: float) -> void:
	if _collapse_burst_active or _collapse_cooldown_timer > 0.0:
		return
	if distance_to_player <= 3.0:
		return

	var is_fleeing := _game_manager._current_holder == GameManager.Holder.GUARDIAN \
			and _state_machine.current_mode == GuardianStateMachine.Mode.FLEE
	# Fleeing: tighter detour budget; chasing: allow 2 extra steps
	var max_overhead := 1.0 if is_fleeing else 2.0

	var to_goal := Vector2(float(main_goal.x - my_grid_pos.x), float(main_goal.y - my_grid_pos.y))
	var goal_len := to_goal.length()
	var goal_dir := to_goal / goal_len if goal_len > 0.01 else Vector2.ZERO
	var direct_dist := _hex_distance(my_grid_pos, main_goal)
	var dist_from_player := _hex_distance(my_grid_pos, player_grid_pos)

	var best_score: float = -1.0
	var best_tile: Vector2i = Vector2i(-1, -1)

	for dx in range(-3, 4):
		for dy in range(-3, 4):
			var candidate := my_grid_pos + Vector2i(dx, dy)
			if candidate.x < 0 or candidate.x >= _grid_manager.width \
					or candidate.y < 0 or candidate.y >= _grid_manager.height:
				continue
			if _grid_manager.get_cell(candidate) != GridManager.CellType.HAZARD_COLLAPSE:
				continue
			var dist_to_tile := _hex_distance(my_grid_pos, candidate)
			if dist_to_tile < 0.5 or dist_to_tile > 3.0:
				continue
			# Reject tiles behind guardian relative to the strategic goal direction
			var to_tile := Vector2(float(candidate.x - my_grid_pos.x), float(candidate.y - my_grid_pos.y))
			if goal_dir.length() > 0.01 and to_tile.dot(goal_dir) < 0.0:
				continue
			# Reject if detour cost exceeds mode-specific budget
			var detour_dist := dist_to_tile + _hex_distance(candidate, main_goal)
			var overhead := detour_dist - direct_dist
			if overhead > max_overhead:
				continue
			# Flee-mode safety checks
			if is_fleeing:
				# Must not move the guardian closer to the player
				if _hex_distance(candidate, player_grid_pos) < dist_from_player:
					continue
				# Must have enough escape routes (not a dead end or narrow corridor)
				if _grid_manager.get_walkable_neighbors(candidate).size() < 3:
					continue
				# Reject tiles near grid edges — already penalised in flee goal scoring
				if candidate.x <= 1 or candidate.x >= _grid_manager.width - 2 \
						or candidate.y <= 1 or candidate.y >= _grid_manager.height - 2:
					continue
			var score := 5.5 - dist_to_tile - overhead * 0.6
			if score > best_score:
				best_score = score
				best_tile = candidate

	if best_score > 2.5:
		_seeking_collapse_tile = best_tile

func _evaluate_powerup_seeking() -> void:
	if powerup_manager == null or _hotbar == null:
		return
	if _hotbar_capacity == 0:
		return

	var my_grid_pos := _grid_manager.world_to_grid(global_position)
	var guardian_holds_ember := _game_manager._current_holder == GameManager.Holder.GUARDIAN

	# Base scores per type — guardian-valid only (SHIELD excluded)
	var base_scores: Dictionary = {
		PowerupManager.PowerupType.FREEZE:      10.0,
		PowerupManager.PowerupType.PULL:        10.0,
		PowerupManager.PowerupType.SPEED_BOOST:  8.0,
		PowerupManager.PowerupType.PHASE_DASH:   7.0,
		PowerupManager.PowerupType.SLOW_FIELD:   6.0,
		PowerupManager.PowerupType.FRUIT_WIPE:   4.0,
	}

	var player_holds_ember := _game_manager._current_holder == GameManager.Holder.PLAYER

	# Opportunistic grab — any valid powerup within 2 tiles is always worth taking
	for pup in powerup_manager.get_active_powerups():
		var type: int = pup["type"]
		if not base_scores.has(type):
			continue
		if guardian_holds_ember and type != PowerupManager.PowerupType.SPEED_BOOST:
			continue
		if _hotbar.has_type(pup["type_str"]):
			continue
		if _hex_distance(my_grid_pos, pup["grid_pos"]) <= 2.0:
			_seeking_powerup_pos = pup["grid_pos"]
			return

	# Scored seek — short detour while chasing, longer when ember is free
	var max_dist: float = 3.0 if player_holds_ember else 5.0
	var best_score: float = -1.0
	var best_pos: Vector2i = Vector2i(-1, -1)

	for pup in powerup_manager.get_active_powerups():
		var type: int = pup["type"]
		if not base_scores.has(type):
			continue
		if guardian_holds_ember and type != PowerupManager.PowerupType.SPEED_BOOST:
			continue
		var type_str: String = pup["type_str"]
		if _hotbar.has_type(type_str):
			continue

		var dist: float = _hex_distance(my_grid_pos, pup["grid_pos"])
		if dist > max_dist:
			continue
		var score: float = base_scores[type] - 1.2 * dist

		if score > best_score:
			best_score = score
			best_pos = pup["grid_pos"]

	if best_score > 4.0:
		_seeking_powerup_pos = best_pos
	else:
		_seeking_powerup_pos = Vector2i(-1, -1)
