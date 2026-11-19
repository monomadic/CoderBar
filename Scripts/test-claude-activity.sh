#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc -O Sources/CoderBarKit/*.swift Tests/CoderBarKitTests/ClaudeActivityTests.swift -o "$TEST_DIR/claude-activity-tests"
"$TEST_DIR/claude-activity-tests"
