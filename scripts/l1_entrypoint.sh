#!/bin/bash
# dgist-6g L1 entrypoint (inside the Aerial container, root): cuphycontroller_scf with CUDA green contexts, the in-process YOLO
# dApp tenant and the xApp agent. No MPS. MODE=demo (real RU/OAI/core outside) or MODE=loopback (RU emulator + testMAC services).
set -u
SDK=/opt/nvidia/cuBB; D=/opt/dgist-6g; RUN=/run/dgist; P=$SDK/testBenches/phase4_test_scripts
BUILD_DIR=${BUILD_DIR:-build.aarch64_dgist}; MODE=${MODE:-demo}; L1_CONFIG=${L1_CONFIG:-dgist}
NCELLS=${NCELLS:-1}; PATTERN_MODE=${PATTERN_MODE:-average}; SLOTS=${SLOTS:-2400000}
log() { echo "[dgist-l1 $(date +%T)] $*"; }
mkdir -p $RUN $SDK/prof; rm -f $RUN/l1_ready $RUN/tenant_ready $RUN/config_done $RUN/l1_exit
BIN=$SDK/$BUILD_DIR/cuPHY-CP/cuphycontroller/examples/cuphycontroller_scf
[ -x $BIN ] || { log "missing $BIN - run: docker compose --profile tools run --rm build"; sleep 10; exit 1; }
grep -q "^ENABLE_DAPP_HOOK:BOOL=ON" $SDK/$BUILD_DIR/CMakeCache.txt 2>/dev/null || log "warning: $BUILD_DIR was not configured with ENABLE_DAPP_HOOK=ON"

# 1. no MPS: green contexts partition the GPU; the researchers' entrypoint started MPS, the dApp needs it off
export CUDA_MPS_PIPE_DIRECTORY=/var CUDA_MPS_LOG_DIRECTORY=/var
echo quit | nvidia-cuda-mps-control 2>/dev/null || true; sleep 1
pgrep -x nvidia-cuda-mps-server > /dev/null && { log "an MPS server is still running - stop it (echo quit | nvidia-cuda-mps-control)"; exit 1; }

# 2. dApp environment (defaults = the validated 1-cell configuration; .env overrides)
export DAPP_PUSCH_PROFILES=${DAPP_PUSCH_PROFILES:-16,24,32,40,56} DAPP_PDSCH_PROFILES=${DAPP_PDSCH_PROFILES:-24,40}
export DAPP_SIZER_MODEL=${DAPP_SIZER_MODEL:-$SDK/cuPHY-CP/dapp_hook/estimator/sm_model.txt}
export DAPP_TENANT=1 DAPP_AGENT=1 DAPP_AGENT_CELLS=$NCELLS
export DAPP_TENANT_CLASSES=${DAPP_TENANT_CLASSES:-40,48,56,64,72,80,88,96,104,112,120} DAPP_TENANT_FB_GUARD=${DAPP_TENANT_FB_GUARD:-0} DAPP_TENANT_LAYOUT=${DAPP_TENANT_LAYOUT:-union}
export DAPP_TENANT_CPU=${DAPP_TENANT_CPU:-45} DAPP_AGENT_CPU=${DAPP_AGENT_CPU:-46} DAPP_AGENT_PORT=${DAPP_AGENT_PORT:-9810}
export DAPP_AGENT_GRAPH_CHUNK=${DAPP_AGENT_GRAPH_CHUNK:-3} DAPP_AGENT_CHUNK_AHEAD=${DAPP_AGENT_CHUNK_AHEAD:-2} DAPP_AGENT_QOS=${DAPP_AGENT_QOS:-1}
export DAPP_TENANT_LOG=/tmp/dapp_tenant.log DAPP_TENANT_CSV=/tmp/dapp_tenant_slots.csv
[ -n "${DAPP_AGENT_UDP:-}" ] && export DAPP_AGENT_UDP || unset DAPP_AGENT_UDP
export AERIAL_LOG_PATH=/var/log/aerial
rm -f /tmp/phy.log /tmp/dapp_tenant.log /tmp/dapp_tenant_slots.csv

CFG=$SDK/cuPHY-CP/cuphycontroller/config
case "$MODE" in
demo)
  cp $D/configs/demo/cuphycontroller_${L1_CONFIG}.yaml $CFG/ && cp $D/configs/demo/l2_adapter_${L1_CONFIG}.yaml $CFG/ || { log "no configs/demo/*_${L1_CONFIG}.yaml"; exit 1; }
  touch $RUN/config_done
  log "demo: cuphycontroller_scf $L1_CONFIG (green contexts, no MPS, dApp tenant + agent on TCP $DAPP_AGENT_PORT)"
  ( cd $SDK && exec $BIN $L1_CONFIG ) > /tmp/phy_console.log 2>&1 & L1=$!
  ;;
