# Aerial 25-3 SDK patch

Applied by `scripts/apply_overlay.sh` on top of the NVIDIA Aerial CUDA-Accelerated RAN 25-3 source tree (commit of the
upstream release: `Release 25-3`). Files:

```
 CMakeLists.txt                                     |   6 +
 cuPHY-CP/cuphycontroller/examples/CMakeLists.txt   |   4 +
 .../examples/cuphycontroller_scf.cpp               |  16 +
 cuPHY-CP/cuphydriver/include/context.hpp           |  23 +
 cuPHY-CP/cuphydriver/include/cuphydriver_api.hpp   |  17 +
 cuPHY-CP/cuphydriver/include/phypusch_aggr.hpp     |   5 +
 cuPHY-CP/cuphydriver/src/common/context.cpp        | 222 ++++++++-
 .../cuphydriver/src/common/cuphydriver_api.cpp     |  72 +++
 cuPHY-CP/cuphydriver/src/uplink/phyprach_aggr.cpp  |  31 +-
 cuPHY-CP/cuphydriver/src/uplink/phypusch_aggr.cpp  |   1 +
 .../src/uplink/task_function_ul_aggr.cpp           |  20 +-
 cuPHY-CP/cuphyl2adapter/lib/nvPHY/CMakeLists.txt   |   4 +
 .../lib/nvPHY/nv_phy_config_option.hpp             |  16 +-
 .../cuphyl2adapter/lib/nvPHY/nv_phy_module.cpp     | 249 ++++++++++
 cuPHY-CP/ru-emulator/ru_emulator/utils.hpp         |  43 +-
 .../scfl2adapter/lib/scf_5g_fapi/CMakeLists.txt    |   5 +
 .../lib/scf_5g_fapi/scf_5g_fapi_dapp_export.cpp    | 512 +++++++++++++++++++++
 .../lib/scf_5g_fapi/scf_5g_fapi_dapp_export.hpp    |  42 ++
 .../lib/scf_5g_fapi/scf_5g_fapi_phy.cpp            |  82 +++-
 .../lib/scf_5g_fapi/scf_5g_slot_commands.cpp       |   2 +-
 .../scf_5g_slot_commands_pdsch_csirs.cpp           |   2 +-
 .../scf_5g_fapi/scf_5g_slot_commands_ssb_pbch.cpp  |   6 +-
 cuPHY-CP/testMAC/testMAC/fapi_handler.cpp          |   8 +-
 cuPHY-CP/testMAC/testMAC/launch_pattern.cpp        |  12 +-
 cuPHY-CP/testMAC/testMAC/launch_pattern.hpp        |  29 ++
 testBenches/phase4_test_scripts/setup1_DU.sh       |   1 +
 .../phase4_test_scripts/valid_perf_patterns.sh     |   6 +-
 27 files changed, 1394 insertions(+), 42 deletions(-)
```
