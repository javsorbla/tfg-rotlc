import argparse
from pathlib import Path
from typing import Optional

import numpy as np
import gymnasium as gym
from gymnasium import spaces
from stable_baselines3 import PPO
from stable_baselines3.common.vec_env import DummyVecEnv


class DummyUmbraEnv(gym.Env):
    metadata = {}

    def __init__(self, nvec: np.ndarray):
        self.observation_space = spaces.Dict(
            {"obs": spaces.Box(low=-1.0, high=1.0, shape=(19,), dtype=np.float32)}
        )
        self.action_space = spaces.MultiDiscrete(nvec.astype(np.int64))

    def reset(self, seed=None, options=None):
        return {"obs": np.zeros((19,), dtype=np.float32)}, {}

    def step(self, action):
        return {"obs": np.zeros((19,), dtype=np.float32)}, 0.0, True, False, {}


def sample_obs(batch: int) -> np.ndarray:
    x = np.zeros((batch, 19), dtype=np.float32)
    x[:, 0] = np.random.uniform(-1, 1, size=batch)  # rel_x
    x[:, 1] = np.random.uniform(-0.8, 0.8, size=batch)  # rel_y

    # En el juego, estas dimensiones se anulan cuando `use_player_velocity_in_obs=false`
    # (ver `ai_controller_2d.gd`: `vel_scale := ... else 0.0`).
    x[:, 2] = 0.0  # player vx (neutralizado)
    x[:, 3] = 0.0  # player vy (neutralizado)
    x[:, 4] = np.random.choice([0.0, 1.0], size=batch, p=[0.2, 0.8])
    x[:, 5] = np.random.choice([0.0, 1.0], size=batch, p=[0.85, 0.15])
    x[:, 6] = np.random.choice([0.0, 1.0], size=batch, p=[0.9, 0.1])
    x[:, 7] = np.random.uniform(0.05, 1.0, size=batch)
    x[:, 8] = np.random.uniform(0.05, 1.0, size=batch)
    x[:, 9] = np.random.choice([0.0, 1.0], size=batch, p=[0.8, 0.2])
    x[:, 10] = np.random.uniform(0.1, 1.0, size=batch)
    x[:, 11] = np.random.uniform(0.0, 0.7, size=batch)
    x[:, 12] = np.random.uniform(0.0, 0.6, size=batch)
    x[:, 13] = np.random.uniform(0.0, 0.5, size=batch)
    x[:, 14] = 0.0  # preferred_side neutralized
    x[:, 15] = np.random.uniform(0.0, 0.7, size=batch)
    x[:, 16] = np.random.uniform(0.0, 0.8, size=batch)
    x[:, 17] = np.random.uniform(0.0, 0.4, size=batch)
    x[:, 18] = np.random.uniform(0.0, 0.5, size=batch)
    return x


def infer_move_head_index(nvec: np.ndarray, explicit_index: Optional[int]) -> int:
    if explicit_index is not None and explicit_index >= 0:
        return explicit_index
    candidates = np.where(nvec == 3)[0]
    if len(candidates) != 1:
        raise RuntimeError(
            f"Cannot infer move head index from nvec={nvec.tolist()} (size=3 appears {len(candidates)} times). "
            "Pass --move-head-index explicitly."
        )
    return int(candidates[0])


def evaluate_checkpoint(path: Path, move_head_index: Optional[int], batch_size: int, lr_deadzone: float) -> dict:
    # Load once without env to read action space shape.
    probe_model: PPO = PPO.load(str(path), device="cpu", print_system_info=False)
    nvec = np.array(probe_model.action_space.nvec, dtype=np.int64)
    move_idx = infer_move_head_index(nvec, move_head_index)

    env = DummyVecEnv([lambda: DummyUmbraEnv(nvec)])
    model: PPO = PPO.load(str(path), env=env, device="cpu", print_system_info=False)

    obs = {"obs": sample_obs(batch_size)}
    obs_t, _ = model.policy.obs_to_tensor(obs)
    move_dist = model.policy.get_distribution(obs_t).distribution[move_idx]
    probs = move_dist.probs.detach().cpu().numpy()  # [N, 3]
    picks = probs.argmax(axis=1)
    counts = [int((picks == i).sum()) for i in range(3)]
    frac = [c / float(batch_size) for c in counts]
    entropy = float((-(probs * np.log(np.clip(probs, 1e-8, 1.0))).sum(axis=1)).mean())

    grid = np.linspace(-1, 1, 41, dtype=np.float32)
    g = np.zeros((len(grid), 19), dtype=np.float32)
    g[:, 0] = grid
    g[:, 4] = 1.0
    g[:, 7] = 0.7
    g[:, 8] = 0.7
    gt, _ = model.policy.obs_to_tensor({"obs": g})
    gp = model.policy.get_distribution(gt).distribution[move_idx].probs.detach().cpu().numpy().argmax(axis=1)

    left_mask = grid < -lr_deadzone
    right_mask = grid > lr_deadzone
    center_mask = np.abs(grid) <= lr_deadzone

    left_ok = int((gp[left_mask] == 0).sum())
    right_ok = int((gp[right_mask] == 2).sum())
    center_idle = int((gp[center_mask] == 1).sum())
    left_wrong = int((gp[left_mask] == 2).sum())
    right_wrong = int((gp[right_mask] == 0).sum())

    return {
        "path": str(path),
        "nvec": nvec.tolist(),
        "move_head_index": move_idx,
        "move_frac": frac,
        "entropy": entropy,
        "left_ok": left_ok,
        "right_ok": right_ok,
        "center_idle": center_idle,
        "left_wrong": left_wrong,
        "right_wrong": right_wrong,
    }


