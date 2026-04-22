# Guia de entrenamiento de Umbra

## Objetivo
Esta guia explica el flujo actual de entrenamiento de Umbra con `stable_baselines3_example.py`, cómo exportar el modelo ONNX y cómo usar ese modelo en el combate real.

## Flujo principal
1. Entrenar modelo con `stable_baselines3_example.py`.
2. Exportar ONNX al terminar el entrenamiento.
3. Configurar `Sync` + `AIController2D` en modo `ONNX_INFERENCE`.
4. Mantener heuristica solo como fallback (timeout/error).

Comando base (desde la raiz del repo):
- `python stable_baselines3_example.py --onnx_export_path=umbra.onnx`

## Comandos recomendados
Usar estos comandos como flujo por defecto para evitar colapso temprano de politica.

Precondicion recomendada (nuevo experimento desde cero):

```powershell
Remove-Item -Recurse -Force logs/sb3/umbra_realign_checkpoints -ErrorAction SilentlyContinue
Remove-Item -Force logs/sb3/umbra_realign.zip -ErrorAction SilentlyContinue
Remove-Item -Force Juego/umbra.onnx -ErrorAction SilentlyContinue
```

1. Entrenamiento principal (genera checkpoints y modelo .zip):

```powershell
.venv/Scripts/python.exe stable_baselines3_example.py --experiment_name=umbra_realign --timesteps=200000 --save_checkpoint_frequency=5000 --save_model_path=logs/sb3/umbra_realign --learning_rate=1e-4 --ent_coef=0.08 --n_steps=1024 --batch_size=256 --n_epochs=10 --gamma=0.995 --gae_lambda=0.95 --target_kl=0.015
```

2. Exportar ONNX desde un checkpoint concreto (sin entrenar):

```powershell
.venv/Scripts/python.exe stable_baselines3_example.py --resume_model_path=logs/sb3/umbra_realign_checkpoints/umbra_realign_20000_steps.zip --export_only --onnx_export_path=Juego/umbra.onnx
```

3. Inferencia rapida desde un .zip (opcional, para validacion en bucle RL):

```powershell
.venv/Scripts/python.exe stable_baselines3_example.py --resume_model_path=logs/sb3/umbra_realign.zip --inference --timesteps=20000
```

Nota: Ajusta el nombre de checkpoint en `--resume_model_path` al ultimo archivo realmente generado en `logs/sb3/umbra_realign_checkpoints/`.
Para Umbra se recomienda `--save_checkpoint_frequency=5000` para detectar colapso antes y descartar checkpoints malos sin perder tiempo.

4. Validar checkpoints y exportar solo uno sano (recomendado):

```powershell
.venv/Scripts/python.exe umbra_checkpoint_gate.py --checkpoint_dir=logs/sb3/umbra_realign_checkpoints --max-dominant=0.85 --min-lr-acc=0.55 --lr-deadzone=0.07 --export-onnx=Juego/umbra.onnx
```

Que valida este comando:
- Dominancia maxima de una clase de `move` (por defecto <= 0.85).
- Coherencia izquierda/derecha con barrido de `rel_x` (por defecto >= 55% por lado).
- Si encuentra uno valido, exporta ONNX automaticamente.

5. Flujo completo en una sola orden (entrena por bloques + gate + export):

```powershell
./run_umbra_autogate.ps1 -ExperimentName umbra_realign -TotalSteps 150000 -BlockSteps 5000 -LearningRate 1e-4 -EntCoef 0.08 -NSteps 1024 -BatchSize 256 -NEpochs 10 -TargetKl 0.015 -GateMaxDominant 0.85 -GateMinLrAcc 0.55 -GateLrDeadzone 0.07 -OnnxOut Juego/umbra.onnx
```

Notas:
- El script reanuda automaticamente desde el ultimo checkpoint del bloque anterior.
- Si Godot se cierra al terminar un bloque, el script se detiene de forma limpia y al volver a lanzarlo reanuda desde el ultimo checkpoint disponible.
- Tras cada bloque ejecuta `umbra_checkpoint_gate.py`.
- Si encuentra un checkpoint sano, exporta ONNX y termina.

Comando rapido para listar checkpoints disponibles:

```powershell
Get-ChildItem logs/sb3/umbra_realign_checkpoints/*.zip | Sort-Object LastWriteTime -Descending
```

Resultado esperado:
- Se genera `Juego/umbra.onnx`.
- Umbra puede inferir directamente desde ese modelo en la escena real.

Nota: Es necesario tener instalado Godot 4.3 en su versión .NET para no tener problemas

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
En el combate real se combinan dos capas:

1. Politica ONNX (prioritaria)
- `Sync` entrega acciones del modelo a `AIController2D`.
- Umbra ejecuta esas acciones en tiempo real.

2. Memoria persistente de `GameState` (ajuste fino)
- `difficulty_scale` y `player_metrics` siguen ajustando balance y sesgos.

Resultado:
- Umbra arranca usando modelo ONNX y conserva adaptacion persistente entre encuentros.

## Configuracion minima en escena real
Para que ONNX funcione en juego real:

1. Nodo `Sync` en la escena
- `script = res://addons/godot_rl_agents/sync.gd`
- `control_mode = ONNX_INFERENCE`
- `onnx_model_path = "res://umbra.onnx"`

2. Nodo `AIController2D` hijo de Umbra
- `control_mode = ONNX_INFERENCE`
- `onnx_model_path = "res://umbra.onnx"`

3. Archivo de modelo
- Debe existir en `Juego/umbra.onnx`.

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
- Modos `HUMAN`/`SMART_BOT` para sparring.
- Presets y auto-stop opcional.
- Resumen y reset rapido.
- Entrenamiento externo con `stable_baselines3_example.py` + export ONNX.
- Inferencia ONNX en el boss real con fallback heuristico por timeout/error.
