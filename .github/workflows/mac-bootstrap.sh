#!/usr/bin/env zsh

set -euo pipefail

export WORKFLOW_ROOT="/Users/runner/work/futurerestore/futurerestore/.github/workflows"
export DEP_ROOT="/Users/runner/work/futurerestore/futurerestore/dep_root"
export BASE="/Users/runner/work/futurerestore/futurerestore"

cd "$WORKFLOW_ROOT"

download() {
    local url="$1"
    local file="${url:t}"

    echo "Downloading $file"

    curl \
        --fail \
        --location \
        --retry 5 \
        --retry-delay 3 \
        --connect-timeout 20 \
        --output "$file" \
        "$url"

    if [[ ! -s "$file" ]]; then
        echo "::error::$file was not downloaded"
        exit 1
    fi
}

download https://cdn.cryptiiiic.com/bootstrap/bootstrap_x86_64.tar.zst &
download https://cdn.cryptiiiic.com/deps/static/macOS/x86_64/macOS_x86_64_Release_Latest.tar.zst &
download https://cdn.cryptiiiic.com/deps/static/macOS/x86_64/macOS_x86_64_Debug_Latest.tar.zst &
download https://cdn.cryptiiiic.com/deps/static/macOS/arm64/macOS_arm64_Release_Latest.tar.zst &
download https://cdn.cryptiiiic.com/deps/static/macOS/arm64/macOS_arm64_Debug_Latest.tar.zst &

wait

echo "Extracting bootstrap..."

sudo gtar -xf bootstrap_x86_64.tar.zst -C / --warning=none

echo "${PROCURSUS}/bin" | sudo tee /etc/paths.new >/dev/null
echo "${PROCURSUS}/libexec/gnubin" | sudo tee -a /etc/paths.new >/dev/null
cat /etc/paths | sudo tee -a /etc/paths.new >/dev/null
sudo mv /etc/paths.new /etc/paths

rm -rf "$DEP_ROOT"
mkdir -p \
    "$DEP_ROOT/macOS_x86_64_Release" \
    "$DEP_ROOT/macOS_x86_64_Debug" \
    "$DEP_ROOT/macOS_arm64_Release" \
    "$DEP_ROOT/macOS_arm64_Debug"

echo "Extracting dependency archives..."

gtar -xf macOS_x86_64_Release_Latest.tar.zst -C "$DEP_ROOT/macOS_x86_64_Release" &
gtar -xf macOS_x86_64_Debug_Latest.tar.zst -C "$DEP_ROOT/macOS_x86_64_Debug" &
gtar -xf macOS_arm64_Release_Latest.tar.zst -C "$DEP_ROOT/macOS_arm64_Release" &
gtar -xf macOS_arm64_Debug_Latest.tar.zst -C "$DEP_ROOT/macOS_arm64_Debug" &

wait

if [[ -e /usr/local/bin ]]; then
    sudo mv /usr/local/bin /usr/local/bin.bak
fi

cd "$BASE"

git submodule sync --recursive
git submodule update --init --recursive

cd "$BASE/external/tsschecker"
git submodule sync --recursive
git submodule update --init --recursive

echo "Bootstrap completed successfully."
