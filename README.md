# Rise Of The Lost Colors

Videojuego 2D desarrollado en **Godot 4.3 (.NET)** como TFG. Incluye combate contra jefes con un sistema de poderes (cian, rojo, amarillo) y entrenamiento de IA mediante *Reinforcement Learning* (PPO + ONNX).

**IMPORTANTE**: Se puede acceder al ejecutable del juego en: https://uses0-my.sharepoint.com/:f:/g/personal/alereyper_alum_us_es/IgDvqXObAMpPQbC-zBIbt-gkAcTDHd32Jlxz_lBdl-ZQUUo?e=6jj9lB

Hay instrucciones del ejecutable en el archivo **Juego/builds/ejecutable.md**

Para instrucciones de compilación, mirar archivo **compila.txt**

---

## Requisitos

| Herramienta | Versión mínima |
|-------------|----------------|
| Godot | 4.3 **.NET** (no la versión standard) |
| .NET SDK | 8.0 |
| Python | 3.12 |

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

El entrenamiento se hace **desde el editor de Godot** (la escena `EntrenamientoUmbra.tscn` debe estar abierta) mientras Python lanza `stable_baselines3_example.py`. Es importante que no exista ningún modelo onnx en la carpeta Juego/:

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
./run_umbra_autogate.ps1 `
  -ExperimentName umbra_v2_allpowers `
  -TotalSteps 150000 `
  -BlockSteps 5000 `
  -LearningRate 1e-4 `
  -EntCoef 0.08 `
  -NSteps 1024 `
  -BatchSize 256 `
  -NEpochs 10 `
  -TargetKl 0.015 `
  -GateMaxDominant 0.85 `
  -GateMinLrAcc 0.55 `
  -GateLrDeadzone 0.07 `
  -CheckpointDir "logs/sb3/umbra_v2_allpowers_checkpoints" `
  -OnnxOut "Juego/umbra.onnx"

# O exportar un .zip concreto directamente
.venv\Scripts\python.exe stable_baselines3_example.py `
  --resume_model_path=logs/sb3/umbra_v2_allpowers_checkpoints/umbra_v2_allpowers_200000_steps.zip `
  --export_only --onnx_export_path=Juego/umbra.onnx
```

Después de exportar, situar `umbra.onnx` (y `umbra.onnx.data` si se genera) en `Juego/umbra.onnx` (Sync node → `onnx_model_path`).

### Hacer el ONNX autocontenido (antes de exportar)

El modelo ONNX se guarda con **datos externos** (`umbra.onnx.data`). Esto falla al exportar porque ONNX Runtime busca el `.data` en el sistema de archivos real, no dentro del `.pck`.

Para evitarlo, fusiona el `.data` dentro del `.onnx` con el script `merge_onnx.py`:

```powershell
.venv\Scripts\python.exe merge_onnx.py
```

Esto sobreescribe `Juego/umbra.onnx` como un solo archivo autocontenido y elimina `Juego/umbra.onnx.data`.

> **Ejecútalo cada vez que exportes un ONNX nuevo**, justo antes de exportar el juego.

---

## Estructura del proyecto

```
tfg-rotlc/
├── Juego/                        # Proyecto Godot
│   ├── assets/                   # Assets del juego (Sprite sheets, backgrounds...)
│   ├── music/                    # Archivos de audio del juego
│   ├── objects/                  # Elementos recolectables por el jugador
│   ├── player/                   # Lógica del jugador
│   ├── enemies/                  # Lógica de los enemigos
│   ├── leaderboard/              # Leaderboard con NakamaManager
│   ├── scripts/                  # GameState y utilidades
│   ├── addons/                   # Plugins (godot_rl_agents, nakama, etc.)
│   ├── scenes/                   # Escenas relacionadas con los niveles del juego
│   ├── ui/                       # Lógica de menús y HUD
│   └── test/                     # Tests funcionales
├── stable_baselines3_example.py  # Lanzador de entrenamiento PPO
├── umbra_checkpoint_gate.py      # Validador de checkpoints + export ONNX
└── Documentacion/                # Docs adicionales
```

---

## Configuración Nakama

El servidor de leaderboards apunta a un servidor levantado en Digital Ocean.

También se incluye la infraestructura del servidor, que se puede levantar en local con Docker. Para usarlo, es necesario editar la IP a la que se apunta por 127.0.0.1 (local)

Para cambiarla, editar `Juego/leaderboard/NakamaManager.gd` o crear `user://network_config.json`:

```json
{
  "scheme": "http",
  "host": "IP_DEL_SERVIDOR",
  "port": 7350
}
```

> **Importante**: Antes de levantar el contenedor, cambiar las contraseñas por defecto en:
> - `nakama-server/.env` → `POSTGRES_PASSWORD`
> - `nakama-server/data/local.yml` → `database.address`

---

## Tests

El proyecto usa **GdUnit4**. Los tests están en `res://test/`. Ejecutarlos desde el panel GdUnit4 del editor de Godot, al que se puede acceder seleccionandolo desde la parte superior izquierda (Al lado de panel de "Escena" y panel "Importar"). Para que aparezcan es necesario pulsar el botón `Run discover tests`. Al principio, por el funcionamiento del plugin, puede que esté deshabilitado, por lo que puede ser necesario pulsar antes el botón `Rerun unit tests` normal o el del modo debug.