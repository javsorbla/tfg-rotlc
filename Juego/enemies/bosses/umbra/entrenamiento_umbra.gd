extends Node

@onready var umbra = $Umbra
@onready var player_dummy = $Player
@onready var spawn_umbra = $SpawnUmbra
@onready var spawn_player = $SpawnPlayer

func _ready():
	umbra.ai_controller.init(player_dummy)
	umbra.activate()
	print("Umbra activa: ", umbra.is_active)
	_reset()

func _reset():
	umbra.global_position = spawn_umbra.global_position
	umbra.current_health = umbra.MAX_HEALTH
	player_dummy.global_position = spawn_player.global_position
	player_dummy.get_node("Health").current_health = player_dummy.get_node("Health").MAX_HEALTH
