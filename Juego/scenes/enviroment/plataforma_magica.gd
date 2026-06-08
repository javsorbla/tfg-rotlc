extends StaticBody2D

@export var plataforma_siguiente: StaticBody2D
@export var plataforma_anterior: StaticBody2D
@export var activa_al_inicio: bool = false

var sfx_player: AudioStreamPlayer2D

func _ready():
	sfx_player = AudioStreamPlayer2D.new()
	sfx_player.name = "PlataformaMagicaSfx"
	sfx_player.stream = load("res://music/scenes/torre_vacio/plataforma_magica.ogg")
	sfx_player.bus = &"EFX"
	sfx_player.volume_db = 4.0
	sfx_player.max_distance = 800.0
	add_child(sfx_player)

	call_deferred("_inicializar")

func _inicializar():
	if activa_al_inicio:
		aparecer()
	else:
		desaparecer()

func aparecer():
	show()
	process_mode = Node.PROCESS_MODE_INHERIT
	sfx_player.stop()
	sfx_player.play()

func desaparecer():
	hide()
	process_mode = Node.PROCESS_MODE_DISABLED

# Conecta la señal 'body_entered' del nodo Area2D (Trigger) a esta función
func _on_trigger_body_entered(body):
	if body.is_in_group("player"):
		# Si hay una plataforma configurada como "siguiente", la hacemos aparecer
		if plataforma_siguiente != null:
			plataforma_siguiente.aparecer()
			
		# Si hay una plataforma configurada como "anterior", la hacemos desaparecer
		if plataforma_anterior != null:
			plataforma_anterior.desaparecer()

# Esta función reinicia este bloque y avisa al siguiente
func reiniciar():
	# Volvemos a nuestro estado original
	if activa_al_inicio:
		aparecer()
	else:
		desaparecer()
		
	# Efecto dominó: le decimos a la siguiente que también se reinicie
	if plataforma_siguiente != null:
		plataforma_siguiente.reiniciar()