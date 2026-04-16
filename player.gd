class_name PlayerController
extends CharacterBody3D

signal stamina_changed(current_stamina: float, max_stamina: float)

@export var grid_manager_path: NodePath
@export_category("Movement")
@export var walk_speed: float = 5.0
@export var acceleration: float = 10.0

@export_category("Stamina")
@export var max_stamina: float = 100.0
@export var exhaustion_threshold: float = 20.0
var _is_dashing: bool = false
var _spawn_position: Vector3

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
var _hazard_recover_timer: float = 0.0
const _HAZARD_RECOVER_TIME: float = 0.8
var _is_being_pulled: bool = false
var _pull_velocity: Vector3 = Vector3.ZERO
var hotbar: Hotbar
@onready var sprite = $AnimatedSprite3D

func _ready() -> void:
	_spawn_position = global_position
	_grid_manager = get_node(grid_manager_path)
	_current_stamina = 50.0
	hotbar = Hotbar.new()
	add_child(hotbar)

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
			_current_stamina = maxf(_current_stamina - 12.5, 0.0)
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

	var current_speed := walk_speed * 1.3 if is_sprinting else walk_speed

	# 4. Apply multipliers
	var terrain_mult: float = 1.0
	if _grid_manager:
		terrain_mult = _grid_manager.get_speed_multiplier(
			_grid_manager.world_to_grid(global_position)
		)
	current_speed *= _slow_multiplier * _speed_multiplier * terrain_mult

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

	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= 9.8 * delta
	velocity.y = move_toward(velocity.y, -9.8, 9.8 * delta)
	move_and_slide()
	_try_tag_guardian()
	if not _is_dashing:
		var is_moving = Vector2(velocity.x, velocity.z).length() > 0.1
		if is_moving:
			sprite.play("walk")
		else:
			sprite.play("idle")
		if velocity.x < -0.1:
			sprite.flip_h = true
		elif velocity.x > 0.1:
			sprite.flip_h = false
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

func apply_phase_dash() -> void:
	var dir := Vector3(velocity.x, 0.0, velocity.z).normalized()
	if dir == Vector3.ZERO:
		return
	var dist: float = _grid_manager.cell_size * 2.0 if _grid_manager else 2.0
	global_position += dir * dist
	_is_dashing = true
	sprite.play("dash")
	await get_tree().create_timer(0.5).timeout
	_is_dashing = false
	sprite.play("idle")

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
func reset_to_spawn() -> void:
	global_position = _spawn_position
	velocity = Vector3.ZERO
