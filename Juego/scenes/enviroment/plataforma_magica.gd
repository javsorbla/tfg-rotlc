extends StaticBody2D

# Al exportar estas variables, podremos arrastrar otras plataformas desde el Inspector
@export var plataforma_siguiente: StaticBody2D
@export var plataforma_anterior: StaticBody2D
@export var activa_al_inicio: bool = false

func _ready():
	# Cuando arranca el nivel, decidimos si este bloque se ve o es invisible
	if activa_al_inicio:
		aparecer()
	else:
		desaparecer()

func aparecer():
	show() # Lo hace visible
	process_mode = Node.PROCESS_MODE_INHERIT # Activa las colisiones

func desaparecer():
	hide() # Lo hace invisible
	process_mode = Node.PROCESS_MODE_DISABLED # Desactiva las colisiones para que caigas

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