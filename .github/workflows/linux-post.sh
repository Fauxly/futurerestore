#!/usr/bin/env bash

set -euo pipefail

export TMPDIR=/tmp
export WORKFLOW_ROOT="${TMPDIR}/Builder/repos/futurerestore/.github/workflows"
export DEP_ROOT="${TMPDIR}/Builder/repos/futurerestore/dep_root"
export BASE="${TMPDIR}/Builder/repos/futurerestore"

cd "${BASE}"

[[ -f version.txt ]] || {
    echo "::error::version.txt not found."
    exit 1
}

export FUTURERESTORE_VERSION="$(git rev-list --count HEAD | tr -d '\n')"
export FUTURERESTORE_VERSION_RELEASE="$(tr -d '\n' < version.txt)"

cd "${WORKFLOW_ROOT}"

echo "futurerestore-Linux-x86_64-${FUTURERESTORE_VERSION_RELEASE}-Build_${FUTURERESTORE_VERSION}-RELEASE.tar.xz" > name1.txt
echo "futurerestore-Linux-x86_64-${FUTURERESTORE_VERSION_RELEASE}-Build_${FUTURERESTORE_VERSION}-DEBUG.tar.xz" > name2.txt
echo "futurerestore-Linux-x86_64-${FUTURERESTORE_VERSION_RELEASE}-Build_${FUTURERESTORE_VERSION}-ASAN.tar.xz" > name3.txt

[[ -f "${TMPDIR}/Builder/linux_fix.sh" ]] || {
    echo "::error::linux_fix.sh not found."
    exit 1
}

cp -f "${TMPDIR}/Builder/linux_fix.sh" linux_fix.sh

create_archive() {

    local BUILD_NAME="$1"
    local BINARY="$2"
    local ARCHIVE="$3"

    echo ""
    echo "Packaging ${BUILD_NAME}..."

    [[ -f "${BINARY}" ]] || {
        echo "::error::${BINARY} not found."
        exit 1
    }

    cp -f "${BINARY}" futurerestore

    rm -f "${ARCHIVE}"

    tar cPJf "${ARCHIVE}" futurerestore linux_fix.sh

    [[ -f "${ARCHIVE}" ]] || {
        echo "::error::Failed to create ${ARCHIVE}"
        exit 1
    }

    echo "Created ${ARCHIVE}"
    ls -lh "${ARCHIVE}"
}

create_archive \
    "Release" \
    "${BASE}/cmake-build-release-x86_64/src/futurerestore" \
    "futurerestore1.tar.xz"

create_archive \
    "Debug" \
    "${BASE}/cmake-build-debug-x86_64/src/futurerestore" \
    "futurerestore2.tar.xz"

create_archive \
    "ASAN" \
    "${BASE}/cmake-build-asan-x86_64/src/futurerestore" \
    "futurerestore3.tar.xz"

rm -f futurerestore

echo ""
echo "Generated package names:"
cat name1.txt
cat name2.txt
cat name3.txt

echo ""
echo "Artifacts:"
ls -lh *.tar.xz

echo ""
echo "======================================"
echo "Linux post step completed successfully."
echo "======================================"
