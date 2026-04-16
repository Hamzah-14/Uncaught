extends CanvasLayer

@onready var end_screen = $Endscreen
@onready var end_label = $Endscreen/Label
@onready var timer_bar = $ProgressBar
@onready var round_label = $RoundLabel1
@onready var round_transition = $RoundTransition
@onready var transition_label = $RoundTransition/Label
var _game_manager: GameManager

func _ready() -> void:
	_game_manager = get_tree().get_first_node_in_group("game_manager")
	if _game_manager:
		timer_bar.max_value = _game_manager.match_duration
		_game_manager.round_changed.connect(_on_round_changed)
		_game_manager.bout_ended.connect(_on_bout_ended)
	round_transition.visible = false
	end_screen.visible = false

func _process(delta: float) -> void:
	if _game_manager == null:
		return
	timer_bar.value = _game_manager._time_remaining
	if _game_manager._time_remaining > 30:
		timer_bar.modulate = Color.GREEN
	elif _game_manager._time_remaining > 10:
		timer_bar.modulate = Color.YELLOW
	else:
		timer_bar.modulate = Color.RED

func _on_round_changed(round_num: int, guardian_capacity: int) -> void:
	round_label.text = "Round " + str(round_num)
	_show_transition(round_num)

func _show_transition(round_num: int) -> void:
	transition_label.text = "Round " + str(round_num) + "\nGet Ready... Let's Go!"
	round_transition.visible = true
	await get_tree().create_timer(3.0).timeout
	round_transition.visible = false

func _on_bout_ended(player_won: bool) -> void:
	end_screen.visible = true
	if player_won:
		end_screen.color = Color(0, 0.6, 0, 0.85)
		end_label.text = "You Won!\nBravo!"
	else:
		end_screen.color = Color(0.8, 0, 0, 0.85)
		end_label.text = "You Lost!\nBetter luck next time!"
