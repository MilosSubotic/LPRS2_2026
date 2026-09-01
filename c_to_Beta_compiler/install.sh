#!/usr/bin/env bash

set -euo pipefail

BETA_DIR="/usr/local/share/beta"
BIN_DIR="/usr/local/bin"
EMU_SRC="simulator/beta.uasm"
TARGET_BIN="betac"

echo "[1/4] Creating beta system directory..."
sudo mkdir -p "$BETA_DIR"

sleep 0.5

echo "[2/4] Installing beta.uasm..."
if [ ! -f "$EMU_SRC" ]; then
    echo "ERROR: $EMU_SRC not found"
    exit 1
fi

sudo cp "$EMU_SRC" "$BETA_DIR/beta.uasm"

sleep 0.5

echo "[3/4] Building compiler..."
make clean
make

if [ ! -f "$TARGET_BIN" ]; then
    echo "ERROR: build failed, $TARGET_BIN not found"
    exit 1
fi

sleep 0.5

echo "[4/4] Installing betac to $BIN_DIR..."
sudo install -m 755 "$TARGET_BIN" "$BIN_DIR/"

sleep 0.5

make clean
clear

echo ""
echo "Installation complete"
echo "betac available globally"
echo "beta.uasm installed in $BETA_DIR"