loopback)
  # lab files of the loopback mode (configs/loopback) replace the SDK's copies for the run; restored on exit
  B=$RUN/lab_backup; mkdir -p $B
  for f in cuPHY-CP/cuphycontroller/config/cuphycontroller_F08_CG1.yaml cuPHY-CP/cuphycontroller/config/l2_adapter_config_F08_CG1.yaml cuPHY-CP/ru-emulator/config/config.yaml cuPHY-CP/testMAC/testMAC/test_mac_config.yaml cuPHY/nvlog/config/nvlog_config.yaml; do
    [ -f $B/$(basename $f).orig ] || cp $SDK/$f $B/$(basename $f).orig
  done
  cp $D/configs/loopback/cuphycontroller_F08_CG1.yaml $CFG/; cp $D/configs/loopback/l2_adapter_config_F08_CG1.yaml $CFG/
  cp $D/configs/loopback/ru_emulator_config.yaml $SDK/cuPHY-CP/ru-emulator/config/config.yaml
  cp $D/configs/loopback/test_mac_config.yaml $SDK/cuPHY-CP/testMAC/testMAC/test_mac_config.yaml
  cp $D/configs/loopback/nvlog_config.yaml $SDK/cuPHY/nvlog/config/nvlog_config.yaml
  mkdir -p $SDK/testVectors/multi-cell; cp $D/configs/loopback/testVectors/multi-cell/*.yaml $SDK/testVectors/multi-cell/
  cd $P
  ./setup1_DU.sh --ru-host-type=_LOOPBACK --du-eth0=${DU_ETH0:-aerial02} -y F08_CG1 > $RUN/setup1.log 2>&1 || { log "setup1_DU.sh failed ($RUN/setup1.log)"; exit 1; }
  ./setup2_RU.sh --ru-eth0=${RU_ETH0:-aerial03} > $RUN/setup2.log 2>&1 || { log "setup2_RU.sh failed ($RUN/setup2.log)"; exit 1; }
  ./test_config.sh ddddddsuuu_$PATTERN_MODE --num-cells=$NCELLS --num-slots=$SLOTS --green-ctx=1 > $RUN/test_config.log 2>&1
  grep -q "total $NCELLS cells" $RUN/test_config.log || { log "test_config.sh failed ($RUN/test_config.log)"; exit 1; }
  [ "$NCELLS" = 1 ] && sed -i "s/^  mps_sm_ul_order: .*/  mps_sm_ul_order: 8/" $CFG/cuphycontroller_F08_CG1.yaml
  sed -i 's/^dapp_hook: {.*}/dapp_hook: {enable: 1, shm_name: \/aerial_dapp_ring, ring_len: 65536, mlock: 1, export_ul: 1, export_dl: 1, export_pdus: 1, async_export: 1, export_cpu: 43}/' $CFG/l2_adapter_config_F08_CG1.yaml
  touch $RUN/config_done
  for i in $(seq 1 60); do [ -f $RUN/ru_started ] && break; sleep 2; done   # the RU emulator service starts first when the loopback profile is up
  log "loopback: $NCELLS cell(s), ddddddsuuu_$PATTERN_MODE, $SLOTS slots; run2_cuPHYcontroller.sh --build_dir=$BUILD_DIR"
  ( cd $P && exec ./run2_cuPHYcontroller.sh --build_dir=$BUILD_DIR --timeout $(( SLOTS / 2000 + 300 )) ) > /tmp/phy_console.log 2>&1 & L1=$!
  ;;
*) log "MODE must be demo or loopback"; exit 1 ;;
esac

# 3. readiness markers for the other services and for docker's healthcheck
for i in $(seq 1 150); do grep -q "L1 is ready" /tmp/phy.log /tmp/phy_console.log 2>/dev/null && break; kill -0 $L1 2>/dev/null || break; sleep 2; done
if grep -q "L1 is ready" /tmp/phy.log /tmp/phy_console.log 2>/dev/null; then touch $RUN/l1_ready; log "L1 is ready"; else log "L1 did not come up (see /tmp/phy_console.log, /tmp/phy.log)"; fi
for i in $(seq 1 180); do (echo > /dev/tcp/127.0.0.1/$DAPP_AGENT_PORT) 2>/dev/null && break; grep -q "tenant NOT started\|FATAL exit" /tmp/phy_console.log /tmp/phy.log 2>/dev/null && break; kill -0 $L1 2>/dev/null || break; sleep 2; done
if (echo > /dev/tcp/127.0.0.1/$DAPP_AGENT_PORT) 2>/dev/null; then touch $RUN/tenant_ready; log "dApp tenant ready: xApp agent on TCP $DAPP_AGENT_PORT"; grep -E "union layout|-> class|CUDA graphs captured" /tmp/dapp_tenant.log | head -20; else log "tenant did not start: $(grep -E 'tenant NOT started' /tmp/phy_console.log /tmp/phy.log | tail -1)"; fi
wait $L1; rc=$?; echo $rc > $RUN/l1_exit; log "L1 exited ($rc)"
cp /tmp/dapp_tenant.log /tmp/dapp_tenant_slots.csv /tmp/phy_console.log $RUN/ 2>/dev/null; tail -n 200000 /tmp/phy.log > $RUN/phy_tail.log 2>/dev/null
if [ "$MODE" = loopback ]; then
  B=$RUN/lab_backup
  cp $B/cuphycontroller_F08_CG1.yaml.orig $CFG/cuphycontroller_F08_CG1.yaml; cp $B/l2_adapter_config_F08_CG1.yaml.orig $CFG/l2_adapter_config_F08_CG1.yaml
  cp $B/config.yaml.orig $SDK/cuPHY-CP/ru-emulator/config/config.yaml; cp $B/test_mac_config.yaml.orig $SDK/cuPHY-CP/testMAC/testMAC/test_mac_config.yaml; cp $B/nvlog_config.yaml.orig $SDK/cuPHY/nvlog/config/nvlog_config.yaml
  log "lab files restored"
fi
exit $rc
