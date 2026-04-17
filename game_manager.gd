class_name GameManager
extends Node

# --- Signals for UI and AI ---
signal time_updated(time_left: float)
signal score_updated(player_score: float, guardian_score: float)
signal bout_ended(player_won: bool)
signal round_ended(round_num: int, player_won_round: bool)
signal round_changed(round_num: int, guardian_capacity: int)
signal ember_possession_changed(holder: Holder)

enum Holder { NONE, PLAYER, GUARDIAN }

@export var match_duration: float = 10.0 # 3 minutes
@export var player_score_rate: float = 1.0 # points per second
@export var guardian_score_rate: float = 0.75 # points per second

var _time_remaining: float
var _player_score: float = 0.0
var _guardian_score: float = 0.0
var _current_holder: Holder = Holder.NONE
var _match_active: bool = false
var _current_round: int = 1
var _max_rounds: int = 3
var _player_rounds_won: int = 0
var _guardian_rounds_won: int = 0

func _ready() -> void:
	# Disable processing until the match officially starts 
	# (e.g., after CSP generation finishes)
	#set_process(false)
	pass
func start_bout() -> void:
	_time_remaining = match_duration
	_player_score = 0.0
	_guardian_score = 0.0
	_current_holder = Holder.NONE
	_match_active = true
	set_process(true)

func _process(delta: float) -> void:
	if not _match_active:
		return
		
	# 1. Timer Logic
	_time_remaining -= delta
	emit_signal("time_updated", _time_remaining)
	
	if _time_remaining <= 0:
		_end_bout()
		return
		
	# 2. Scoring Logic
	if _current_holder == Holder.PLAYER:
		_player_score += player_score_rate * delta
		emit_signal("score_updated", _player_score, _guardian_score)
	elif _current_holder == Holder.GUARDIAN:
		_guardian_score += guardian_score_rate * delta
		emit_signal("score_updated", _player_score, _guardian_score)

# Called by the Ember object when an entity collides with it
func set_ember_holder(new_holder: Holder) -> void:
	if _current_holder != new_holder:
		_current_holder = new_holder
		emit_signal("ember_possession_changed", _current_holder)

func _end_bout() -> void:
	_match_active = false
	set_process(false)
	var player_won_round: bool = _player_score > _guardian_score
	print("[GameManager] Round ", _current_round, " ended — player won: ", player_won_round,
		" (P:", snapped(_player_score, 0.1), " G:", snapped(_guardian_score, 0.1), ")")
	if player_won_round:
		_player_rounds_won += 1
	else:
		_guardian_rounds_won += 1
	var finished_round := _current_round
	_current_round += 1
	if _current_round > _max_rounds:
		var player_won: bool = _player_rounds_won > _guardian_rounds_won
		print("[GameManager] Bout over — player wins bout: ", player_won,
			" (rounds P:", _player_rounds_won, " G:", _guardian_rounds_won, ")")
		emit_signal("bout_ended", player_won)
	else:
		emit_signal("round_ended", finished_round, player_won_round)
		reset_round()

func reset_round() -> void:
	_time_remaining = match_duration
	_player_score = 0.0
	_guardian_score = 0.0
	var new_capacity: int = min(_current_round - 1, 3)
	print("[GameManager] Round ", _current_round, " starting — guardian capacity: ", new_capacity)
	emit_signal("round_changed", _current_round, new_capacity)
	get_tree().paused = true
	await get_tree().create_timer(3.0, true).timeout
	get_tree().paused = false
	var player = get_tree().get_first_node_in_group("player")
	var guardian = get_tree().get_first_node_in_group("guardian")
	if player:
		player.reset_to_spawn()
	if guardian:
		guardian.reset_to_spawn()
	start_next_round()

func start_next_round() -> void:
	_current_holder = Holder.NONE
	emit_signal("ember_possession_changed", _current_holder)
	_match_active = true
	set_process(true)
	print("[GameManager] Match resumed — round ", _current_round)
	var ember = get_tree().get_first_node_in_group("ember")
	var grid_manager = get_tree().get_first_node_in_group("gridmanager")
	if ember and grid_manager:
		var rand_grid = Vector2i.ZERO
		var found = false
		while not found:
			var rand_x = randi_range(3, grid_manager.width - 3)
			var rand_y = randi_range(3, grid_manager.height - 3)
			rand_grid = Vector2i(rand_x, rand_y)
			if grid_manager.is_walkable(rand_grid):
				found = true
		ember.global_position = grid_manager.grid_to_world(rand_grid, 1.0)
