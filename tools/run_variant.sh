#!/usr/bin/env bash
# Install one v3 palette variant (+ the shared redesigned characters) into
# art/ and screenshot levels 1/5/10 under Xvfb.
# Usage: run_variant.sh <variant>   (daylight | warm | contrast)
set -e
PROJ="$HOME/workspace/game-shadow-assassin"
VAR="$1"
GODOT="$HOME/tools/godot/Godot_v4.3-stable_linux.x86_64"
OUT="$PROJ/verification/shots-v3-palette/$VAR"
mkdir -p "$OUT"
cp "$PROJ/tools/v3_variants/$VAR"/*.png "$PROJ/art/"
cp "$PROJ/tools/v3_variants/chars"/*.png "$PROJ/art/"
# Reimport: a -s run does NOT reimport changed PNGs on its own, so a stale
# .ctex would be rendered. The editor import step refreshes them.
"$GODOT" --headless --path "$PROJ" --import > "/tmp/v3_${VAR}_import.log" 2>&1
grep -ci "error" "/tmp/v3_${VAR}_import.log" || true
for L in 1 5 10; do
  SHOT_LEVEL=$L OUTDIR="$OUT" xvfb-run -a "$GODOT" --path "$PROJ" \
    -s /tmp/shot_harness_v3.gd > "/tmp/v3_${VAR}_L${L}.log" 2>&1 || true
done
ls -la "$OUT"
