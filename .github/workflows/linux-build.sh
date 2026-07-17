#!/usr/bin/env bash

set -euo pipefail

export TMPDIR=/tmp
export WORKFLOW_ROOT="${TMPDIR}/Builder/repos/futurerestore/.github/workflows"
export DEP_ROOT="${TMPDIR}/Builder/repos/futurerestore/dep_root"
export BASE="${TMPDIR}/Builder/repos/futurerestore"

check_dependencies() {
    local CONFIG="$1"

    echo "Checking ${CONFIG} dependencies..."

    [[ -d "${DEP_ROOT}/${CONFIG}/include" ]] || {
        echo "::error::${CONFIG}/include not found."
        exit 1
    }

    [[ -d "${DEP_ROOT}/${CONFIG}/lib" ]] || {
        echo "::error::${CONFIG}/lib not found."
        exit 1
    }
}

link_dependencies() {
    local CONFIG="$1"

    rm -f "${DEP_ROOT}/include"
    rm -f "${DEP_ROOT}/lib"

    ln -s "${DEP_ROOT}/${CONFIG}/include" "${DEP_ROOT}/include"
    ln -s "${DEP_ROOT}/${CONFIG}/lib" "${DEP_ROOT}/lib"
}

build() {

    local BUILD_TYPE="$1"
    local BUILD_DIR="$2"
    local DEP_SET="$3"
    shift 3

    echo ""
    echo "========================================"
    echo "Building ${BUILD_TYPE}"
    echo "========================================"

    check_dependencies "${DEP_SET}"
    link_dependencies "${DEP_SET}"

    cd "${BASE}"

    rm -rf "${BUILD_DIR}"

    cmake \
        -S . \
        -B "${BUILD_DIR}" \
        -G "CodeBlocks - Unix Makefiles" \
        -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
        -DCMAKE_MAKE_PROGRAM="$(command -v make)" \
        -DCMAKE_C_COMPILER=clang-15 \
        -DCMAKE_CXX_COMPILER=clang++-15 \
        -DCMAKE_LINKER=ld.lld-15 \
        -DCMAKE_MESSAGE_LOG_LEVEL=WARNING \
        -DARCH=x86_64 \
        -DNO_PKGCFG=ON \
        "$@"

    make -j"$(nproc)" -l"$(nproc)" -C "${BUILD_DIR}"

    [[ -f "${BUILD_DIR}/src/futurerestore" ]] || {
        echo "::error::${BUILD_DIR}/src/futurerestore was not produced."
        exit 1
    }

    echo "✓ ${BUILD_TYPE} build finished."
}

build \
    Release \
    cmake-build-release-x86_64 \
    Linux_x86_64_Release

build \
    Debug \
    cmake-build-debug-x86_64 \
    Linux_x86_64_Debug

build \
    Debug \
    cmake-build-asan-x86_64 \
    Linux_x86_64_Debug \
    -DASAN=ON

echo ""
echo "Stripping release binary..."

[[ -f cmake-build-release-x86_64/src/futurerestore ]] || {
    echo "::error::Release binary not found."
    exit 1
}

llvm-strip-15 -s cmake-build-release-x86_64/src/futurerestore

echo ""
echo "Build artifacts:"
ls -lh \
    cmake-build-release-x86_64/src/futurerestore \
    cmake-build-debug-x86_64/src/futurerestore \
    cmake-build-asan-x86_64/src/futurerestore

echo ""
echo "========================================"
echo "Linux build completed successfully."
echo "========================================"
