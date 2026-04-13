class_name MapEditor
extends Control

@onready var hex_canvas: HexCanvas = $HSplitContainer/CanvasPanel/ScrollContainer/HexCanvas
@onready var map_name_input: LineEdit = $HSplitContainer/Sidebar/VBox/MapName
@onready var status_label: Label = $HSplitContainer/Sidebar/VBox/StatusLabel
@onready var map_list: ItemList = $HSplitContainer/Sidebar/VBox/MapList
@onready var hover_label: Label = $HSplitContainer/Sidebar/VBox/HoverLabel
@onready var tool_container: GridContainer = $HSplitContainer/Sidebar/VBox/ToolGrid

const MAPS_DIR = "res://maps/"
const TYPE_NAMES = {
	0: "FLOOR",
	1: "FLOOR_HIGH",
	2: "RIVER_WATER",
	3: "RIVER_SHORE",
	4: "BRIDGE",
	5: "SANCTUM",
	6: "HAZARD_COLLAPSE",
	7: "HAZARD_TRAP",
}
const TOOL_COLORS = {
	0: Color(0.22, 0.45, 0.15),
	1: Color(0.42, 0.32, 0.18),
	2: Color(0.18, 0.45, 0.72),
	3: Color(0.42, 0.72, 0.55),
	4: Color(0.55, 0.45, 0.35),
	5: Color(0.55, 0.25, 0.65),
	6: Color(0.75, 0.22, 0.15),
	7: Color(0.80, 0.45, 0.10),
}

var _tool_buttons: Array[Button] = []
var _active_tool: int = 0

func _ready() -> void:
	_setup_tool_buttons()
	_setup_map_list_style()  # ← add this
	hex_canvas.tile_painted.connect(_on_tile_painted)
	hex_canvas.hovered.connect(_on_hovered)
	_ensure_maps_dir()
	_refresh_map_list()
	_set_status("Ready. Click to paint, right-click to erase.")

func _setup_map_list_style() -> void:
	# Style the ItemList
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.15, 0.15)
	sb.border_color = Color(0.3, 0.3, 0.3)
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	map_list.add_theme_stylebox_override("panel", sb)
	map_list.add_theme_color_override("font_color", Color.WHITE)
	map_list.add_theme_color_override("font_selected_color", Color.WHITE)
	
	var sb_selected = StyleBoxFlat.new()
	sb_selected.bg_color = Color(0.25, 0.45, 0.25)
	sb_selected.corner_radius_top_left = 4
	sb_selected.corner_radius_top_right = 4
	sb_selected.corner_radius_bottom_left = 4
	sb_selected.corner_radius_bottom_right = 4
	map_list.add_theme_stylebox_override("selected", sb_selected)
	map_list.add_theme_constant_override("v_separation", 8)
	
	# Style action buttons
	_style_action_button($HSplitContainer/Sidebar/VBox/SaveMap, Color(0.20, 0.55, 0.25))
	_style_action_button($HSplitContainer/Sidebar/VBox/LoadMap, Color(0.20, 0.35, 0.55))
	_style_action_button($HSplitContainer/Sidebar/VBox/Delete, Color(0.55, 0.20, 0.20))
	_style_action_button($HSplitContainer/Sidebar/VBox/Clear, Color(0.40, 0.40, 0.15))

func _style_action_button(btn: Button, color: Color) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	var sb_hover = sb.duplicate()
	sb_hover.bg_color = color.lightened(0.15)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.custom_minimum_size = Vector2(0, 34)
func _setup_tool_buttons() -> void:
	for t in TYPE_NAMES:
		var btn = Button.new()
		btn.text = TYPE_NAMES[t]
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(90, 32)
		
		var sb = StyleBoxFlat.new()
		sb.bg_color = TOOL_COLORS.get(t, Color.GRAY)
		sb.corner_radius_top_left = 4
		sb.corner_radius_top_right = 4
		sb.corner_radius_bottom_left = 4
		sb.corner_radius_bottom_right = 4
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		
		var sb_pressed = sb.duplicate()
		sb_pressed.border_width_top = 2
		sb_pressed.border_width_bottom = 2
		sb_pressed.border_width_left = 2
		sb_pressed.border_width_right = 2
		sb_pressed.border_color = Color.WHITE
		
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("pressed", sb_pressed)
		btn.add_theme_stylebox_override("hover", sb_pressed)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_pressed_color", Color.WHITE)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.pressed.connect(_on_tool_selected.bind(t, btn))
		tool_container.add_child(btn)
		_tool_buttons.append(btn)
		if t == 0:
			btn.button_pressed = true

