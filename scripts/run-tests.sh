#!/usr/bin/env bash
# Shared entry point for CI and manual verification.
#   bash scripts/run-tests.sh [--times] [-j [N]] [-t text] [--tag tag] [spec filter...]
#   --times      report how long each spec file took
#   -j [N]       run spec files in N parallel processes (default: one per CPU)
#   -t text      only tests whose full name contains text
#   --tag tag    only tests tagged #tag
# Uses luajit, or lua5.1 when LuaJIT isn't installed.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

lua=
for candidate in luajit lua5.1; do
	if command -v "$candidate" >/dev/null; then lua="$candidate"; break; fi
done
if [[ -z "$lua" ]]; then
	echo 'LuaJIT (or Lua 5.1) is required to run tests. Install luajit and retry.' >&2
	exit 1
fi

exec "$lua" tests/run.lua "$@"