def is_healthy(metrics: dict, max_dominant: float, min_lr_acc: float) -> bool:
    dominant = max(metrics["move_frac"])
    left_total = metrics["left_ok"] + metrics["left_wrong"]
    right_total = metrics["right_ok"] + metrics["right_wrong"]
    left_acc = metrics["left_ok"] / float(max(1, left_total))
    right_acc = metrics["right_ok"] / float(max(1, right_total))
    return dominant <= max_dominant and left_acc >= min_lr_acc and right_acc >= min_lr_acc


def export_onnx(model_path: str, onnx_path: str) -> None:
    from godot_rl.wrappers.onnx.stable_baselines_export import export_model_as_onnx

    model = PPO.load(model_path, device="cpu", print_system_info=False)
    export_model_as_onnx(model, str(Path(onnx_path).with_suffix(".onnx")))


def main() -> None:
    parser = argparse.ArgumentParser(allow_abbrev=False)
    parser.add_argument("--checkpoint_dir", type=str, required=True)
    parser.add_argument("--glob", type=str, default="*.zip")
    parser.add_argument("--move-head-index", type=int, default=-1)
    parser.add_argument("--batch-size", type=int, default=4000)
    parser.add_argument("--max-dominant", type=float, default=0.85)
    parser.add_argument("--min-lr-acc", type=float, default=0.55)
    parser.add_argument(
        "--lr-deadzone",
        type=float,
        default=0.07,
        help="Neutral rel_x zone in normalized coordinates for left/right accuracy (default aligns with ~35px over 500px).",
    )
    parser.add_argument("--export-onnx", type=str, default="")
    args = parser.parse_args()

    ckpt_dir = Path(args.checkpoint_dir)
    if not ckpt_dir.exists():
        raise FileNotFoundError(f"checkpoint_dir not found: {ckpt_dir}")

    ckpts = sorted(ckpt_dir.glob(args.glob))
    if not ckpts:
        print("No checkpoints found")
        return

    explicit_head = None if args.move_head_index < 0 else args.move_head_index
    lr_deadzone = max(0.0, min(0.49, float(args.lr_deadzone)))

    print(f"Scanning {len(ckpts)} checkpoints in {ckpt_dir}")
    healthy = []
    all_rows = []
    for ckpt in ckpts:
        row = evaluate_checkpoint(ckpt, explicit_head, args.batch_size, lr_deadzone)
        all_rows.append(row)
        dominant = max(row["move_frac"])
        left_total = row["left_ok"] + row["left_wrong"]
        right_total = row["right_ok"] + row["right_wrong"]
        left_acc = row["left_ok"] / float(max(1, left_total))
        right_acc = row["right_ok"] / float(max(1, right_total))
        ok = is_healthy(row, args.max_dominant, args.min_lr_acc)
        if ok:
            healthy.append(row)
        print(
            f"{ckpt.name} | nvec={row['nvec']} move_head={row['move_head_index']} "
            f"move_frac={[round(v, 3) for v in row['move_frac']]} ent={row['entropy']:.4f} "
            f"left_acc={left_acc:.3f} right_acc={right_acc:.3f} "
            f"status={'PASS' if ok else 'FAIL'}"
        )

    if not healthy:
        print("No healthy checkpoint found under current thresholds")
        return

    healthy.sort(key=lambda r: (max(r["move_frac"]), -(r["left_ok"] + r["right_ok"])))
    best = healthy[0]
    print(f"Selected checkpoint: {Path(best['path']).name}")

    if args.export_onnx:
        export_onnx(best["path"], args.export_onnx)
        print(f"Exported ONNX to {Path(args.export_onnx).with_suffix('.onnx')}")


if __name__ == "__main__":
    main()
