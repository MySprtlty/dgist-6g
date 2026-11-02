#!/bin/bash
# dgist-6g: host prerequisites before `docker compose up -d` (run on the GH200 host).
D=$(cd "$(dirname "$0")/.." && pwd); . <(grep -E '^(AERIAL_SDK_DIR|AERIAL_IMAGE|BUILD_DIR|MODE)=' "$D/.env" | sed 's/ *#.*//')
ok=1
chk() { if eval "$2" > /dev/null 2>&1; then echo "  ok   $1"; else echo "  FAIL $1"; ok=0; fi; }
echo "== dgist-6g host check ($(hostname))"
chk "docker compose v2" "docker compose version"
chk "NVIDIA GPU visible" "nvidia-smi -L"
chk "image $AERIAL_IMAGE present (or pull it)" "docker image inspect $AERIAL_IMAGE"
chk "SDK checkout $AERIAL_SDK_DIR" "test -d $AERIAL_SDK_DIR/cuPHY-CP/cuphydriver"
chk "overlay applied (.dgist-6g-overlay)" "test -f $AERIAL_SDK_DIR/.dgist-6g-overlay"
chk "L1 built ($BUILD_DIR/.../cuphycontroller_scf)" "test -x $AERIAL_SDK_DIR/${BUILD_DIR:-build.aarch64_dgist}/cuPHY-CP/cuphycontroller/examples/cuphycontroller_scf"
chk "hugepages mounted" "mount | grep -q hugepages"
chk "no other L1 / RU / MAC process" "! pgrep -x phy_main && ! pgrep -x ru_emulator && ! pgrep -x test_mac"
chk "no MPS server" "! pgrep -x nvidia-cuda-mps-server"
chk "no nv-cubb container of another stack" "! docker ps --format '{{.Names}}' | grep -qx nv-cubb"
chk "YOLO engines (models/full26x/seg00_sm80.engine)" "test -e $AERIAL_SDK_DIR/cuPHY-CP/dapp_hook/models/full26x/seg00_sm80.engine"
chk "4K sample images for the RA stand-in (models/img4k)" "ls $AERIAL_SDK_DIR/cuPHY-CP/dapp_hook/models/img4k/*.jpg"
[ "${MODE:-demo}" = demo ] && echo "  note demo mode: start Open5GS and the OAI gNB after the L1 is healthy (README)"
[ $ok = 1 ] && echo "== ready: docker compose up -d" || echo "== fix the FAIL lines first"
