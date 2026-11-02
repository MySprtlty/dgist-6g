#!/bin/bash
# dgist-6g testMAC service (loopback mode): the L2/MAC stand-in that drives the L1 with the ddddddsuuu traffic pattern over nvIPC.
# Starts when the L1 and the dApp tenant are ready. Turn it on with: docker compose --profile loopback up -d
set -u
SDK=/opt/nvidia/cuBB; RUN=/run/dgist; P=$SDK/testBenches/phase4_test_scripts
BUILD_DIR=${BUILD_DIR:-build.aarch64_dgist}; SLOTS=${SLOTS:-2400000}
log() { echo "[dgist-testmac $(date +%T)] $*"; }
[ "${MODE:-demo}" = loopback ] || { log "MODE=$MODE: testMAC is only used in loopback mode"; exit 0; }
for i in $(seq 1 400); do [ -f $RUN/tenant_ready ] && break; [ -f $RUN/l1_exit ] && { log "the L1 exited before the tenant was ready"; exit 1; }; sleep 2; done
[ -f $RUN/tenant_ready ] || { log "L1 / tenant not ready"; exit 1; }
log "run3_testMAC.sh --build_dir=$BUILD_DIR ($SLOTS slots)"
cd $P && ./run3_testMAC.sh --build_dir=$BUILD_DIR --timeout $(( SLOTS / 2000 + 300 )) > /tmp/testmac_console.log 2>&1; rc=$?
grep -m1 "Finished running" /tmp/testmac.log /tmp/testmac_console.log 2>/dev/null | head -1
grep -E 'Slots CRC|CRC Error|UCI' /tmp/testmac.log 2>/dev/null | tail -12 > $RUN/testmac_summary.txt; cp /tmp/testmac_console.log $RUN/ 2>/dev/null
log "testMAC exited ($rc)"; exit $rc
