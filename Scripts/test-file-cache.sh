#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc -O Sources/CoderBarKit/FileContentCache.swift \
    Tests/CoderBarKitTests/FileContentCacheTests.swift -o "$TEST_DIR/file-cache-tests"
"$TEST_DIR/file-cache-tests"
