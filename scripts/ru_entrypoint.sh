#!/bin/bash
# dgist-6g RU emulator service (loopback mode): the traffic generator of the O-RAN fronthaul, started after the L1 service has
# written the loopback configuration (run1_RU.sh reads test_config_summary.sh). Turn it on with: docker compose --profile loopback up -d
set -u
SDK=/opt/nvidia/cuBB; RUN=/run/dgist; P=$SDK/testBenches/phase4_test_scripts
BUILD_DIR=${BUILD_DIR:-build.aarch64_dgist}; SLOTS=${SLOTS:-2400000}
log() { echo "[dgist-ru $(date +%T)] $*"; }
rm -f $RUN/ru_started
for i in $(seq 1 300); do [ -f $RUN/config_done ] && break; sleep 2; done
[ -f $RUN/config_done ] || { log "the L1 service did not write the configuration (MODE=loopback?)"; exit 1; }
[ "${MODE:-demo}" = loopback ] || { log "MODE=$MODE: the RU emulator is only used in loopback mode"; exit 0; }
log "run1_RU.sh --build_dir=$BUILD_DIR (timeout $(( SLOTS / 2000 + 330 )) s)"
cd $P && ./run1_RU.sh --build_dir=$BUILD_DIR --timeout $(( SLOTS / 2000 + 330 )) > /tmp/ru_console.log 2>&1 & RU=$!
sleep 3; touch $RUN/ru_started
wait $RU; rc=$?; log "RU emulator exited ($rc)"
grep -E 'DL U (LATE|ON TIME|EARLY) PACKETS|DL C LATE SLOTS|DL U LATE SLOTS|Slots CRC' /tmp/ru.log 2>/dev/null | tail -20 > $RUN/ru_summary.txt; cp /tmp/ru_console.log $RUN/ 2>/dev/null
exit $rc
