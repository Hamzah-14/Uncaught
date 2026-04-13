class_name StaminaBar
extends CanvasLayer

const BAR_WIDTH:  float = 200.0
const BAR_HEIGHT: float = 20.0
const MARGIN_LEFT: float = 20.0
const MARGIN_BOT:  float = 60.0  # sits above the hotbar row

var _fill: ColorRect

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Label
	var label := Label.new()
	label.text = "Stamina"
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1.0))
	label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	label.offset_left   = MARGIN_LEFT
	label.offset_bottom = -(MARGIN_BOT + BAR_HEIGHT + 4)
	label.offset_right  = MARGIN_LEFT + BAR_WIDTH
	label.offset_top    = label.offset_bottom - 18
	add_child(label)

	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.12, 0.12, 0.85)
	bg.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bg.offset_left   = MARGIN_LEFT
	bg.offset_right  = MARGIN_LEFT + BAR_WIDTH
	bg.offset_bottom = -MARGIN_BOT
	bg.offset_top    = -(MARGIN_BOT + BAR_HEIGHT)
	add_child(bg)

	# Fill
	_fill = ColorRect.new()
	_fill.color = Color(0.2, 0.85, 0.2, 1.0)
	_fill.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_fill.offset_left   = MARGIN_LEFT
	_fill.offset_right  = MARGIN_LEFT + BAR_WIDTH
	_fill.offset_bottom = -MARGIN_BOT
	_fill.offset_top    = -(MARGIN_BOT + BAR_HEIGHT)
	add_child(_fill)

func connect_to_player(player: PlayerController) -> void:
	player.stamina_changed.connect(_on_stamina_changed)
	# Immediate refresh with actual current values
	_on_stamina_changed(player._current_stamina, player.max_stamina)
	print("[StaminaBar] Connected — initial stamina: ", player._current_stamina)

func _on_stamina_changed(current: float, maximum: float) -> void:
	var pct: float = current / maximum if maximum > 0.0 else 0.0
	_fill.offset_right = MARGIN_LEFT + BAR_WIDTH * pct

	if pct * 100.0 < 20.0:
		_fill.color = Color(0.9, 0.15, 0.15, 1.0)   # red
	elif pct * 100.0 < 40.0:
		_fill.color = Color(0.95, 0.75, 0.1, 1.0)   # yellow
	else:
		_fill.color = Color(0.2, 0.85, 0.2, 1.0)    # green
