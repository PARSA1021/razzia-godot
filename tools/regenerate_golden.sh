#!/usr/bin/env bash
# Rebuilds tests/golden/* from the reference JS implementation in tools/js (needs Node 18+).
# Run this whenever tools/js/engine.js, ai.js or controller.js change on purpose (a RULE CHANGE), then re-run the Godot tests.
set -e
cd "$(dirname "$0")/js"
node make_golden.mjs ../../tests/golden
node make_rng_vectors.mjs ../../tests/golden/rng.json
node coverage.mjs ../../tests/golden
