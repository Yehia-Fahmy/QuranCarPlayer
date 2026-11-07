#!/bin/sh
# Builds and tests the platform-independent core package on macOS.
#
# Works with only the Command Line Tools installed. The CLT ships Swift Testing but its
# build system does not resolve the TestingMacros plugin automatically, so the plugin is
# passed explicitly. With full Xcode selected, the plain `swift test` also works.
set -eu
cd "$(dirname "$0")/../Packages/QuranCarPlayerCore"

TOOLCHAIN_DIR="$(dirname "$(dirname "$(xcrun --find swift)")")"
PLUGIN="$TOOLCHAIN_DIR/lib/swift/host/plugins/testing/libTestingMacros.dylib"

if [ -f "$PLUGIN" ]; then
  exec swift test -Xswiftc -load-plugin-library -Xswiftc "$PLUGIN" "$@"
else
  exec swift test "$@"
fi
