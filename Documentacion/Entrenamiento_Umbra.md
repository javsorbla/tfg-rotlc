# Guia de entrenamiento de Umbra

## Objetivo
Esta guia explica como entrenar a Umbra desde Godot, como guardar lo aprendido para usarlo en el primer enfrentamiento real, y como resetear el progreso si la dificultad se dispara.

## Que se guarda y donde
Hay dos niveles de persistencia:

1. Progreso agregado de aprendizaje (el que usa el juego real)
- Archivo: `user://umbra_progress.json`
- Se guarda con `GameState`.
- Incluye:
  - `encounters`, `wins`, `losses`
  - `difficulty_scale`
  - `player_metrics` (distancia media, frecuencia de dash/ataque/salto, lado preferido)
  - `latest_model_path`

2. Log detallado por episodios de entrenamiento
- Archivo: `user://umbra_training_episodes.jsonl`
- Guarda una linea JSON por episodio con:
  - ganador del episodio
  - duracion
  - modo del dummy (`human` o `smart_bot`)
  - vida final de Umbra y del jugador dummy

Nota importante: lo que impacta directamente al primer enfrentamiento es el progreso agregado (`umbra_progress.json`).

## Escena de entrenamiento
Escena principal:
- `Juego/enemies/bosses/umbra/EntrenamientoUmbra.tscn`

Script de control:
- `Juego/enemies/bosses/umbra/entrenamiento_umbra.gd`

El flujo es por episodios:
1. Se inicia combate Umbra vs Dummy.
2. El episodio termina cuando muere Umbra o muere el Dummy.
3. Se guarda episodio y se resetea automaticamente.
4. Repite en bucle.

## Modos de control del dummy
El dummy soporta dos modos:

1. `SMART_BOT`
- IA de sparring no trivial (strafe, dash, salto situacional, ataque con cooldown).
- Implementado en `Juego/enemies/bosses/umbra/player_dummy.gd`.

2. `HUMAN`
- Tu controlas el dummy como jugador real para "ensenar" a Umbra.

Cambio rapido en runtime:
- `Enter` alterna `HUMAN <-> SMART_BOT`.

## Presets de entrenamiento
Configurable en el inspector del nodo de entrenamiento (`entrenamiento_umbra.gd`).

Enum disponible:
- `MANUAL`
- `QUICK`
- `SERIOUS`
- `BALANCED_RELEASE`

Campos relevantes:
- `preset_enabled`
- `training_preset`
- `auto_switch_mode_with_preset`
- `auto_stop_on_target`
- `min_episodes_before_stop`
- `target_win_rate_low`
- `target_win_rate_high`

Comportamiento:
1. `MANUAL`
- Sin automatismos (control manual completo).

2. `QUICK`
- Mezcla con mas peso de `SMART_BOT`.
- Pensado para sesiones cortas.

3. `SERIOUS`
- Mezcla mas equilibrada entre `HUMAN` y `SMART_BOT`.

4. `BALANCED_RELEASE`
- Mezcla orientada a balance final.
- Puede detener el bucle automaticamente al entrar en rango objetivo de win rate.

## Atajos durante entrenamiento
En `EntrenamientoUmbra.tscn`:

- `Enter`: alterna modo dummy (`HUMAN`/`SMART_BOT`).
- `F10`: imprime resumen de aprendizaje actual.
- `F9`: reset total del aprendizaje (progreso + log).

## Resumen y reset de aprendizaje
Funciones expuestas en `GameState`:

- `get_umbra_learning_summary()`
  - Devuelve episodios, wins/losses, win rate y dificultad.

- `reset_umbra_learning(clear_training_log := true, clear_latest_model := true)`
  - Resetea progreso agregado.
  - Opcionalmente limpia log de entrenamiento.
  - Opcionalmente limpia ruta de modelo.

Uso rapido recomendado:
- Si Umbra esta demasiado fuerte: `F9` y reinicias una sesion de ajuste.
- Para auditar progreso: `F10` periodicamente.

## Como impacta en el primer enfrentamiento real
Primer encuentro (tutorial):
- `Juego/scenes/tutorial.gd` instancia Umbra.
- Umbra lee progreso persistido via `GameState` al activarse.
- Se aplica dificultad persistida (`difficulty_scale`) y metricas agregadas del jugador.

Resultado:
- El Umbra del juego real arranca con memoria del entrenamiento acumulado.

## Flujo recomendado de uso
### Opcion A: ajuste rapido
1. Preset `QUICK`.
2. 15-30 minutos de episodios.
3. Revisa `F10`.
4. Prueba primer enfrentamiento.
5. Si esta duro, `F9` y repites con menos tiempo.

### Opcion B: entrenamiento serio
1. Preset `SERIOUS`.
2. Alterna bloques con `HUMAN` para corregir sesgos.
3. Revisa win rate y dificultad con `F10`.
4. Valida en combate real.

### Opcion C: balance de release
1. Preset `BALANCED_RELEASE`.
2. Activa `auto_stop_on_target`.
3. Define rango objetivo de win rate.
4. Cuando pare automaticamente, valida en escena real.

## Problemas comunes
1. "No noto cambios en combate real"
- Comprueba que entrenaste en la escena correcta.
- Revisa resumen con `F10` y confirma que subieron `encounters`.

2. "Se volvio imposible"
- Haz `F9` para reset total.
- Reentrena con mas peso de `HUMAN` y menos episodios.

3. "Quiero conservar log pero resetear dificultad"
- Llama a `reset_umbra_learning(false, true)` desde codigo (no desde atajo).

## Estado actual del sistema
Implementado:
- Aprendizaje incremental persistente usable en juego real.
- Registro por episodios.
- Modos `HUMAN`/`SMART_BOT`.
- Presets y auto-stop opcional.
- Resumen y reset rapido.

No implementado aun (siguiente fase opcional):
- Cargar un modelo RL ONNX entrenado externamente para inferencia directa en el boss real.
