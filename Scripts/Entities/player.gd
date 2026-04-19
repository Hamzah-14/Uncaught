class_name PlayerController
extends CharacterBody3D

signal stamina_changed(current_stamina: float, max_stamina: float)

@export var grid_manager_path: NodePath
@export var game_manager: GameManager
@export_category("Movement")
@export var walk_speed: float = 5.0
@export var acceleration: float = 10.0

@export_category("Stamina")
@export var max_stamina: float = 100.0
@export var exhaustion_threshold: float = 20.0

var _current_stamina: float = 50.0
var _is_exhausted: bool = false
var _is_shielded: bool = false
var _grid_manager: GridManager
var _speed_multiplier: float = 1.0
var _drain_timer: float = 0.0
var _regen_timer: float = 0.0
const _DRAIN_TICK: float = 0.5
const _REGEN_TICK: float = 0.75
var _on_hazard: bool = false
var _on_hazard_trap: bool = false
var _hazard_recover_timer: float = 0.0
const _HAZARD_RECOVER_TIME: float = 0.8
var _is_being_pulled: bool = false
var _pull_velocity: Vector3 = Vector3.ZERO
var hotbar: Hotbar
var _is_dashing: bool = false
var _dash_anim_timer: float = 0.0
var _tree_slow_mult: float = 1.0
var _tree_adjacent_timer: float = 0.0
var _tree_slow_ramp_timer: float = 0.0
var _tree_cycle_timer: float = 0.0
var _tree_cycle_duration: float = 17.5
var _tree_slow_active: bool = false
var _tree_slow_print_timer: float = 0.0
var _spawn_position: Vector3
# Null-safe — only present when scene adds AnimatedSprite3D as child override
var _sprite: AnimatedSprite3D
@onready var _anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var _ranger: Node3D = get_node_or_null("Ranger")

func _ready() -> void:
	_spawn_position = global_position
	_grid_manager = get_node(grid_manager_path)
	_current_stamina = 50.0
	hotbar = Hotbar.new()
	add_child(hotbar)
	_sprite = get_node_or_null("AnimatedSprite3D")
	_tree_cycle_duration = randf_range(15.0, 20.0)

