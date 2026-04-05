class_name PlayerController
extends CharacterBody3D

# --- Signals for the UI Hotbar/Stamina Bar ---
signal stamina_changed(current_stamina: float, max_stamina: float)

@export_category("Movement")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 9.0
@export var acceleration: float = 10.0

@export_category("Stamina")
@export var max_stamina: float = 100.0
@export var stamina_drain_rate: float = 25.0 # Drains in 4 seconds
@export var stamina_regen_rate: float = 15.0 # Regens slightly slower
@export var exhaustion_threshold: float = 20.0 # Must regen to this before sprinting again

var _current_stamina: float
var _is_exhausted: bool = false

func _ready() -> void:
	_current_stamina = max_stamina

func _physics_process(delta: float) -> void:
	# 1. Input Mapping (Requires setting up "move_up", "move_down", etc. in Project Settings -> Input Map)
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction = Vector3(input_dir.x, 0, input_dir.y).normalized()
	
	# 2. Sprint & Stamina Logic
	var is_trying_to_sprint = Input.is_action_pressed("sprint")
	var current_speed = walk_speed
	
	if is_trying_to_sprint and not _is_exhausted and direction != Vector3.ZERO:
		current_speed = sprint_speed
		_drain_stamina(delta)
	else:
		_regen_stamina(delta)
		
	# 3. Apply Velocity (X and Z axes only)
	if direction:
		velocity.x = move_toward(velocity.x, direction.x * current_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * current_speed, acceleration * delta)
		
		## Optional: Make the player mesh look at the direction of movement
		#var look_target = global_position + direction
		#look_at(look_target, Vector3.UP)
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
		
	# Clear exhaustion lock once we pass the threshold
	if _is_exhausted and _current_stamina >= exhaustion_threshold:
		_is_exhausted = false
