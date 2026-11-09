#!/usr/bin/env bash
# Renders Socialite's UI proof: Titan Panel's bar with the Socialite button and
# its tooltip, per scenario, to .proof/<scenario>.svg/.png and .proof/index.html.
#   bash scripts/proof.sh [scenario filter...]
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
command -v luajit >/dev/null || { echo 'LuaJIT is required for UI proof (the BLP decoder uses its ffi).' >&2; exit 1; }
command -v rsvg-convert >/dev/null || echo 'rsvg-convert not found: writing SVG only.' >&2
command -v magick >/dev/null || command -v convert >/dev/null \
	|| echo 'ImageMagick not found: .tga and .blp textures render as placeholders.' >&2

lib="$(bash scripts/fetch-wut.sh)"
exec luajit -e "package.path = '$lib/?.lua;$lib/?/init.lua;' .. package.path" tests/proof/run.lua "$@"
