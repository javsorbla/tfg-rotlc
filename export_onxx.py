from stable_baselines3 import PPO
import torch

model = PPO.load("models/umbra_final")
model.policy.eval()

class PolicyWrapper(torch.nn.Module):
    def __init__(self, policy):
        super().__init__()
        self.policy = policy
    
    def forward(self, obs):
        with torch.no_grad():
            features = self.policy.extract_features({"obs": obs})
            latent_pi, _ = self.policy.mlp_extractor(features)
            action_logits = self.policy.action_net(latent_pi)
            return action_logits

wrapper = PolicyWrapper(model.policy)
wrapper.eval()

dummy = torch.zeros(1, 19).float()

with torch.no_grad():
    torch.onnx.export(
        wrapper,
        dummy,
        "models/umbra_final.onnx",
        opset_version=11,
        input_names=["obs"],
        output_names=["action_logits"],
        export_params=True,
        do_constant_folding=True,
        dynamo=False  # forzar API legacy
    )

print("Exportado correctamente")