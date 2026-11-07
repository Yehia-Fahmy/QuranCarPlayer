#!/bin/sh
# Regenerates QuranCarPlayer.xcodeproj from project.yml using XcodeGen.
# Install: brew install xcodegen
set -eu
cd "$(dirname "$0")/.."
command -v xcodegen >/dev/null 2>&1 || { echo "xcodegen not found; install with: brew install xcodegen" >&2; exit 1; }
xcodegen generate --spec project.yml
