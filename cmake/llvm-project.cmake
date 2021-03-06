# - Find the llvm/mlir libraries
# This module finds if llvm/mlir is installed, or build llvm/mlir from source.
# This module sets the following variables.
#
#  MLIR_LLVM_INCLUDE_DIR     - path to the LLVM/MLIR include files
#  MLIR_LLVM_LIBS            - path to the LLVM/MLIR libraries
#
# This module define the following functions.
#
# external_tablegen_library  - created interface library which depends on tablegen outputs

include(CMakeParseArguments)

function(external_tablegen_library)
    cmake_parse_arguments(
        _RULE
        "TESTONLY"
        "NAME;TBLGEN"
        "SRCS;INCLUDES;OUTS"
        ${ARGN}
        )

    if(_RULE_TESTONLY AND NOT MGE_WITH_TEST)
        return()
    endif()

    set(_NAME ${_RULE_NAME})

    set(LLVM_TARGET_DEFINITIONS ${_RULE_SRCS})
    set(_INCLUDE_DIRS ${_RULE_INCLUDES})
    list(TRANSFORM _INCLUDE_DIRS PREPEND "-I")
    set(_OUTPUTS)
    while(_RULE_OUTS)
        list(GET _RULE_OUTS 0 _COMMAND)
        list(REMOVE_AT _RULE_OUTS 0)
        list(GET _RULE_OUTS 0 _FILE)
        list(REMOVE_AT _RULE_OUTS 0)
        tablegen(${_RULE_TBLGEN} ${_FILE} ${_COMMAND} ${_INCLUDE_DIRS})
        list(APPEND _OUTPUTS ${CMAKE_CURRENT_BINARY_DIR}/${_FILE})
    endwhile()
    add_custom_target(${_NAME}_target DEPENDS ${_OUTPUTS})

    add_library(${_NAME} INTERFACE)
    add_dependencies(${_NAME} ${_NAME}_target)

    target_include_directories(${_NAME} INTERFACE
        "$<BUILD_INTERFACE:${_RULE_INCLUDES}>")

    install(TARGETS ${_NAME} EXPORT ${MGE_EXPORT_TARGETS})
endfunction()

if (MGE_USE_SYSTEM_LIB)
    find_package(ZLIB)
    find_package(MLIR REQUIRED CONFIG)
    message(STATUS "Using MLIRConfig.cmake in: ${MLIR_DIR}")
    message(STATUS "Using LLVMConfig.cmake in: ${LLVM_DIR}")
    list(APPEND CMAKE_MODULE_PATH "${MLIR_CMAKE_DIR}")
    list(APPEND CMAKE_MODULE_PATH "${LLVM_CMAKE_DIR}")
    include(TableGen)

    set(MLIR_LLVM_INCLUDE_DIR ${LLVM_INCLUDE_DIRS} ${MLIR_INCLUDE_DIRS})

    set(MLIR_LLVM_COMPONENTS Core;Support;X86CodeGen;OrcJIT;NVPTX)
    llvm_map_components_to_libnames(MLIR_LLVM_LIBS ${MLIR_LLVM_COMPONENTS})
    set(MLIR_LLVM_LIB_DIR ${MLIR_INSTALL_PREFIX}/lib)

    function(find_mlir_llvm_lib lib)
        find_library(${lib}
            NAMES ${lib}
            PATHS ${MLIR_LLVM_LIB_DIR}
            NO_DEFAULT_PATH)
        if(${${lib}} STREQUAL ${lib}-NOTFOUND)
            message(FATAL_ERROR "${lib} not found, did you forget to build llvm-project?")
        else()
            list(APPEND MLIR_LLVM_LIBS ${lib})
            set(MLIR_LLVM_LIBS "${MLIR_LLVM_LIBS}" PARENT_SCOPE)
        endif()
    endfunction(find_mlir_llvm_lib)

    set(MLIR_COMPONENTS MLIRAnalysis;MLIRExecutionEngine;MLIRIR;MLIRParser;MLIRPass;MLIRSideEffectInterfaces;MLIRTargetLLVMIR;MLIRTransforms;MLIRAffineToStandard;MLIRSCFToStandard;MLIRAVX512ToLLVM;MLIRAVX512;MLIRLLVMAVX512;MLIRSDBM;MLIRROCDLIR;MLIRGPU;MLIRQuant;MLIRSPIRV;MLIRNVVMIR;MLIRShape;MLIRGPUToNVVMTransforms;MLIRTargetNVVMIR;MLIRGPUToGPURuntimeTransforms;MLIRStandardOpsTransforms)

    foreach(c ${MLIR_COMPONENTS})
        find_mlir_llvm_lib(${c})
    endforeach()
    return()
