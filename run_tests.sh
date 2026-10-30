#!/usr/bin/env bash
# Usage: ./run_tests.sh [path-to-godot]   (Godot 4.3+; headless)
GODOT="${1:-${GODOT:-godot}}"
exec "$GODOT" --headless --path "$(dirname "$0")" --script res://tests/run_tests.gd
