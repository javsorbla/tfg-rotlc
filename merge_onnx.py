import onnx
import os
import sys

base = sys.argv[1] if len(sys.argv) > 1 else "Juego"
model_path = os.path.join(base, "umbra.onnx")
data_path = os.path.join(base, "umbra.onnx.data")

model = onnx.load(model_path, load_external_data=True)
print(f"Model loaded successfully with external data")

onnx.save(model, model_path)
new_size = os.path.getsize(model_path)
print(f"Saved self-contained model. Size: {new_size} bytes")

model2 = onnx.load(model_path, load_external_data=False)
all_inline = True
for init in model2.graph.initializer:
    if init.data_location == onnx.TensorProto.EXTERNAL:
        print(f"ERROR: {init.name} still has external data!")
        all_inline = False
if all_inline:
    print("SUCCESS: Model is now self-contained")

if os.path.exists(data_path):
    os.remove(data_path)
    print(f"Removed {data_path} (no longer needed)")