func _physics_process(delta: float) -> void:
	# Pull override — ignore all input, force velocity toward guardian
	if _is_being_pulled:
		velocity.x = _pull_velocity.x
		velocity.z = _pull_velocity.z
		if is_on_floor():
			velocity.y = -1.0
		else:
			velocity.y -= 9.8 * delta
		move_and_slide()
		return

	if _dash_anim_timer > 0.0:
		_dash_anim_timer -= delta

	# 1. Input
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction = Vector3(input_dir.x, 0, input_dir.y).normalized()

	# 2. Use selected hotbar slot
	if Input.is_action_just_pressed("use_powerup"):
		_use_selected_powerup()

	# 3. Sprint & Stamina
	var is_trying_to_sprint = Input.is_action_pressed("sprint")
	var is_sprinting := is_trying_to_sprint and not _is_exhausted and direction != Vector3.ZERO

	if is_sprinting:
		_drain_timer -= delta
		if _drain_timer <= 0.0:
			_drain_timer = _DRAIN_TICK
			_current_stamina = maxf(_current_stamina - 15.0, 0.0)
			emit_signal("stamina_changed", _current_stamina, max_stamina)
			if _current_stamina <= 0.0:
				_is_exhausted = true
	else:
		_regen_timer -= delta
		if _regen_timer <= 0.0:
			_regen_timer = _REGEN_TICK
			_current_stamina = minf(_current_stamina + 5.0, max_stamina)
			emit_signal("stamina_changed", _current_stamina, max_stamina)
			if _is_exhausted and _current_stamina >= exhaustion_threshold:
				_is_exhausted = false

	var current_speed := walk_speed * 1.26 if is_sprinting else walk_speed

	# 4. Apply multipliers
	var terrain_mult: float = 1.0
	if _grid_manager:
		terrain_mult = _grid_manager.get_speed_multiplier(
			_grid_manager.world_to_grid(global_position)
		)
	current_speed *= _slow_multiplier * _tree_slow_mult * _speed_multiplier * terrain_mult

	# 5. Apply Velocity
	if direction:
		velocity.x = move_toward(velocity.x, direction.x * current_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * current_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0, acceleration * delta)

	# Hazard tile tracking
	if _grid_manager:
		var tile_pos := _grid_manager.world_to_grid(global_position)
		var cell := _grid_manager.get_cell(tile_pos)
		if cell == GridManager.CellType.HAZARD_TRAP:
			if not _on_hazard:
				_on_hazard = true
				_hazard_recover_timer = 0.0
				apply_slow(0.35, 999)
			if not _on_hazard_trap:
				_on_hazard_trap = true
				_drain_stamina_instant(40.0)
				print("Hazard trap triggered")
		else:
			if _on_hazard:
				_on_hazard = false
				_hazard_recover_timer = _HAZARD_RECOVER_TIME
			_on_hazard_trap = false

	# Lerp slow multiplier back after leaving hazard
	if _hazard_recover_timer > 0.0:
		_hazard_recover_timer -= delta
		var t := 1.0 - (_hazard_recover_timer / _HAZARD_RECOVER_TIME)
		_slow_multiplier = lerpf(0.65, 1.0, t)
		if _hazard_recover_timer <= 0.0:
			_slow_multiplier = 1.0

	# Tree proximity slow debuff — ramps up when player holds ember and stays near BLOCKED tiles
	if game_manager != null and game_manager._current_holder == GameManager.Holder.PLAYER:
		_tree_cycle_timer += delta
		if _tree_cycle_timer >= _tree_cycle_duration:
			_tree_cycle_timer = 0.0
			_tree_cycle_duration = randf_range(15.0, 20.0)
			_tree_adjacent_timer = 0.0
			_tree_slow_ramp_timer = 0.0
			_tree_slow_print_timer = 0.0
			_tree_slow_active = false
			_tree_slow_mult = 1.0
			print("TREE SLOW CYCLE RESET: new cycle in %.1f seconds" % _tree_cycle_duration)
		if _is_adjacent_to_blocked():
			_tree_adjacent_timer += delta
			if _tree_adjacent_timer >= 3.0:
				if not _tree_slow_active:
					print("TREE SLOW: player held ember near obstacle for 3s, ramping slow 20-60%")
				_tree_slow_active = true
				_tree_slow_ramp_timer = minf(_tree_slow_ramp_timer + delta, 2.0)
				var t := _tree_slow_ramp_timer / 2.0
				_tree_slow_mult = 1.0 - lerpf(0.2, 0.6, t)
				_tree_slow_print_timer -= delta
				if _tree_slow_print_timer <= 0.0:
					_tree_slow_print_timer = 0.5
					print("Tree slow: %.0f%%" % ((1.0 - _tree_slow_mult) * 100))
		else:
			_tree_adjacent_timer = 0.0
			if not _tree_slow_active:
				_tree_slow_mult = 1.0
	else:
		_tree_slow_mult = 1.0
		_tree_adjacent_timer = 0.0
		_tree_slow_ramp_timer = 0.0
		_tree_slow_active = false

	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= 9.8 * delta
	velocity.y = move_toward(velocity.y, -9.8, 9.8 * delta)
	move_and_slide()

	# Drive 2D sprite if present
	if _sprite and not _is_dashing:
		var is_moving := Vector2(velocity.x, velocity.z).length() > 0.1
		_sprite.play("walk" if is_moving else "idle")
		if velocity.x < -0.1:
			_sprite.flip_h = true
		elif velocity.x > 0.1:
			_sprite.flip_h = false

	_update_animation(direction, is_sprinting or _speed_multiplier > 1.05)
	_try_tag_guardian()

func _drain_stamina_instant(amount: float) -> void:
	_current_stamina = maxf(_current_stamina - amount, 0.0)
	emit_signal("stamina_changed", _current_stamina, max_stamina)

func restore_stamina(amount: float) -> void:
	_current_stamina = minf(_current_stamina + amount, max_stamina)
	emit_signal("stamina_changed", _current_stamina, max_stamina)
	if _is_exhausted and _current_stamina >= exhaustion_threshold:
		_is_exhausted = false

func collect_powerup(type: String) -> void:
	var added := hotbar.try_add(type)
	if added:
		print("Player collected: ", type, " → hotbar slot ", hotbar._selected_index)
	else:
		print("Player collect skipped: ", type, " (duplicate or hotbar full)")

