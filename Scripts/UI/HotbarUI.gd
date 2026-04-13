class_name HotbarUI
extends CanvasLayer

const SLOT_SIZE  := Vector2(80.0, 80.0)
const SLOT_GAP   := 8
const MARGIN_BOT := 20

var _panels: Array[Panel] = []
var _labels: Array[Label] = []
var _style_normal: StyleBoxFlat
var _style_selected: StyleBoxFlat

func _ready() -> void:
	_build_styles()
	_build_ui()

func _build_styles() -> void:
	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color = Color(0.08, 0.08, 0.10, 0.85)
	_style_normal.set_border_width_all(2)
	_style_normal.border_color = Color(0.45, 0.45, 0.50, 1.0)
	_style_normal.set_corner_radius_all(5)

	_style_selected = StyleBoxFlat.new()
	_style_selected.bg_color = Color(0.12, 0.12, 0.22, 0.92)
	_style_selected.set_border_width_all(3)
	_style_selected.border_color = Color(1.0, 0.82, 0.18, 1.0)  # golden highlight
	_style_selected.set_corner_radius_all(5)

func _build_ui() -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", SLOT_GAP)

	# Anchor to bottom-centre of the viewport
	hbox.anchor_left   = 0.5
	hbox.anchor_right  = 0.5
	hbox.anchor_top    = 1.0
	hbox.anchor_bottom = 1.0
	var half_w: float = (SLOT_SIZE.x * Hotbar.MAX_SLOTS + SLOT_GAP * (Hotbar.MAX_SLOTS - 1)) / 2.0
	hbox.offset_left   = -half_w
	hbox.offset_right  =  half_w
	hbox.offset_top    = -(SLOT_SIZE.y + MARGIN_BOT)
	hbox.offset_bottom = -MARGIN_BOT

	add_child(hbox)

	for i in Hotbar.MAX_SLOTS:
		var panel := Panel.new()
		panel.custom_minimum_size = SLOT_SIZE
		panel.add_theme_stylebox_override("panel", _style_normal)

		# Slot-number hint (1-indexed) — small label pinned to top-left
		var num_label := Label.new()
		num_label.text = str(i + 1)
		num_label.add_theme_font_size_override("font_size", 11)
		num_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
		num_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		num_label.offset_left  = 5
		num_label.offset_top   = 4
		num_label.offset_right  = 25
		num_label.offset_bottom = 20

		# Powerup name — centred in the panel
		var name_label := Label.new()
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		name_label.text = ""

		panel.add_child(num_label)
		panel.add_child(name_label)
		hbox.add_child(panel)

		_panels.append(panel)
		_labels.append(name_label)

# Call this once after the player node (and its Hotbar child) exist.
func connect_to_hotbar(hotbar: Hotbar) -> void:
	hotbar.hotbar_changed.connect(_on_hotbar_changed)
	# Trigger an immediate refresh so the UI reflects the current state.
	_on_hotbar_changed(hotbar._slots.duplicate(), hotbar._selected_index)

func _on_hotbar_changed(slots: Array, selected: int) -> void:
	for i in _panels.size():
		var type: String = slots[i] if i < slots.size() else ""
		_labels[i].text = _display_name(type)
		var style: StyleBoxFlat = _style_selected if i == selected else _style_normal
		_panels[i].add_theme_stylebox_override("panel", style)

func _display_name(type: String) -> String:
	match type:
		"freeze":      return "FREEZE"
		"speed_boost": return "BOOST"
		"slow_field":  return "SLOW"
		"shield":      return "Shield"
		"phase_dash":  return "Dash"
		"fruit_wipe":  return "Wipe"
		"":            return ""
		_:             return type.to_upper()
