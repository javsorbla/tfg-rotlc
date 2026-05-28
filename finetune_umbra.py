import json
import os
import sys

import torch
from stable_baselines3 import PPO


def _safe_load_metrics(metrics_path: str) -> dict:
    if not os.path.exists(metrics_path):
        return {}
    with open(metrics_path, "r", encoding="utf-8") as f:
        data = json.load(f)
    if isinstance(data, dict):
        return data
    return {}


class PolicyWrapper(torch.nn.Module):
    def __init__(self, policy):
        super().__init__()
        self.policy = policy

    def forward(self, obs):
        with torch.no_grad():
            features = self.policy.extract_features({"obs": obs})
            latent_pi, _ = self.policy.mlp_extractor(features)
            return self.policy.action_net(latent_pi)


def export_onnx(model: PPO, output_onnx: str, obs_dim: int = 19) -> None:
    os.makedirs(os.path.dirname(output_onnx), exist_ok=True)

    wrapper = PolicyWrapper(model.policy)
    wrapper.eval()
    dummy = torch.zeros(1, obs_dim).float()

    with torch.no_grad():
        torch.onnx.export(
            wrapper,
            dummy,
            output_onnx,
            opset_version=18,
            input_names=["obs"],
            output_names=["output"],
            export_params=True,
            do_constant_folding=True,
            dynamo=False,
        )


def finetune(
    metrics_path: str,
    model_zip_path: str,
    output_onnx: str,
    timesteps: int = 2000,
    env_path: str = "",
) -> int:
    metrics = _safe_load_metrics(metrics_path)
    print(f"[finetune_umbra] Metrics loaded: {metrics}")

    if not os.path.exists(model_zip_path):
        print(f"[finetune_umbra] Base model not found: {model_zip_path}")
        return 2

    model = PPO.load(model_zip_path)

    # Full PPO fine-tuning requires a runnable Godot env (headless export path).
    # If env is unavailable, we still export current policy to keep pipeline stable.
    env_available = bool(env_path) and os.path.exists(env_path)
    if env_available:
        from godot_rl.wrappers.stable_baselines_wrapper import StableBaselinesGodotEnv

        print(f"[finetune_umbra] Using headless env: {env_path}")
        env = StableBaselinesGodotEnv(env_path=env_path, show_window=False, speedup=8)
        model.set_env(env)
        model.learn(total_timesteps=timesteps, reset_num_timesteps=False)
        model.save(model_zip_path)
        env.close()
    else:
        print("[finetune_umbra] Headless env unavailable; exporting current policy without PPO updates")

    temp_onnx = output_onnx + ".tmp"
    export_onnx(model, temp_onnx)

    if os.path.exists(output_onnx):
        os.remove(output_onnx)
    os.replace(temp_onnx, output_onnx)

    print(f"[finetune_umbra] ONNX ready: {output_onnx}")
    return 0


if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Usage: finetune_umbra.py <metrics_json> <model_zip> <output_onnx> [timesteps] [env_path]")
        sys.exit(1)

    metrics_path_arg = sys.argv[1]
    model_path_arg = sys.argv[2]
    onnx_path_arg = sys.argv[3]
    timesteps_arg = int(sys.argv[4]) if len(sys.argv) > 4 else 2000
    env_path_arg = sys.argv[5] if len(sys.argv) > 5 else ""

    exit_code = finetune(metrics_path_arg, model_path_arg, onnx_path_arg, timesteps_arg, env_path_arg)
    sys.exit(exit_code)
