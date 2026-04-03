#!/bin/zsh
set -euo pipefail

WORKSPACE_DIR="/Users/mahiro/Desktop/Antigravity/Apple Watch 心拍取得アプリ　テスト"
LINK_PATH="/tmp/HeartStateLabWorkspace"

ln -sfn "$WORKSPACE_DIR" "$LINK_PATH"
echo "Linked $LINK_PATH -> $WORKSPACE_DIR"
