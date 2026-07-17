#!/usr/bin/env zsh

set -euo pipefail

export WORKFLOW_ROOT="/Users/runner/work/futurerestore/futurerestore/.github/workflows"
export DEP_ROOT="/Users/runner/work/futurerestore/futurerestore/dep_root"
export BASE="/Users/runner/work/futurerestore/futurerestore"
export PROCURSUS="/opt/procursus"

cd "$WORKFLOW_ROOT"

download() {
    local url="$1"
    local file="${url:t}"

    echo "Downloading $file..."

    curl \
        --insecure \
        --fail \
        --location \
        --retry 5 \
        --retry-delay 3 \
        --connect-timeout 20 \
        --output "$file" \
        "$url"

    if [[ ! -s "$file" ]]; then
        echo "::error::$file was not downloaded."
        exit 1
    fi
}

download https://cdn.cryptiiiic.com/bootstrap/bootstrap_x86_64.tar.zst &
download https://cdn.cryptiiiic.com/deps/static/macOS/x86_64/macOS_x86_64_Release_Latest.tar.zst &
download https://cdn.cryptiiiic.com/deps/static/macOS/x86_64/macOS_x86_64_Debug_Latest.tar.zst &
download https://cdn.cryptiiiic.com/deps/static/macOS/arm64/macOS_arm64_Release_Latest.tar.zst &
download https://cdn.cryptiiiic.com/deps/static/macOS/arm64/macOS_arm64_Debug_Latest.tar.zst &

wait

echo "Downloaded archives:"
ls -lh ./*.tar.zst 2>/dev/null || true

echo "Verifying archives..."

for f in ./*.tar.zst; do
    [[ -e "$f" ]] || {
        echo "::error::No archives were downloaded."
        exit 1
    }

    echo "Checking $(basename "$f")"

    gtar -tf "$f" >/dev/null || {
        echo "::error::$(basename "$f") is not a valid archive."
        exit 1
    }
done

echo "Extracting bootstrap..."

sudo gtar -xf bootstrap_x86_64.tar.zst -C / --warning=none

echo "Updating PATH..."

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

echo "Checking extracted dependencies..."

for dir in \
    macOS_x86_64_Release \
    macOS_x86_64_Debug \
    macOS_arm64_Release \
    macOS_arm64_Debug
do
    [[ -d "$DEP_ROOT/$dir/include" ]] || {
        echo "::error::$dir/include not found."
        exit 1
    }

    [[ -d "$DEP_ROOT/$dir/lib" ]] || {
        echo "::error::$dir/lib not found."
        exit 1
    }
done

if [[ -e /usr/local/bin ]]; then
    sudo mv /usr/local/bin /usr/local/bin.bak
fi

cd "$BASE"

echo "Updating submodules..."

git submodule sync --recursive
git submodule update --init --recursive

cd "$BASE/external/tsschecker"

git submodule sync --recursive
git submodule update --init --recursive

echo "Bootstrap completed successfully."