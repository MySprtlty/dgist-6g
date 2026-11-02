#!/bin/bash
# dgist-6g build (inside the Aerial container, root): apply the overlay to /opt/nvidia/cuBB and build the binaries the compose
# services run. First build of the SDK takes about an hour on a GH200; later builds are incremental.
#   docker compose --profile tools run --rm build            everything (cuphycontroller_scf, ru_emulator, test_mac, dApp tools)
#   docker compose --profile tools run --rm build l1          one target set: l1 | loopback | dapp
# Flags = the configuration the dApp was validated with: SCF_FAPI_10_04 OFF (the FAPI wire layout the OAI gNB sends),
# ENABLE_CONFORMANCE_TM_PDSCH_PDCCH OFF, SCF_FAPI_10_04_SRS ON, ENABLE_DAPP_HOOK ON, BUILD_DOCS OFF.
set -eu
SDK=/opt/nvidia/cuBB; D=/opt/dgist-6g; BUILD_DIR=${BUILD_DIR:-build.aarch64_dgist}
what=${1:-all}
bash $D/scripts/apply_overlay.sh $SDK
cd $SDK
if [ ! -f $BUILD_DIR/CMakeCache.txt ]; then
  echo "== configuring $BUILD_DIR"
  cmake -S $SDK -B $SDK/$BUILD_DIR -G Ninja -DCMAKE_BUILD_TYPE=Release -DSCF_FAPI_10_04=OFF -DENABLE_CONFORMANCE_TM_PDSCH_PDCCH=OFF -DSCF_FAPI_10_04_SRS=ON -DENABLE_DAPP_HOOK=ON -DBUILD_DOCS=OFF
fi
case "$what" in
  l1)       T="cuphycontroller_scf" ;;
  loopback) T="cuphycontroller_scf ru_emulator test_mac" ;;
  dapp)     T="dapp_tenant_main dapp_agent_test dapp_ring_selftest dapp_export_test" ;;
  *)        T="cuphycontroller_scf ru_emulator test_mac dapp_tenant_main dapp_agent_test dapp_ring_selftest dapp_export_test" ;;
esac
echo "== ninja -C $BUILD_DIR $T"
ninja -C $SDK/$BUILD_DIR $T
grep -E "^(ENABLE_DAPP_HOOK|SCF_FAPI_10_04|ENABLE_CONFORMANCE_TM_PDSCH_PDCCH|SCF_FAPI_10_04_SRS):" $SDK/$BUILD_DIR/CMakeCache.txt
ls -la $SDK/$BUILD_DIR/cuPHY-CP/cuphycontroller/examples/cuphycontroller_scf
echo "== build done"
