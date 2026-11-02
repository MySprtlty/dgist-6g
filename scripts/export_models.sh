#!/bin/bash
# dgist-6g: export the YOLO26 detectors to ONNX on the host (the Aerial image has no PyTorch). Needs a Python venv with
# ultralytics (CPU torch is enough). Output next to the weights: cuPHY-CP/dapp_hook/models/yolo26<m>_1280_b8_e2e.onnx
#   scripts/export_models.sh [venv_dir]          (default ~/.venvs/dapp_yolo; created with pip if missing)
set -eu
D=$(cd "$(dirname "$0")/.." && pwd)
SDK=$(grep -E '^AERIAL_SDK_DIR=' "$D/.env" | head -1 | cut -d= -f2 | awk '{print $1}')
M=$SDK/cuPHY-CP/dapp_hook/models
VENV=${1:-$HOME/.venvs/dapp_yolo}
[ -x $VENV/bin/python ] || { python3 -m venv $VENV && $VENV/bin/pip install -q --upgrade pip && $VENV/bin/pip install -q ultralytics onnx onnxruntime pillow numpy; }
cd $M
# the weights (yolo26n.pt .. yolo26x.pt) are downloaded by ultralytics on first use
$VENV/bin/python export_1280.py --models yolo26n yolo26s yolo26m yolo26l yolo26x --imgsz 1280 --batches 8 --nms-free --max-det 300
ls -la $M/yolo26*_1280_b8_e2e.onnx
echo "== now build the engines: docker compose --profile tools run --rm engines"
