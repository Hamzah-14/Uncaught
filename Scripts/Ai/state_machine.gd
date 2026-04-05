class_name GuardianStateMachine
extends Node

enum Mode { CHASE, SEARCH, INTERCEPT, AGGRESSIVE }

var current_mode: Mode = Mode.SEARCH

# Thresholds (you can tweak these numbers to change Guardian behavior)
@export var chase_range: float = 8.0       # tiles away before Guardian chases
@export var aggressive_range: float = 12.0  # tiles away in aggressive mode
@export var search_duration: float = 5.0    # seconds before giving up searching

# Internal tracking
var _time_in_search: float = 0.0
var _player_last_known: Vector2i = Vector2i.ZERO
var _player_last_direction: Vector2i = Vector2i.ZERO

# References (set these up in guardian_controller.gd)
var player_visible: bool = false
var player_holds_ember: bool = false
var guardian_holds_ember: bool = false
var distance_to_player: float = 999.0
var player_grid_pos: Vector2i = Vector2i.ZERO

func _process(delta: float) -> void:
	_evaluate_state(delta)

func _evaluate_state(delta: float) -> void:
	var previous_mode = current_mode

	# --- Rule evaluation (order matters — top rules win) ---

	# Rule 1: Player has the ember → always aggressive
	if player_holds_ember:
		current_mode = Mode.AGGRESSIVE

	# Rule 2: Guardian has ember → chase player to protect lead
	elif guardian_holds_ember and player_visible:
		current_mode = Mode.CHASE

	# Rule 3: Player visible and close → chase
	elif player_visible and distance_to_player <= chase_range:
		current_mode = Mode.CHASE

	# Rule 4: Player visible but far → try to intercept
	elif player_visible and distance_to_player > chase_range:
		current_mode = Mode.INTERCEPT

	# Rule 5: Player not visible → search
	elif not player_visible:
		current_mode = Mode.SEARCH
		_time_in_search += delta

	# --- Debug print when mode changes ---
	if current_mode != previous_mode:
		print("Guardian mode: ", Mode.keys()[current_mode])

func update_sensors(
	p_visible: bool,
	p_holds_ember: bool,
	g_holds_ember: bool,
	dist: float,
	p_pos: Vector2i,
	p_dir: Vector2i
) -> void:
	player_visible = p_visible
	player_holds_ember = p_holds_ember
	guardian_holds_ember = g_holds_ember
	distance_to_player = dist
	player_grid_pos = p_pos
	_player_last_direction = p_dir

	if p_visible:
		_player_last_known = p_pos
		_time_in_search = 0.0

func get_goal() -> Vector2i:
	match current_mode:
		Mode.CHASE:
			return player_grid_pos
		Mode.AGGRESSIVE:
			return player_grid_pos
		Mode.SEARCH:
			return _player_last_known
		Mode.INTERCEPT:
			# Predict where player is heading
			return _player_last_known + (_player_last_direction * 3)
	return player_grid_pos
