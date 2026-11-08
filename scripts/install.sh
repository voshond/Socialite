#!/usr/bin/env bash
# Install / reinstall Socialite into the WoW Forever client.
#
# Usage:
#   scripts/install.sh               # remove the old copy, copy addon files into AddOns/Socialite
#   scripts/install.sh --link        # remove the old copy, symlink AddOns/Socialite -> this repo
#   scripts/install.sh --uninstall   # remove AddOns/Socialite (SavedVariables in WTF/ are kept)
#
# Copy mode ships only addon files: *.toc, *.lua, *.xml, i18n/, vendor/,
# Socialite.tga/.png and LICENSE (no tests/, scripts/, .git, ...).
#
# Environment overrides:
#   WOW_DIR     WoW client dir (default: Forever under Faugus/battlenet)

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WOW_DIR="${WOW_DIR:-/mnt/data02/Games/Faugus/battlenet/drive_c/Program Files (x86)/World of Warcraft/_forever_}"
ADDONS_DIR="$WOW_DIR/Interface/AddOns"
NAME="Socialite"
TARGET="$ADDONS_DIR/$NAME"
ADDON_DIRS=(i18n vendor)
ADDON_FILES=(Socialite.tga Socialite.png LICENSE)

die() { echo "error: $*" >&2; exit 1; }

remove_existing() {
	if [[ -L "$TARGET" ]]; then
		rm "$TARGET"
	elif [[ -d "$TARGET" ]]; then
		rm -rf -- "$TARGET"
	elif [[ -e "$TARGET" ]]; then
		die "$TARGET exists but is not a directory or symlink, refusing to touch it"
	else
		return 1
	fi
}

copy_addon() {
	mkdir -p "$TARGET"
	shopt -s nullglob
	local file dir
	for file in "$REPO_DIR"/*.toc "$REPO_DIR"/*.lua "$REPO_DIR"/*.xml; do
		cp "$file" "$TARGET/"
	done
	shopt -u nullglob
	for file in "${ADDON_FILES[@]}"; do
		[[ -f "$REPO_DIR/$file" ]] && cp "$REPO_DIR/$file" "$TARGET/"
	done
	for dir in "${ADDON_DIRS[@]}"; do
		cp -R "$REPO_DIR/$dir" "$TARGET/"
	done
}

mode="copy"
case "${1:-}" in
	"") ;;
	--link) mode="link" ;;
	--uninstall) mode="uninstall" ;;
	-h|--help) sed -n '2,13p' "$0"; exit 0 ;;
	*) die "unknown option: $1 (see --help)" ;;
esac

[[ -f "$REPO_DIR/$NAME.toc" ]] || die "$NAME.toc not found in $REPO_DIR"
[[ -d "$WOW_DIR" ]] || die "WoW dir not found: $WOW_DIR (set WOW_DIR to your client folder)"
mkdir -p "$ADDONS_DIR"

if remove_existing; then
	echo "removed  $TARGET"
fi

case "$mode" in
	uninstall)
		echo "uninstalled $NAME"
		exit 0
		;;
	link)
		ln -s "$REPO_DIR" "$TARGET"
		echo "linked   $TARGET -> $REPO_DIR"
		;;
	copy)
		copy_addon
		echo "copied   $NAME"
		;;
esac

echo "done. In game: /reload (restart the client if you added new files to the .toc)"