# In _try_tag_guardian()
func _try_tag_guardian() -> void:
	var ember = get_tree().get_first_node_in_group("ember")
	if ember == null:
		return
	if ember._holder == null or not ember._holder.is_in_group("guardian"):
		return
	if ember.is_immune(get_tree().get_first_node_in_group("guardian")):
		return
	var guardian = get_tree().get_first_node_in_group("guardian")
	if guardian == null:
		return
	if global_position.distance_to(guardian.global_position) <= 1.8:
		ember.transfer(self, GameManager.Holder.PLAYER)

var _slow_multiplier: float = 1.0

func apply_slow(amount: float, duration: float) -> void:
	_slow_multiplier = 1.0 - amount
	await get_tree().create_timer(duration).timeout
	_slow_multiplier = 1.0

func apply_speed_boost(multiplier: float, duration: float) -> void:
	_speed_multiplier = multiplier
	await get_tree().create_timer(duration).timeout
	_speed_multiplier = 1.0

func freeze(duration: float) -> void:
	set_physics_process(false)
	velocity = Vector3.ZERO
	await get_tree().create_timer(duration).timeout
	set_physics_process(true)

func apply_shield(duration: float) -> void:
	_is_shielded = true
	await get_tree().create_timer(duration).timeout
	_is_shielded = false

func apply_pull(source_pos: Vector3) -> void:
	var dir := (source_pos - global_position)
	dir.y = 0.0
	dir = dir.normalized()
	_pull_velocity = dir * 12.0
	_is_being_pulled = true
	print("Player pulled toward Guardian")
	await get_tree().create_timer(0.6).timeout
	_is_being_pulled = false
	_pull_velocity = Vector3.ZERO

func _update_animation(direction: Vector3, is_running: bool) -> void:
	if _anim_player == null:
		return
	var moving := Vector2(velocity.x, velocity.z).length() > 0.1
	var target_anim: String
	if _dash_anim_timer > 0.0:
		target_anim = "Rig_Medium_General/Use_Item"
	elif is_running and moving:
		target_anim = "Running_A"
	elif moving:
		target_anim = "Walking_A"
	else:
		target_anim = "Rig_Medium_General/Idle_A"
	if _anim_player.current_animation != target_anim:
		_anim_player.play(target_anim)
	if _ranger != null and direction != Vector3.ZERO:
		var target_angle := atan2(direction.x, direction.z)
		_ranger.rotation.y = lerp_angle(_ranger.rotation.y, target_angle, 0.15)

func reset_to_spawn() -> void:
	global_position = _spawn_position
	velocity = Vector3.ZERO

func apply_phase_dash() -> void:
	var dir := Vector3(velocity.x, 0.0, velocity.z).normalized()
	if dir == Vector3.ZERO:
		return
	var dist: float = _grid_manager.cell_size * 2.0 if _grid_manager else 2.0
	global_position += dir * dist
	_is_dashing = true
	_dash_anim_timer = 0.5
	if _sprite:
		_sprite.play("dash")
	await get_tree().create_timer(0.5).timeout
	_is_dashing = false

func _use_selected_powerup() -> void:
	var type := hotbar.use_selected()
	if type == "":
		return
	match type:
		"freeze":
			var guardian = get_tree().get_first_node_in_group("guardian")
			if guardian:
				guardian.freeze(2.5)
				print("Player used: Freeze — Guardian frozen for 2.5s")
		"speed_boost":
			apply_speed_boost(1.3, 4.0)
			print("Player used: Speed Boost — 1.3x for 4s")
		"slow_field":
			var guardian = get_tree().get_first_node_in_group("guardian")
			if guardian:
				guardian.apply_slow(0.3, 3.0)
				print("Player used: Slow Trap — Guardian slowed 30% for 3s")
		"shield":
			apply_shield(4.0)
			print("Player used: Shield — immune to tagging for 4s")
		"phase_dash":
			apply_phase_dash()
			print("Player used: Phase Dash")

func _is_adjacent_to_blocked() -> bool:
	if _grid_manager == null:
		return false
	var pos := _grid_manager.world_to_grid(global_position)
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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			hotbar.select_prev()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			hotbar.select_next()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: hotbar.select_slot(0)
			KEY_2: hotbar.select_slot(1)
			KEY_3: hotbar.select_slot(2)
			KEY_4: hotbar.select_slot(3)
