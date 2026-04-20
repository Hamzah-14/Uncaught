class_name GameManager
extends Node

# --- Signals ---
signal time_updated(time_left: float)
signal score_updated(player_score: float, guardian_score: float)
signal round_won(round_num: int)      # player survived — transition shown, next round incoming
signal game_over()                     # guardian won — show loss screen
signal round_changed(round_num: int, guardian_capacity: int)
signal ember_possession_changed(holder: Holder)
signal multiplier_activated

enum Holder { NONE, PLAYER, GUARDIAN }

@export var match_duration: float = 90.0
@export var player_score_rate: float = 1.0
@export var guardian_score_rate: float = 0.75

var _time_remaining: float
var _player_score: float = 0.0
var _guardian_score: float = 0.0
var _current_holder: Holder = Holder.NONE
var _match_active: bool = false
var _current_round: int = 1
var _multiplier_active: bool = false

func _ready() -> void:
	pass

func _get_duration_for_round(round_num: int) -> float:
	match round_num:
		1: return 60.0
		2: return 90.0
		3: return 120.0
		4: return 150.0
		_: return 180.0

func start_bout() -> void:
	match_duration = _get_duration_for_round(_current_round)
	_time_remaining = match_duration
	_player_score = 0.0
	_guardian_score = 0.0
	_current_holder = Holder.NONE
	_multiplier_active = false
	_match_active = true
	set_process(true)

func _process(delta: float) -> void:
	if not _match_active:
		return

	_time_remaining -= delta
	emit_signal("time_updated", _time_remaining)

	if _time_remaining <= 0:
		_end_bout()
		return

	if not _multiplier_active and _time_remaining <= 20.0:
		_multiplier_active = true
		emit_signal("multiplier_activated")

	var rate_mult := 1.5 if _multiplier_active else 1.0
	if _current_holder == Holder.PLAYER:
		_player_score += player_score_rate * rate_mult * delta
		emit_signal("score_updated", _player_score, _guardian_score)
	elif _current_holder == Holder.GUARDIAN:
		_guardian_score += guardian_score_rate * rate_mult * delta
		emit_signal("score_updated", _player_score, _guardian_score)

func set_ember_holder(new_holder: Holder) -> void:
	if _current_holder != new_holder:
		_current_holder = new_holder
		emit_signal("ember_possession_changed", _current_holder)

func _end_bout() -> void:
	_match_active = false
	set_process(false)
	var player_won: bool = _player_score > _guardian_score
	print("[GameManager] Round ", _current_round, " ended — player won: ", player_won,
		" (P:", snapped(_player_score, 0.1), " G:", snapped(_guardian_score, 0.1), ")")

	if player_won:
		var finished_round := _current_round
		_current_round += 1
		emit_signal("round_won", finished_round)
		# HUD shows transition — wait then start next round automatically
		await get_tree().create_timer(3.5).timeout
		reset_round()
	else:
		# Emit before resetting so HUD can read _current_round for the failure message
		emit_signal("game_over")
		_current_round = 1

func reset_round() -> void:
	match_duration = _get_duration_for_round(_current_round)
	_time_remaining = match_duration
	_player_score = 0.0
	_guardian_score = 0.0
	var new_capacity: int = min(_current_round, 4)
	print("[GameManager] Round ", _current_round, " starting — capacity: ", new_capacity, " duration: ", match_duration, "s")
	emit_signal("round_changed", _current_round, new_capacity)
	start_next_round()

func start_next_round() -> void:
	_current_holder = Holder.NONE
	_multiplier_active = false
	emit_signal("ember_possession_changed", _current_holder)
	_match_active = true
	set_process(true)
	print("[GameManager] Match resumed — round ", _current_round)
