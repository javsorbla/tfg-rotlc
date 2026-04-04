# TFG - Rise Of The Lost Colors
TFG Desarrollo de un videojuego.

## Dependencias

### Godot RL Agents (plugin)
1. Plugin descargado desde AssetLib en Godot

### Python
1. Crear un entorno virtual: `python -m venv venv`
2. Activarlo: `venv\Scripts\activate`
3. Instalar dependencias: `pip install godot-rl stable-baselines3`

### Iniciar entrenamiento de Umbra
Provisionalmente, se usa el siguiente comando:
```
python -c "
from godot_rl.wrappers.stable_baselines_wrapper import StableBaselinesGodotEnv
from stable_baselines3 import PPO
env = StableBaselinesGodotEnv(env_path=None, show_window=True)
model = PPO('MultiInputPolicy', env, verbose=1)
model.learn(total_timesteps=100000)
model.save('umbra_model')
env.close()
"
```