class_name GuardianHotbar
extends Node

# Valid collectible types for the guardian.
const VALID_TYPES: Array[String] = [
	"freeze", "slow_field", "speed_boost", "phase_dash", "fruit_wipe", "pull"
]

var _capacity: int = 0
var _slots: Array[String] = []
var _selected_index: int = 0

# Resize slot array. Growing adds empty slots; shrinking drops trailing slots
# and clamps the selected index so it never points out of bounds.
func set_capacity(n: int) -> void:
	_capacity = max(0, n)
	while _slots.size() < _capacity:
		_slots.append("")
	while _slots.size() > _capacity:
		_slots.pop_back()
	if _capacity > 0:
		_selected_index = clampi(_selected_index, 0, _capacity - 1)
	else:
		_selected_index = 0

# Adds a type to the first empty slot. Rejects duplicates and returns false if
# capacity is 0, the type is already held, or all slots are occupied.
func try_add(type: String) -> bool:
	if _capacity == 0:
		return false
	if type in _slots:
		return false
	for i in _capacity:
		if _slots[i] == "":
			_slots[i] = type
			return true
	return false

# Returns true if the given type is currently held in any slot.
func has_type(type: String) -> bool:
	return type in _slots

# Finds and consumes the first slot holding the given type.
# Used by AI logic to fire a specific powerup by name.
func use_slot(type: String) -> bool:
	for i in _capacity:
		if _slots[i] == type:
			_slots[i] = ""
			return true
	return false

func use_selected() -> String:
	if _capacity == 0 or _slots.is_empty():
		return ""
	var type := _slots[_selected_index]
	_slots[_selected_index] = ""
	return type

func current_selection() -> String:
	if _capacity == 0 or _slots.is_empty():
		return ""
	return _slots[_selected_index]

func select_next() -> void:
	if _capacity > 0:
		_selected_index = (_selected_index + 1) % _capacity

func select_prev() -> void:
	if _capacity > 0:
		_selected_index = (_selected_index - 1 + _capacity) % _capacity

func select_slot(index: int) -> void:
	if index >= 0 and index < _capacity:
		_selected_index = index
