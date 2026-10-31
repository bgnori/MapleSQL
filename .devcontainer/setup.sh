#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "Installing the toolchain from lean-toolchain and generating lake-manifest.json (10 minute limit)..."
timeout --foreground 600 lake update

echo "Building MapleSQL and its compile-time tests (5 minute limit)..."
timeout --foreground 300 lake build MapleSQL MapleSQLTests
