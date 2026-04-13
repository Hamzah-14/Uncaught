class_name Hotbar
extends Node

signal hotbar_changed(slots: Array, selected: int)

const MAX_SLOTS: int = 4
const VALID_TYPES: Array[String] = [
	"freeze", "slow_field", "speed_boost", "shield", "phase_dash"
]

var _slots: Array[String] = ["", "", "", ""]
var _selected_index: int = 0

# Adds a powerup type to the first empty slot.
# Returns false if the type is already held or all slots are full.
func try_add(type: String) -> bool:
	if type in _slots:
		return false
	for i in MAX_SLOTS:
		if _slots[i] == "":
			_slots[i] = type
			_emit_changed()
			return true
	return false

# Consumes and returns the type in the selected slot ("" if empty).
func use_selected() -> String:
	var type := _slots[_selected_index]
	_slots[_selected_index] = ""
	_emit_changed()
	return type

func select_next() -> void:
	_selected_index = (_selected_index + 1) % MAX_SLOTS
	_emit_changed()

func select_prev() -> void:
	_selected_index = (_selected_index - 1 + MAX_SLOTS) % MAX_SLOTS
	_emit_changed()

func select_slot(index: int) -> void:
	if index >= 0 and index < MAX_SLOTS:
		_selected_index = index
		_emit_changed()

func current_selection() -> String:
	return _slots[_selected_index]

func _emit_changed() -> void:
	emit_signal("hotbar_changed", _slots.duplicate(), _selected_index)
