import torch
import torch.nn as nn
from torchvision import models
from torch.utils.mobile_optimizer import optimize_for_mobile
import os

def export_model():
    print("Preparing to export model for mobile...")
    
    # 1. Initialize the MobileNet-V3 architecture
    num_classes = 10000
    model = models.mobilenet_v3_large()
    in_features = model.classifier[3].in_features
    model.classifier[3] = nn.Linear(in_features, num_classes)

    # 2. Load the trained weights
    weight_path = "best_plant_model.pth"
    if not os.path.exists(weight_path):
        print(f"ERROR: Could not find {weight_path}. Please place it in this directory.")
        return

    print("Loading weights...")
    model.load_state_dict(torch.load(weight_path, map_location=torch.device('cpu')))

    # 3. CRITICAL: Set to eval mode before tracing!
    # Without this, BatchNorm layers use single-image statistics instead of learned running statistics,
    # which completely scrambles the output and causes the model to predict the same class for every image.
    model.eval()

    # 4. Trace the model with a dummy input
    print("Tracing model...")
    example_input = torch.rand(1, 3, 224, 224)
    # MobileNetV3 traces better than it scripts
    traced_model = torch.jit.trace(model, example_input)

    # 5. Optimize for mobile
    print("Optimizing for mobile...")
    optimized_model = optimize_for_mobile(traced_model)

    # 6. Save the PyTorch Lite model
    output_path = "assets/best_plant_model.ptl"
    optimized_model._save_for_lite_interpreter(output_path)
    
    print(f"SUCCESS! Model exported to {output_path}")
    print("You can now rebuild your Flutter app.")

if __name__ == "__main__":
    export_model()
