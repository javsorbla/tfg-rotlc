from godot_rl.wrappers.stable_baselines_wrapper import StableBaselinesGodotEnv
from stable_baselines3 import PPO
from stable_baselines3.common.callbacks import CheckpointCallback

# Callback para guardar el modelo periódicamente
checkpoint_callback = CheckpointCallback(
    save_freq=10000,
    save_path="./models/",
    name_prefix="umbra_model"
)

env = StableBaselinesGodotEnv(env_path=None, show_window=True)
model = PPO("MultiInputPolicy", env, verbose=1, tensorboard_log="./logs/")

# Entrenar
model.learn(
    total_timesteps=10000, # 500000
    callback=checkpoint_callback
)

# Guardar modelo final en formato SB3
model.save("models/umbra_final")

# Exportar a ONNX
import torch
import onnx

obs = env.observation_space.sample()
torch.onnx.export(
    model.policy,
    torch.tensor(obs).unsqueeze(0).float(),
    "models/umbra_final.onnx",
    opset_version=11,
    input_names=["obs"],
    output_names=["actions"]
)

env.close()
print("Modelo exportado como umbra_final.onnx")