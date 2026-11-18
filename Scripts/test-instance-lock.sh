#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc Sources/CoderBarKit/ProcessInstanceLock.swift Tests/CoderBarKitTests/ProcessInstanceLockTests.swift -o "$TEST_DIR/instance-tests"
"$TEST_DIR/instance-tests"
