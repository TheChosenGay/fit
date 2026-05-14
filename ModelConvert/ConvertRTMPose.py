#!/usr/bin/env python3
"""
RTMPose WholeBody → CoreML conversion.

Pipeline: Download ONNX → Fix Clip ops → ONNX→PyTorch → PyTorch→CoreML

Usage:
    cd ModelConvert
    source .venv/bin/activate   # Python 3.12
    pip install -r Requirements.txt
    python3 ConvertRTMPose.py

Output:
    ./Output/RTMPoseWholeBody.mlpackage

Model details:
    - RTMW-DW-L-M WholeBody (256×192 input, 133 keypoints)
    - SimCC output: simcc_x [1, 133, 384], simcc_y [1, 133, 512]
    - Decode: argmax(simcc_x) / 2 = x_pixel, argmax(simcc_y) / 2 = y_pixel
"""

import os
import sys
import zipfile
import requests
import numpy as np
from pathlib import Path
from tqdm import tqdm

POSE_ONNX_URL = (
    "https://download.openmmlab.com/mmpose/v1/projects/rtmw/onnx_sdk/"
    "rtmw-dw-l-m_simcc-cocktail14_270e-256x192_20231122.zip"
)
INPUT_HEIGHT = 256
INPUT_WIDTH = 192
NUM_KEYPOINTS = 133

OUTPUT_DIR = Path(__file__).parent / "Output"
CACHE_DIR = Path(__file__).parent / "Cache"


def download_onnx():
    CACHE_DIR.mkdir(exist_ok=True)
    zip_path = CACHE_DIR / "rtmw_wholebody.zip"

    if not zip_path.exists():
        print(f"[1/5] Downloading ONNX model...")
        resp = requests.get(POSE_ONNX_URL, stream=True)
        resp.raise_for_status()
        total = int(resp.headers.get("content-length", 0))
        with open(zip_path, "wb") as f, tqdm(total=total, unit="B", unit_scale=True) as bar:
            for chunk in resp.iter_content(8192):
                f.write(chunk)
                bar.update(len(chunk))
    else:
        print(f"[1/5] ONNX zip cached: {zip_path}")

    onnx_path = None
    with zipfile.ZipFile(zip_path) as zf:
        for name in zf.namelist():
            if name.endswith(".onnx"):
                zf.extract(name, CACHE_DIR)
                onnx_path = CACHE_DIR / name
                break

    if onnx_path is None:
        sys.exit("[!] No .onnx found in zip")

    size_mb = onnx_path.stat().st_size / 1e6
    print(f"      ONNX: {onnx_path} ({size_mb:.1f} MB)")
    return onnx_path


def fix_onnx_clip_ops(onnx_path):
    import onnx
    from onnx import helper, TensorProto
    from onnxsim import simplify

    print("[2/5] Simplifying + fixing ONNX graph...")
    model = onnx.load(str(onnx_path))
    model, _ = simplify(model)

    patched = 0
    for node in model.graph.node:
        if node.op_type == "Clip":
            new_inputs = list(node.input)
            changed = False
            for i in range(len(new_inputs)):
                if new_inputs[i] == "":
                    name = f"clip_const_{patched}_{i}"
                    val = 0.0 if i == 1 else float("inf")
                    tensor = helper.make_tensor(name, TensorProto.FLOAT, [], [val])
                    model.graph.initializer.append(tensor)
                    new_inputs[i] = name
                    changed = True
            if changed:
                del node.input[:]
                node.input.extend(new_inputs)
                patched += 1

    fixed_path = CACHE_DIR / "end2end_fixed.onnx"
    onnx.save(model, str(fixed_path))
    print(f"      Patched {patched} Clip ops → {fixed_path}")
    return fixed_path


def onnx_to_pytorch(fixed_onnx_path):
    import torch
    from onnx2torch import convert as onnx2torch_convert

    print("[3/5] ONNX → PyTorch...")
    model = onnx2torch_convert(str(fixed_onnx_path))
    model.eval()

    dummy = torch.randn(1, 3, INPUT_HEIGHT, INPUT_WIDTH)
    with torch.no_grad():
        outputs = model(dummy)

    if isinstance(outputs, (tuple, list)):
        for i, o in enumerate(outputs):
            print(f"      Output {i}: {o.shape}")
    else:
        print(f"      Output: {outputs.shape}")

    return model


def pytorch_to_coreml(torch_model):
    import torch
    import coremltools as ct

    print("[4/5] PyTorch → CoreML...")
    dummy = torch.randn(1, 3, INPUT_HEIGHT, INPUT_WIDTH)
    with torch.no_grad():
        traced = torch.jit.trace(torch_model, dummy)

    mlmodel = ct.convert(
        traced,
        inputs=[
            ct.ImageType(
                name="input",
                shape=(1, 3, INPUT_HEIGHT, INPUT_WIDTH),
                scale=1.0 / 255.0,
                color_layout=ct.colorlayout.RGB,
            )
        ],
        outputs=[
            ct.TensorType(name="simcc_x"),
            ct.TensorType(name="simcc_y"),
        ],
        minimum_deployment_target=ct.target.iOS17,
        compute_precision=ct.precision.FLOAT16,
    )

    mlmodel.author = "PostureAI (from mmpose RTMW)"
    mlmodel.short_description = (
        f"RTMW WholeBody {NUM_KEYPOINTS} keypoints, "
        f"SimCC output, input {INPUT_WIDTH}x{INPUT_HEIGHT}"
    )
    mlmodel.input_description["input"] = f"RGB image {INPUT_WIDTH}x{INPUT_HEIGHT}"

    OUTPUT_DIR.mkdir(exist_ok=True)
    coreml_path = OUTPUT_DIR / "RTMPoseWholeBody.mlpackage"
    mlmodel.save(str(coreml_path))

    size_mb = sum(f.stat().st_size for f in coreml_path.rglob("*") if f.is_file()) / 1e6
    print(f"      Saved: {coreml_path} ({size_mb:.1f} MB)")
    return coreml_path


def verify(coreml_path):
    import coremltools as ct
    from PIL import Image

    print("[5/5] Verifying...")
    loaded = ct.models.MLModel(str(coreml_path))
    spec = loaded.get_spec()

    print("      Inputs:")
    for inp in spec.description.input:
        print(f"        {inp.name}")
    print("      Outputs:")
    for out in spec.description.output:
        print(f"        {out.name}")

    img = Image.new("RGB", (INPUT_WIDTH, INPUT_HEIGHT), (128, 128, 128))
    result = loaded.predict({"input": img})
    for k, v in result.items():
        if hasattr(v, "shape"):
            print(f"        {k}: shape={v.shape}")

    print("\n[OK] CoreML model ready!")


def main():
    onnx_path = download_onnx()
    fixed_path = fix_onnx_clip_ops(onnx_path)
    torch_model = onnx_to_pytorch(fixed_path)
    coreml_path = pytorch_to_coreml(torch_model)
    verify(coreml_path)

    print(f"\n{'=' * 60}")
    print(f"Copy into Xcode project:")
    print(f"  cp -r {coreml_path} ../fit/Resources/Models/")
    print(f"{'=' * 60}")


if __name__ == "__main__":
    main()
