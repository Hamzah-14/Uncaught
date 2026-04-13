class_name GuardianStateMachine
extends Node

enum Mode { CHASE, FLEE, INTERCEPT, AGGRESSIVE }

@export var chase_range: float = 6.0
@export var intercept_range: float = 8.0

var current_mode: Mode = Mode.CHASE
var _player_last_known: Vector2i = Vector2i.ZERO
var _player_last_direction: Vector2i = Vector2i.ZERO

# Sensor inputs
var player_visible: bool = false
var player_holds_ember: bool = false
var guardian_holds_ember: bool = false
var distance_to_player: float = 999.0
var player_grid_pos: Vector2i = Vector2i.ZERO
var time_remaining: float = 999.0
var score_deficit: float = 0.0

# Set by GuardianController after building PotentialField
var flee_goal: Vector2i = Vector2i.ZERO

# Set by GuardianController so INTERCEPT can clamp and validate walkability
var grid_size: Vector2i = Vector2i(19, 19)
@export var grid_manager: GridManager

func _process(delta: float) -> void:
	_evaluate_state(delta)

func update_sensors(
	p_visible: bool,
	p_holds_ember: bool,
	g_holds_ember: bool,
	dist: float,
	p_pos: Vector2i,
	p_dir: Vector2i,
	match_time_remaining: float,
	current_score_deficit: float
) -> void:
	player_visible = p_visible
	player_holds_ember = p_holds_ember
	guardian_holds_ember = g_holds_ember
	distance_to_player = dist
	player_grid_pos = p_pos
	_player_last_direction = p_dir
	time_remaining = match_time_remaining
	score_deficit = current_score_deficit

	if p_visible:
		_player_last_known = p_pos

func _evaluate_state(delta: float) -> void:
	var previous_mode = current_mode

	if guardian_holds_ember:
		# Guardian has the Ember — run away using PotentialField
		current_mode = Mode.FLEE
	elif time_remaining < 45.0 and score_deficit >= 2.0:
		current_mode = Mode.AGGRESSIVE
	elif player_visible and distance_to_player <= chase_range:
		current_mode = Mode.CHASE
	elif player_visible and distance_to_player <= intercept_range:
		current_mode = Mode.INTERCEPT
	else:
		current_mode = Mode.CHASE

	if current_mode != previous_mode:
		print("Guardian mode: ", Mode.keys()[current_mode])

func get_goal() -> Vector2i:
	match current_mode:
		Mode.CHASE:
			return player_grid_pos
		Mode.AGGRESSIVE:
			return player_grid_pos
		Mode.FLEE:
			return flee_goal  # set externally by GuardianController each frame
		Mode.INTERCEPT:
			var predicted = _player_last_known + (_player_last_direction * 2)
			# Clamp to grid bounds
			predicted.x = clamp(predicted.x, 0, grid_size.x - 1)
			predicted.y = clamp(predicted.y, 0, grid_size.y - 1)
			# If the predicted tile is inside an obstacle, fall back to the
			# player's current position so A* can route around walls normally.
			if grid_manager == null or not grid_manager.is_walkable(predicted):
				return player_grid_pos
			return predicted
	return player_grid_pos
