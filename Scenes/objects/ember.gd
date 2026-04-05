class_name Ember
extends Area3D

@export var game_manager: GameManager
@export var float_speed: float = 2.0
@export var float_amplitude: float = 0.5
@export var neutral_duration: float = 3.0 # 3 seconds ungrabbable after drop

var _is_held: bool = false
var _holder: Node3D = null
var _neutral_timer: float = 0.0
var _base_y: float = 1.0 # Hover height

func _ready() -> void:
	# Listen for bodies entering the Area3D
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if _neutral_timer > 0.0:
		_neutral_timer -= delta

	if _is_held and is_instance_valid(_holder):
		# Physically snap to the holder, hovering slightly above them
		global_position = _holder.global_position + Vector3(0, 2.0, 0)
	else:
		# Idle floating animation when on the ground
		global_position.y = _base_y + sin(Time.get_ticks_msec() / 1000.0 * float_speed) * float_amplitude

func _on_body_entered(body: Node3D) -> void:
	# Cannot be picked up if it's in the 3-second neutral window
	if _neutral_timer > 0.0 or _is_held:
		return
		
	if body is PlayerController:
		_attach_to(body, GameManager.Holder.PLAYER)
	# TODO: Add Guardian check here once we build the GuardianController

func _attach_to(entity: Node3D, holder_type: GameManager.Holder) -> void:
	_is_held = true
	_holder = entity
	
	if game_manager:
		game_manager.set_ember_holder(holder_type)
		
	print(entity.name, " claimed the Ember!")

## Called by the Player/Guardian if they get frozen, tagged, or use the Drop ability
func drop(safe_grid_pos: Vector3) -> void:
	_is_held = false
	_holder = null
	_neutral_timer = neutral_duration
	
	# Snap to the nearest safe floor tile passed by the dropping entity
	global_position = safe_grid_pos
	_base_y = safe_grid_pos.y + 1.0
	
	if game_manager:
		game_manager.set_ember_holder(GameManager.Holder.NONE)
		
	print("Ember dropped! Neutral for ", neutral_duration, " seconds.")