endif()

function(add_mge_mlir_src_dep llvm_monorepo_path)
    set(_CMAKE_BUILD_TYPE "${CMAKE_BUILD_TYPE}")
    string(TOUPPER "${CMAKE_BUILD_TYPE}" uppercase_CMAKE_BUILD_TYPE)
    if(NOT uppercase_CMAKE_BUILD_TYPE MATCHES "^(DEBUG|RELEASE|RELWITHDEBINFO|MINSIZEREL)$")
        set(CMAKE_BUILD_TYPE "Debug")
    endif()
    set(_CMAKE_BUILD_SHARED_LIBS ${BUILD_SHARED_LIBS})
    set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)

    add_subdirectory("${llvm_monorepo_path}/llvm" ${LLVM_BUILD_DIR} EXCLUDE_FROM_ALL)

    # Reset CMAKE_BUILD_TYPE to its previous setting
    set(CMAKE_BUILD_TYPE "${_CMAKE_BUILD_TYPE}" CACHE STRING "Build type" FORCE)
    # Reset BUILD_SHARED_LIBS to its previous setting
    set(BUILD_SHARED_LIBS ${_CMAKE_BUILD_SHARED_LIBS} CACHE BOOL "Build shared libraries" FORCE)
endfunction()

set(LLVM_INCLUDE_EXAMPLES OFF CACHE BOOL "" FORCE)
set(LLVM_INCLUDE_TESTS OFF CACHE BOOL "" FORCE)
set(LLVM_INCLUDE_BENCHMARKS OFF CACHE BOOL "" FORCE)
set(LLVM_ENABLE_RTTI ${MGE_ENABLE_RTTI} CACHE BOOL "" FORCE)
set(LLVM_TARGETS_TO_BUILD "X86;NVPTX;AMDGPU;AArch64;ARM;PowerPC;SystemZ" CACHE STRING "" FORCE)
set(LLVM_ENABLE_PROJECTS "mlir" CACHE STRING "" FORCE)
set(LLVM_BUILD_DIR ${PROJECT_BINARY_DIR}/third_party/llvm-project/llvm)

add_mge_mlir_src_dep("third_party/llvm-project")

set(MLIR_LLVM_INCLUDE_DIR
    ${PROJECT_SOURCE_DIR}/third_party/llvm-project/llvm/include
    ${PROJECT_BINARY_DIR}/third_party/llvm-project/llvm/include
    ${PROJECT_SOURCE_DIR}/third_party/llvm-project/mlir/include
    ${PROJECT_BINARY_DIR}/third_party/llvm-project/llvm/tools/mlir/include
    )
set(MLIR_TABLEGEN_EXE mlir-tblgen)

set(MLIR_LLVM_LIBS LLVMCore;LLVMSupport;LLVMX86CodeGen;LLVMOrcJIT;LLVMNVPTXCodeGen;LLVMNVPTXDesc;LLVMNVPTXInfo;MLIRAnalysis;MLIRExecutionEngine;MLIRIR;MLIRParser;MLIRPass;MLIRSideEffectInterfaces;MLIRTargetLLVMIR;MLIRTransforms;MLIRAffineToStandard;MLIRSCFToStandard;MLIRAVX512ToLLVM;MLIRAVX512;MLIRLLVMAVX512;MLIRSDBM;MLIRROCDLIR;MLIRGPU;MLIRQuant;MLIRSPIRV;MLIRNVVMIR;MLIRGPUToNVVMTransforms;MLIRShape;MLIRTargetNVVMIR;MLIRGPUToGPURuntimeTransforms;MLIRStandardOpsTransforms)
