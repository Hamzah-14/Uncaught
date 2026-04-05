class_name PlayerController
extends CharacterBody3D

signal stamina_changed(current_stamina: float, max_stamina: float)

@export_category("Movement")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 9.0
@export var acceleration: float = 10.0

@export_category("Stamina")
@export var max_stamina: float = 100.0
@export var stamina_drain_rate: float = 25.0
@export var stamina_regen_rate: float = 15.0
@export var exhaustion_threshold: float = 20.0

var _current_stamina: float
var _is_exhausted: bool = false
var _has_freeze: bool = false

func _ready() -> void:
	_current_stamina = max_stamina

func _physics_process(delta: float) -> void:
	# 1. Input
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction = Vector3(input_dir.x, 0, input_dir.y).normalized()
	
	# 2. Use power-up
	if Input.is_action_just_pressed("use_powerup"):
		_use_freeze()
	
	# 3. Sprint & Stamina
	var is_trying_to_sprint = Input.is_action_pressed("sprint")
	var current_speed = walk_speed
	
	if is_trying_to_sprint and not _is_exhausted and direction != Vector3.ZERO:
		current_speed = sprint_speed
		_drain_stamina(delta)
	else:
		_regen_stamina(delta)
	
	# 4. Apply Velocity
	if direction:
		velocity.x = move_toward(velocity.x, direction.x * current_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * current_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0, acceleration * delta)
	
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	move_and_slide()

func _drain_stamina(delta: float) -> void:
	_current_stamina = max(_current_stamina - (stamina_drain_rate * delta), 0.0)
	emit_signal("stamina_changed", _current_stamina, max_stamina)
	if _current_stamina <= 0.0:
		_is_exhausted = true

func _regen_stamina(delta: float) -> void:
	if _current_stamina < max_stamina:
		_current_stamina = min(_current_stamina + (stamina_regen_rate * delta), max_stamina)
		emit_signal("stamina_changed", _current_stamina, max_stamina)
	if _is_exhausted and _current_stamina >= exhaustion_threshold:
		_is_exhausted = false

func collect_powerup(type: String) -> void:
	if type == "freeze":
		_has_freeze = true
		print("Player has freeze power-up - press F to use!")

func _use_freeze() -> void:
	if not _has_freeze:
		return
	_has_freeze = false
	var guardian = get_tree().get_first_node_in_group("guardian")
	if guardian:
		guardian.freeze(3.0)
		print("Guardian frozen!")
