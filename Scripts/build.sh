#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
# Validate options before compiling; packaging owns their behavior.
for arg in "$@"; do
    case "$arg" in
        --open|--install) ;;
        -h|--help) exec zsh Scripts/package.sh --help ;;
        *) echo "Unknown option: $arg" >&2; exit 2 ;;
    esac
done
swift build -c release
exec zsh Scripts/package.sh "$@"
