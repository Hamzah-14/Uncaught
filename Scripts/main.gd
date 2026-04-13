class_name ArenaController
extends Node3D

@export var csp_generator: CSPGenerator
@export var game_manager: GameManager
@export var grid_manager: GridManager
@export var world_render: WorldRenderer
@export var hud: HUD
@export var powerup_manager: PowerupManager
@export var fruit_manager: FruitManager
@export var guardian_controller: GuardianController
#@export var terrain_generator: TerrainGenerator
@export var hotbar_ui: HotbarUI
@export var stamina_bar: StaminaBar
@export var debug_csp: bool = false  # true = animated generation, false = instant

var _retry_count: int = 0
var _max_retries: int = 5

func _ready() -> void:
	call_deferred("_start_sequence")

func _start_sequence() -> void:
	var maps = MapData.load_all()
	
	if maps.is_empty():
		push_error("No maps found in res://maps/ — using flat fallback")
		_fallback_flat()
	else:
		var chosen = maps[randi() % maps.size()]
		print("Loading map: ", chosen["name"])
		for pos in chosen["cells"]:
			grid_manager.set_cell(pos, chosen["cells"][pos])
	
	game_manager.round_changed.connect(_on_round_changed)
	world_render.render_grid()
	_spawn_ember()
	if powerup_manager:
		powerup_manager.setup(grid_manager)
	if fruit_manager:
		fruit_manager.setup(grid_manager)
	if hud:
		hud.setup(game_manager)
	if guardian_controller and fruit_manager:
		guardian_controller.fruit_manager = fruit_manager
	game_manager.start_bout()
	var player := get_tree().get_first_node_in_group("player") as PlayerController
	if player:
		if hotbar_ui:
			hotbar_ui.connect_to_hotbar(player.hotbar)
			print("[Arena] HotbarUI connected")
		else:
			push_warning("[Arena] hotbar_ui export is not assigned — hotbar will not render")
		if stamina_bar:
			stamina_bar.connect_to_player(player)
		else:
			push_warning("[Arena] stamina_bar export is not assigned — stamina bar will not render")
	else:
		push_error("[Arena] No node in group 'player' found — UI cannot connect")
	print("[Arena] Ready. Powerups: ", powerup_manager != null, " Fruits: ", fruit_manager != null,
		" HUD: ", hud != null, " HotbarUI: ", hotbar_ui != null, " StaminaBar: ", stamina_bar != null)

func _fallback_flat() -> void:
	for x in range(grid_manager.width):
		for y in range(grid_manager.height):
			grid_manager.set_cell(Vector2i(x, y), GridManager.CellType.FLOOR)
func _on_generation_complete(success: bool) -> void:
	if success:
		world_render.render_grid()
		_spawn_ember()
		if powerup_manager:
			powerup_manager.setup(grid_manager)
		if fruit_manager:
			fruit_manager.setup(grid_manager)
		if hud:
			hud.setup(game_manager)
		game_manager.start_bout()
		print("Arena ready.")
	else:
		_retry_count += 1
		if _retry_count >= _max_retries:
			push_error("CRITICAL: Arena generation failed after max retries. Falling back to flat arena.")
			_fallback_flat_arena()
			return
		print("CSP failed, retrying... attempt: ", _retry_count)
		csp_generator.generate_arena()

func _fallback_flat_arena() -> void:
	for x in range(grid_manager.width):
		for y in range(grid_manager.height):
			grid_manager.set_cell(Vector2i(x, y), GridManager.CellType.FLOOR)
	world_render.render_grid()
	_spawn_ember()
	if powerup_manager:
		powerup_manager.setup(grid_manager)
	if fruit_manager:
		fruit_manager.setup(grid_manager)
	if hud:
		hud.setup(game_manager)
	game_manager.start_bout()

func _on_round_changed(round_num: int, capacity: int) -> void:
	if guardian_controller:
		guardian_controller.set_hotbar_capacity(capacity)
	if powerup_manager:
		powerup_manager.set_round(round_num)
	# Reset ember to center for new round
	var ember = get_tree().get_first_node_in_group("ember") as EmberObject
	if ember:
		ember.drop()  # drop from holder if held
		await get_tree().create_timer(0.1).timeout  # let drop() settle
		var center := Vector2i(grid_manager.width / 2, grid_manager.height / 2)
		ember.global_position = grid_manager.grid_to_world(center, 0.5)
		print("[Arena] Ember repositioned to center for round ", round_num)
	print("[Arena] Round ", round_num, " started — guardian hotbar capacity: ", capacity)

func _spawn_ember() -> void:
	var ember_scene = preload("res://Scenes/objects/ember.tscn")
	var ember = ember_scene.instantiate()
	ember.setup(game_manager, grid_manager, self)  # once, before add_child
	add_child(ember)
	var center = Vector2i(grid_manager.width / 2, grid_manager.height / 2)
	ember.global_position = grid_manager.grid_to_world(center, 0.5)
	ember.add_to_group("ember")
