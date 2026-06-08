# Rise Of The Lost Colors

Videojuego 2D desarrollado en **Godot 4.3 (.NET)** como TFG. Incluye combate contra jefes con un sistema de poderes (cian, rojo, amarillo) y entrenamiento de IA mediante *Reinforcement Learning* (PPO + ONNX).

---

## Requisitos

| Herramienta | Versión mínima |
|-------------|----------------|
| Godot | 4.3 **.NET** (no la versión standard) |
| .NET SDK | 8.0 |
| Python | 3.10 |

Los plugins de Godot se instalan desde la **AssetLib** integrada en el editor:

| Plugin | Propósito |
|--------|-----------|
| `godot_rl_agents` | Comunicación Godot ↔ Python para RL |
| `com.heroiclabs.nakama` | Backend de leaderboards online |
| `maaacks_menus_template` | Plantilla de menús y UI |
| `GdUnit4` | Test runner |

---

## Arrancar el juego

1. Abrir `Juego/project.godot` con Godot 4.3 .NET
2. Pulsar **F5** (Ejecutar)
3. La escena principal es `res://ui/menus/main_menu/main_menu.tscn`

---

## Entorno Python

```powershell
# Crear entorno virtual (una vez)
python -m venv .venv

# Activar
.venv\Scripts\activate

# Instalar dependencias
pip install -r requirements.txt
```

---

## Entrenar a Umbra (RL)

El entrenamiento se hace **desde el editor de Godot** (la escena `EntrenamientoUmbra.tscn` debe estar abierta) mientras Python lanza `stable_baselines3_example.py`:

```powershell
.venv\Scripts\python.exe stable_baselines3_example.py `
  --experiment_name=umbra_v2_allpowers `
  --timesteps=800000 `
  --save_checkpoint_frequency=10000 `
  --save_model_path=logs/sb3/umbra_v2_allpowers `
  --learning_rate=1e-4 --ent_coef=0.08 `
  --n_steps=1024 --batch_size=256 --n_epochs=10 `
  --gamma=0.995 --gae_lambda=0.95 --target_kl=0.015
```

El modelo se guarda como `.zip` en `logs/sb3/` y los checkpoints en `logs/sb3/*_checkpoints/`.

### Exportar ONNX

```powershell
# Validar checkpoints y exportar el más sano
.venv\Scripts\python.exe umbra_checkpoint_gate.py `
  --checkpoint_dir=logs/sb3/umbra_v2_allpowers_checkpoints `
  --max-dominant=0.85 --min-lr-acc=0.55 --lr-deadzone=0.07 `
  --export-onnx=Juego/umbra.onnx

# O exportar un .zip concreto directamente
.venv\Scripts\python.exe stable_baselines3_example.py `
  --resume_model_path=logs/sb3/umbra_v2_allpowers_checkpoints/umbra_v2_allpowers_200000_steps.zip `
  --export_only --onnx_export_path=Juego/umbra.onnx
```

Después de exportar, situar `umbra.onnx` en `Juego/umbra.onnx` (Sync node → `onnx_model_path`).

---

## Estructura del proyecto

```
tfg-rotlc/
├── Juego/                        # Proyecto Godot
│   ├── enemies/bosses/umbra/     # Boss Umbra + entrenamiento
│   ├── player/                   # Scripts del jugador
│   ├── leaderboard/              # NakamaManager
│   ├── scripts/                  # GameState y utilidades
│   └── addons/                   # Plugins (godot_rl_agents, nakama, etc.)
├── stable_baselines3_example.py  # Lanzador de entrenamiento PPO
├── umbra_checkpoint_gate.py      # Validador de checkpoints + export ONNX
└── Documentacion/                # Docs adicionales
```

---

## Configuración Nakama

El servidor de leaderboards apunta a `64.226.80.31:7350` (DigitalOcean).

Para cambiarlo, editar `Juego/leaderboard/NakamaManager.gd` o crear `user://network_config.json`:

```json
{
  "scheme": "http",
  "host": "IP_DEL_SERVIDOR",
  "port": 7350
}
```

Durante el entrenamiento, Nakama solo hace autenticación (1 HTTP POST). **No escribe leaderboards** — `complete_run()` solo se llama desde el portal del juego, no desde la escena de entrenamiento.

---

## Tests

El proyecto usa **GdUnit4**. Los tests están en `res://test/`. Ejecutarlos desde el panel GdUnit4 del editor de Godot, al que se puede acceder seleccionandolo desde la parte superior izquierda (Al lado de panel de "Escena" y panel "Importar"). Para que aparezcan es necesario pulsar el botón `Run discover tests`. Al principio, por el funcionamiento del plugin, puede que esté deshabilitado, por lo que puede ser necesario pulsar antes el botón `Rerun unit tests` normal o el del modo debug.
