#!/bin/bash
# dgist-6g TensorRT engines (inside the Aerial container, root): one engine per (model, SM class) from the exported ONNX files,
# then the model sets the tenant loads (models/full26<m>/seg00_sm<class>.engine). An engine only performs well near the SM count
# it was built at, so each class is built under an MPS active-thread cap that grants exactly that many SMs (models/build_engines.sh);
# MPS is started for the builds only and stopped afterwards (the L1 runs without it).
#   docker compose --profile tools run --rm engines                     models yolo26n..yolo26x, classes 56 80 (the validated set)
#   MODELS="yolo26m_1280 yolo26l_1280" SMS="64 72 88 96" docker compose --profile tools run --rm engines   (finer ladder)
# Prerequisite: the ONNX exports in cuPHY-CP/dapp_hook/models (scripts/export_models.sh on the host).
set -eu
M=/opt/nvidia/cuBB/cuPHY-CP/dapp_hook/models
MODELS=${MODELS:-"yolo26n_1280 yolo26s_1280 yolo26m_1280 yolo26l_1280 yolo26x_1280"}; SMS=${SMS:-"56 80"}
for m in $MODELS; do [ -s $M/${m}_b8_e2e.onnx ] || { echo "missing $M/${m}_b8_e2e.onnx: run scripts/export_models.sh on the host first"; exit 1; }; done
export CUDA_MPS_PIPE_DIRECTORY=/var CUDA_MPS_LOG_DIRECTORY=/var
pgrep -x phy_main > /dev/null && { echo "the L1 is running; stop it before building engines (docker compose down)"; exit 1; }
echo quit | nvidia-cuda-mps-control 2>/dev/null || true; sleep 1
nvidia-cuda-mps-control -d; sleep 1; echo start_server -uid 0 | nvidia-cuda-mps-control; sleep 1
trap 'echo quit | nvidia-cuda-mps-control 2>/dev/null || true' EXIT
cd $M && MODELS="$MODELS" BATCHES=8 ONNX_SUFFIX=_e2e SMS="$SMS" bash build_engines.sh
echo quit | nvidia-cuda-mps-control 2>/dev/null || true; sleep 1
for m in n s m l x; do
  mkdir -p $M/full26$m
  for c in 24 32 40 48 56 64 72 80 88 96 104 112 120 128; do f=yolo26${m}_1280_b8_e2e_fp16_sm${c}.engine; [ -s $M/$f ] && [ ! -e $M/full26$m/seg00_sm$c.engine ] && ln -s ../$f $M/full26$m/seg00_sm$c.engine; done
  echo "  26$m: $(ls $M/full26$m/ 2>/dev/null | sed 's/seg00_sm//; s/.engine//' | sort -n | tr '\n' ' ')"
done
echo "== engines done"
