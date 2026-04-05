class_name HUD
extends CanvasLayer

@onready var timer_label: Label = $TimerLabel
@onready var player_score: Label = $PLayerScore
@onready var guardian_score: Label = $GuardianScore
@onready var ember_status: Label = $EmberStatus
@onready var powerup_label: Label = $Poweruplabel

func setup(game_manager: GameManager) -> void:
	game_manager.time_updated.connect(_on_time_updated)
	game_manager.score_updated.connect(_on_score_updated)
	game_manager.ember_possession_changed.connect(_on_ember_changed)
	game_manager.bout_ended.connect(_on_bout_ended)
	game_manager.round_changed.connect(_on_round_changed)

func _on_round_changed(round_number: int) -> void:
	if round_number == 1:
		ember_status.text = "ROUND 1 - Good luck!"
	else:
		ember_status.text = "ROUND " + str(round_number) + " - Difficulty increased!"
	ember_status.modulate = Color.YELLOW
	await get_tree().create_timer(2.0).timeout
	ember_status.text = "EMBER IS FREE"
	ember_status.modulate = Color.WHITE

func _on_time_updated(time_left: float) -> void:
	var minutes = int(time_left) / 60
	var seconds = int(time_left) % 60
	timer_label.text = "%d:%02d" % [minutes, seconds]

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

func _on_bout_ended(player_won: bool) -> void:
	if player_won:
		ember_status.text = "YOU WIN! Difficulty increasing..."
		ember_status.modulate = Color.GREEN
	else:
		ember_status.text = "GUARDIAN WINS! Back to round 1..."
		ember_status.modulate = Color.RED

func update_powerup(has_freeze: bool) -> void:
	if has_freeze:
		powerup_label.text = "POWERUP: FREEZE (press F)"
		powerup_label.modulate = Color.CYAN
	else:
		powerup_label.text = "POWERUP: none"
		powerup_label.modulate = Color.GRAY