func _on_tool_selected(type: int, btn: Button) -> void:
	_active_tool = type
	hex_canvas.active_tool = type
	for b in _tool_buttons:
		b.button_pressed = false
	btn.button_pressed = true

func _on_tile_painted(_pos: Vector2i, _type: int) -> void:
	_update_counts()

func _on_hovered(pos: Vector2i) -> void:
	if pos.x >= 0:
		hover_label.text = "Cell: (%d, %d)  Tool: %s" % [pos.x, pos.y, TYPE_NAMES.get(_active_tool, "?")]

func _update_counts() -> void:
	var counts = hex_canvas.get_tile_counts()
	var parts = []
	for t in TYPE_NAMES:
		if counts.get(t, 0) > 0:
			parts.append("%s: %d" % [TYPE_NAMES[t], counts[t]])
	status_label.text = "  ".join(parts)

func _ensure_maps_dir() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(MAPS_DIR)):
		DirAccess.make_dir_absolute(ProjectSettings.globalize_path(MAPS_DIR))

func _refresh_map_list() -> void:
	map_list.clear()
	var dir = DirAccess.open(MAPS_DIR)
	if dir == null:
		map_list.add_item("No maps yet — paint and save!")
		return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			map_list.add_item(fname.replace(".json", "").strip_edges())
		fname = dir.get_next()

func _on_save_map_pressed() -> void:
	var name = map_name_input.text.strip_edges()
	if name.is_empty():
		_set_status("ERROR: Enter a map name first.")
		return
	
	var cells = {}
	for pos in hex_canvas.grid:
		cells["%d,%d" % [pos.x, pos.y]] = hex_canvas.grid[pos]
	
	var data = {
		"name": name,
		"width": HexCanvas.GRID_W,
		"height": HexCanvas.GRID_H,
		"cells": cells
	}
	
	var path = MAPS_DIR + name + ".json"
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_set_status("ERROR: Could not write file.")
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	
	_set_status("Saved: " + name)
	_refresh_map_list()

func _on_load_selected_pressed() -> void:
	var selected = map_list.get_selected_items()
	if selected.is_empty():
		_set_status("Select a map to load.")
		return
	var name = map_list.get_item_text(selected[0])
	_load_map(name)

func _load_map(name: String) -> void:
	var path = MAPS_DIR + name.strip_edges() + ".json"
	print("Trying to load: ", path)
	print("Absolute: ", ProjectSettings.globalize_path(path))
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("Error code: ", FileAccess.get_open_error())
		_set_status("ERROR: Could not read file.")
		return
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()
	if err != OK:
		_set_status("ERROR: Invalid JSON.")
		return
	
	var data = json.data
	var cells: Dictionary = {}
	for key in data["cells"]:
		var parts = key.split(",")
		var pos = Vector2i(int(parts[0]), int(parts[1]))
		cells[pos] = int(data["cells"][key])
	
	hex_canvas.load_from_dict(cells)
	map_name_input.text = data["name"]
	_set_status("Loaded: " + data["name"])
	_update_counts()

func _on_delete_selected_pressed() -> void:
	var selected = map_list.get_selected_items()
	if selected.is_empty():
		return
	var name = map_list.get_item_text(selected[0])
	var path = ProjectSettings.globalize_path(MAPS_DIR + name + ".json")
	if FileAccess.file_exists(MAPS_DIR + name + ".json"):
		OS.move_to_trash(path)
	_set_status("Deleted: " + name)
	_refresh_map_list()

func _on_clear_canvas_pressed() -> void:
	hex_canvas.clear()
	_set_status("Canvas cleared.")

func _set_status(msg: String) -> void:
	status_label.text = msg
