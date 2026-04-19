class_name HUD
extends CanvasLayer

# --- Required nodes (must exist on this CanvasLayer) ---
@onready var timer_label: Label = $TimerLabel
@onready var player_score: Label = $PlayerScore
@onready var guardian_score: Label = $GuardianScore
@onready var ember_status: Label = $EmberStatus
@onready var powerup_label: Label = $Poweruplabel

# --- Optional nodes (add in editor for full UI) ---
# ProgressBar  named "TimerBar"      — depleting timer bar
# Label        named "RoundIndicator" — permanent "ROUND III" on side
# ColorRect    named "RoundTransition" — fullscreen overlay between rounds
#   └ Label    named "Label"           — transition message text
# ColorRect    named "Endscreen"       — fullscreen loss screen
#   └ Label    named "Label"           — loss message text

var _timer_bar: ProgressBar
var _round_indicator: Label
var _round_transition: ColorRect
var _endscreen: ColorRect
var _multiplier_label: Label
var _game_manager: GameManager
var _showing_endscreen: bool = false

func setup(game_manager: GameManager) -> void:
	_game_manager = game_manager

	# Grab optional nodes safely
	_timer_bar        = get_node_or_null("TimeBar")
	_round_indicator  = get_node_or_null("RoundIndicator")
	_round_transition = get_node_or_null("RoundTransition")
	_endscreen        = get_node_or_null("EndScreen")
	_multiplier_label = get_node_or_null("MultiplierLabel")
	if _multiplier_label:
		_multiplier_label.visible = false

	if _timer_bar:
		_timer_bar.max_value = game_manager.match_duration
		_timer_bar.value = game_manager.match_duration
		_timer_bar.show_percentage = false
	if _round_transition:
		_round_transition.visible = false
	if _endscreen:
		_endscreen.visible = false
	if _round_indicator:
		_round_indicator.text = "ROUND I"

	game_manager.time_updated.connect(_on_time_updated)
	game_manager.score_updated.connect(_on_score_updated)
	game_manager.ember_possession_changed.connect(_on_ember_changed)
	game_manager.round_changed.connect(_on_round_changed)
	game_manager.round_won.connect(_on_round_won)
	game_manager.game_over.connect(_on_game_over)
	game_manager.multiplier_activated.connect(_on_multiplier_activated)

# --- Roman numeral helper ---
func _roman(n: int) -> String:
	if n <= 0:
		return str(n)
	var vals := [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
	var syms := ["M","CM","D","CD","C","XC","L","XL","X","IX","V","IV","I"]
	var result := ""
	for i in range(vals.size()):
		while n >= vals[i]:
			result += syms[i]
			n -= vals[i]
	return result

# --- Signal handlers ---
func _on_time_updated(time_left: float) -> void:
	var minutes := int(time_left) / 60
	var seconds := int(time_left) % 60
	timer_label.text = "%d:%02d" % [minutes, seconds]

	if _timer_bar:
		_timer_bar.value = time_left
		var pct := time_left / _game_manager.match_duration
		if pct > 0.5:
			_timer_bar.modulate = Color.GREEN
		elif pct > 0.25:
			_timer_bar.modulate = Color.YELLOW
		else:
			_timer_bar.modulate = Color.RED

func _on_score_updated(p_score: float, g_score: float) -> void:
	player_score.text = "YOU: %.1f" % p_score
	guardian_score.text = "GUARDIAN: %.1f" % g_score

func _on_ember_changed(holder) -> void:
	match holder:
		GameManager.Holder.PLAYER:
			ember_status.text = "YOU HOLD THE EMBER"
			ember_status.modulate = Color.CYAN
		GameManager.Holder.GUARDIAN:
			ember_status.text = "GUARDIAN HOLDS THE EMBER"
			ember_status.modulate = Color.RED
		GameManager.Holder.NONE:
			ember_status.text = "EMBER IS FREE"
			ember_status.modulate = Color.WHITE

func _on_multiplier_activated() -> void:
	if _multiplier_label:
		_multiplier_label.text = " LAST 20s! — POINT MULTIPLIER 1.5×"
		_multiplier_label.modulate = Color.YELLOW
		_multiplier_label.visible = true

func _on_round_changed(round_num: int, _capacity: int) -> void:
	if _round_indicator:
		_round_indicator.text = "ROUND " + _roman(round_num)
	if _round_transition:
		_round_transition.visible = false
	if _timer_bar and _game_manager:
		_timer_bar.max_value = _game_manager.match_duration
		_timer_bar.value = _game_manager.match_duration
	if _multiplier_label:
		_multiplier_label.visible = false

func _on_round_won(round_num: int) -> void:
	if _round_transition:
		var label: Label = _round_transition.get_node_or_null("Label")
		if label:
			label.text = "ROUND %s COMPLETE!\n\nGet ready for Round %s..." % [
				_roman(round_num), _roman(round_num + 1)
			]
		_round_transition.visible = true

func _on_game_over() -> void:
	if _endscreen:
		var label: Label = _endscreen.get_node_or_null("Label")
		if label and _game_manager:
			var failed_round := _game_manager._current_round
			var survived := failed_round - 1
			if survived == 0:
				label.text = "GAME OVER\n\nFailed Round %s\n\nPress R to restart" % _roman(failed_round)
			else:
				var plural := "round" if survived == 1 else "rounds"
				label.text = "GAME OVER\n\nSurvived %d %s\nFailed on Round %s\n\nPress R to restart" % [
					survived, plural, _roman(failed_round)
				]
		_endscreen.visible = true
		_showing_endscreen = true

func _unhandled_input(event: InputEvent) -> void:
	if _showing_endscreen and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			get_tree().reload_current_scene()

func update_powerup(has_freeze: bool) -> void:
	if has_freeze:
		powerup_label.text = "POWERUP: FREEZE (press F)"
		powerup_label.modulate = Color.CYAN
	else:
		powerup_label.text = "POWERUP: none"
		powerup_label.modulate = Color.GRAY
