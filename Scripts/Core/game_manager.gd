class_name GameManager
extends Node

# --- Signals for UI and AI ---
signal time_updated(time_left: float)
signal score_updated(player_score: float, guardian_score: float)
signal bout_ended(player_won: bool)
signal ember_possession_changed(holder: Holder)

enum Holder { NONE, PLAYER, GUARDIAN }

@export var match_duration: float = 180.0 # 3 minutes
@export var player_score_rate: float = 1.0 # points per second
@export var guardian_score_rate: float = 0.75 # points per second

var _time_remaining: float
var _player_score: float = 0.0
var _guardian_score: float = 0.0
var _current_holder: Holder = Holder.NONE
var _match_active: bool = false

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
	var player_won: bool = _player_score > _guardian_score
	emit_signal("bout_ended", player_won)
