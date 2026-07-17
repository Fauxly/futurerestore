#!/usr/bin/env bash

set -euo pipefail

export TMPDIR=/tmp
export WORKFLOW_ROOT="${TMPDIR}/Builder/repos/futurerestore/.github/workflows"
export DEP_ROOT="${TMPDIR}/Builder/repos/futurerestore/dep_root"
export BASE="${TMPDIR}/Builder/repos/futurerestore"

sed -i \
  -e 's|deb http://deb.debian.org/debian buster main|deb http://archive.debian.org/debian buster main contrib non-free|g' \
  -e 's|deb http://deb.debian.org/debian-security buster/updates main|deb http://archive.debian.org/debian-security buster/updates main contrib non-free|g' \
  -e 's|deb http://deb.debian.org/debian buster-updates main|deb http://archive.debian.org/debian buster-backports main contrib non-free|g' \
  /etc/apt/sources.list

apt-get -qq update
apt-get -yqq dist-upgrade

apt-get install --no-install-recommends -yqq \
    zstd \
    curl \
    gnupg2 \
    lsb-release \
    wget \
    software-properties-common \
    build-essential \
    git \
    autoconf \
    automake \
    libtool-bin \
    pkg-config \
    cmake \
    zlib1g-dev \
    libminizip-dev \
    libpng-dev \
    libreadline-dev \
    libbz2-dev \
    libudev-dev \
    libudev1

cp -RpP /usr/bin/ld /
rm -rf /usr/bin/ld /usr/lib/x86_64-linux-gnu/lib{usb-1.0,png*,readline}.so*

chown -R 0:0 "${BASE}"

cd "${BASE}"

git submodule sync --recursive
git submodule update --init --recursive

cd "${WORKFLOW_ROOT}"

curl -fsSL -o llvm.sh https://apt.llvm.org/llvm.sh
chmod +x llvm.sh
./llvm.sh 15 all

ln -sf /usr/bin/ld.lld-15 /usr/bin/ld
ln -sf /usr/bin/clang-15 /usr/bin/clang
ln -sf /usr/bin/clang++-15 /usr/bin/clang++

download() {
    local url="$1"
    local file

    file=$(basename "$url")

    echo "Downloading ${file}..."

    curl \
        --insecure \
        --fail \
        --location \
        --retry 5 \
        --retry-delay 3 \
        --connect-timeout 20 \
        --output "${file}" \
        "${url}"

    if [[ ! -s "${file}" ]]; then
        echo "::error::${file} was not downloaded."
        exit 1
    fi
}

download https://cdn.cryptiiiic.com/bootstrap/linux_fix.tar.zst &
download https://cdn.cryptiiiic.com/deps/static/Linux/x86_64/Linux_x86_64_Release_Latest.tar.zst &
download https://cdn.cryptiiiic.com/deps/static/Linux/x86_64/Linux_x86_64_Debug_Latest.tar.zst &
download https://github.com/Kitware/CMake/releases/download/v3.23.2/cmake-3.23.2-linux-x86_64.tar.gz &

wait

echo "Downloaded files:"
ls -lh

echo "Verifying archives..."

for f in \
    Linux_x86_64_Release_Latest.tar.zst \
    Linux_x86_64_Debug_Latest.tar.zst \
    linux_fix.tar.zst
do
    [[ -f "$f" ]] || {
        echo "::error::$f not found."
        exit 1
    }

    tar -tf "$f" >/dev/null || {
        echo "::error::$f is corrupted."
        exit 1
    }
done

tar -tzf cmake-3.23.2-linux-x86_64.tar.gz >/dev/null || {
    echo "::error::cmake archive is corrupted."
    exit 1
}

rm -rf "${DEP_ROOT}"

mkdir -p \
    "${DEP_ROOT}/Linux_x86_64_Release" \
    "${DEP_ROOT}/Linux_x86_64_Debug"

echo "Extracting archives..."

tar xf Linux_x86_64_Release_Latest.tar.zst -C "${DEP_ROOT}/Linux_x86_64_Release" &
tar xf Linux_x86_64_Debug_Latest.tar.zst -C "${DEP_ROOT}/Linux_x86_64_Debug" &
tar xf linux_fix.tar.zst -C "${TMPDIR}/Builder" &
tar xf cmake-3.23.2-linux-x86_64.tar.gz

wait

echo "Checking extracted dependencies..."

for dir in \
    Linux_x86_64_Release \
    Linux_x86_64_Debug
do
    [[ -d "${DEP_ROOT}/${dir}/include" ]] || {
        echo "::error::${dir}/include not found."
        exit 1
    }

    [[ -d "${DEP_ROOT}/${dir}/lib" ]] || {
        echo "::error::${dir}/lib not found."
        exit 1
    }
done

echo "Dependency layout:"

find "${DEP_ROOT}" -maxdepth 2 -type d | sort

echo "Installing CMake..."

cp -a cmake-3.23.2-linux-x86_64/bin/. /usr/local/bin/

mkdir -p /usr/local/share

cp -a cmake-3.23.2-linux-x86_64/share/. /usr/local/share/

if [[ -d cmake-3.23.2-linux-x86_64/doc ]]; then
    mkdir -p /usr/local/doc
    cp -a cmake-3.23.2-linux-x86_64/doc/. /usr/local/doc/
fi

if [[ -d cmake-3.23.2-linux-x86_64/man ]]; then
    mkdir -p /usr/local/share/man
    cp -a cmake-3.23.2-linux-x86_64/man/. /usr/local/share/man/
fi

rm -rf \
    *.zst \
    *.gz \
    cmake-3.23.2-linux-x86_64 \
    llvm.sh

echo "Linux bootstrap completed successfully."

cd "${WORKFLOW_ROOT}"
