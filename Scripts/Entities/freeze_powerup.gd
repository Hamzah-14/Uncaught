class_name FreezePowerup
extends Area3D

signal collected

@export var pickup_distance: float = 2.0
var _collected: bool = false

func _physics_process(_delta: float) -> void:
	if _collected:
		return
	var player = get_tree().get_first_node_in_group("player")
	if player and global_position.distance_to(player.global_position) < pickup_distance:
		_collected = true
		print("Freeze power-up collected!")
		player.collect_powerup("freeze")
		emit_signal("collected")
		queue_free()
