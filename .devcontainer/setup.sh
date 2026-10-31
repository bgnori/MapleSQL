#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "Installing the toolchain from lean-toolchain and generating lake-manifest.json (10 minute limit)..."
timeout --foreground 600 lake update

echo "Testing MapleSQL (5 minute limit)..."
timeout --foreground 300 lake test
