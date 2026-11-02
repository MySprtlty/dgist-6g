# dgist-6g dApp inside the Aerial L1 process
#
#   dapp_hook          header-only: FAPI hook ring (include/dapp_hook/dapp_ring*.h*), async export, per-slot sizer
#   dapp_tenant        static library linked into cuphycontroller_scf: YOLO tenant thread (TensorRT engines on CUDA green
#                      contexts, per-request SM partition, chunked graph launches) + xApp agent (TCP 9810, JSON lines)
#   dapp_tenant_main   stand-alone tenant (no L1, DAPP_TENANT_FREERUN=1) for request-path and layout self-checks
#   dapp_agent_test    host-only exerciser of the xApp protocol (no CUDA)
#   dapp_ring_*        ring verification tools; dapp_export_test = hook export unit test

add_library(dapp_hook INTERFACE)
target_include_directories(dapp_hook INTERFACE
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>)
target_compile_features(dapp_hook INTERFACE cxx_std_17)
if(ENABLE_DAPP_HOOK)
    target_compile_definitions(dapp_hook INTERFACE ENABLE_DAPP_HOOK)
endif()

find_library(DAPP_LIBRT rt)
if(DAPP_LIBRT)
    target_link_libraries(dapp_hook INTERFACE ${DAPP_LIBRT})
endif()

add_executable(dapp_ring_dump tools/dapp_ring_dump.cpp)
target_link_libraries(dapp_ring_dump PRIVATE dapp_hook)
set_target_properties(dapp_ring_dump PROPERTIES CXX_STANDARD 17 CXX_STANDARD_REQUIRED ON)

add_executable(dapp_ring_fakel1 tools/dapp_ring_fakel1.cpp)
target_link_libraries(dapp_ring_fakel1 PRIVATE dapp_hook)
set_target_properties(dapp_ring_fakel1 PROPERTIES CXX_STANDARD 17 CXX_STANDARD_REQUIRED ON)

add_executable(dapp_ring_selftest tools/dapp_ring_selftest.cpp)
target_link_libraries(dapp_ring_selftest PRIVATE dapp_hook pthread)
set_target_properties(dapp_ring_selftest PROPERTIES CXX_STANDARD 17 CXX_STANDARD_REQUIRED ON)

# dapp_tenant: the YOLO tenant thread linked into cuphycontroller_scf (tenant/dapp_tenant.hpp). Built when TensorRT is
# available; cuphycontroller links it only when the target exists (DAPP_TENANT_AVAILABLE).
set(DAPP_TENANT_AVAILABLE OFF CACHE INTERNAL "dapp_tenant target exists")
if(ENABLE_DAPP_HOOK AND TARGET CUDA::cuda_driver AND TARGET CUDA::cudart)
    find_library(DAPP_NVINFER_LIB nvinfer)
    find_path(DAPP_NVINFER_INC NvInfer.h PATH_SUFFIXES aarch64-linux-gnu x86_64-linux-gnu)
    if(DAPP_NVINFER_LIB AND DAPP_NVINFER_INC)
        add_library(dapp_tenant STATIC tenant/dapp_tenant.cu tenant/dapp_agent.cpp e2e/nvjpeg_dec.cu)
        target_include_directories(dapp_tenant PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/tenant PRIVATE ${DAPP_NVINFER_INC} ${CMAKE_CURRENT_SOURCE_DIR}/e2e)
        if(TARGET CUDA::nvjpeg)
            set(DAPP_TENANT_NVJPEG_LIB CUDA::nvjpeg)
        else()
            find_library(DAPP_TENANT_NVJPEG_LIB nvjpeg HINTS ${CUDAToolkit_LIBRARY_DIR})
        endif()
        target_link_libraries(dapp_tenant PUBLIC dapp_hook PRIVATE ${DAPP_NVINFER_LIB} ${DAPP_TENANT_NVJPEG_LIB} CUDA::cuda_driver CUDA::cudart pthread)
        set_target_properties(dapp_tenant PROPERTIES CXX_STANDARD 17 CXX_STANDARD_REQUIRED ON CUDA_STANDARD 17 POSITION_INDEPENDENT_CODE ON)
        set_source_files_properties(tenant/dapp_tenant.cu e2e/nvjpeg_dec.cu PROPERTIES COMPILE_OPTIONS "-w")
        add_executable(dapp_tenant_main tenant/dapp_tenant_main.cpp)
        target_link_libraries(dapp_tenant_main PRIVATE dapp_tenant CUDA::cudart pthread)
        set_target_properties(dapp_tenant_main PROPERTIES CXX_STANDARD 17 CXX_STANDARD_REQUIRED ON)
        add_executable(dapp_agent_test tenant/dapp_agent_test.cpp tenant/dapp_agent.cpp)
        target_include_directories(dapp_agent_test PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/tenant)
        target_link_libraries(dapp_agent_test PRIVATE pthread)
        set_target_properties(dapp_agent_test PROPERTIES CXX_STANDARD 17 CXX_STANDARD_REQUIRED ON)
        set(DAPP_TENANT_AVAILABLE ON CACHE INTERNAL "dapp_tenant target exists")
        message(STATUS "dapp_tenant: in-process YOLO tenant enabled (${DAPP_NVINFER_LIB})")
    else()
        message(STATUS "dapp_tenant: TensorRT not found, in-process tenant disabled")
    endif()
endif()

# dapp_export_test: synthetic SCF FAPI DL_TTI/UL_TTI messages through the same export code the L1 hook uses.
if(ENABLE_DAPP_HOOK)
    add_executable(dapp_export_test tools/dapp_export_test.cpp
        ${CMAKE_CURRENT_SOURCE_DIR}/../scfl2adapter/lib/scf_5g_fapi/scf_5g_fapi_dapp_export.cpp)
    target_include_directories(dapp_export_test PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/../scfl2adapter/lib/scf_5g_fapi
        ${CMAKE_CURRENT_SOURCE_DIR}/../gt_common_libs/nvIPC/include)
    target_link_libraries(dapp_export_test PRIVATE dapp_hook)
    target_compile_definitions(dapp_export_test PRIVATE ENABLE_DAPP_HOOK)
    if(ENABLE_CONFORMANCE_TM_PDSCH_PDCCH)
        target_compile_definitions(dapp_export_test PRIVATE ENABLE_CONFORMANCE_TM_PDSCH_PDCCH)
    endif()
    set_target_properties(dapp_export_test PROPERTIES CXX_STANDARD 17 CXX_STANDARD_REQUIRED ON)
endif()

install(TARGETS dapp_ring_dump dapp_ring_fakel1 dapp_ring_selftest DESTINATION ${PROJECT_NAME}/bin OPTIONAL)
install(DIRECTORY include/ DESTINATION ${PROJECT_NAME}/include OPTIONAL)
