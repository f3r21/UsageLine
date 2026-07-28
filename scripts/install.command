#!/usr/bin/env bash
#
# install.command
#
# Lives inside UsageLine.dmg next to UsageLine.app. Double-clicking this
# (from the mounted DMG) does the entire install in one step: copies the app
# to /Applications, re-signs it locally (fixes the ad-hoc-signature
# EXC_BAD_SIGNATURE crash that happens when a signed .app is copied from a
# different machine), clears the quarantine flag, and launches it — so
# there's no separate "open Terminal and paste a command" step at all.
#
# This still needs one right-click -> Open the first time, like any
# downloaded executable that isn't from a paid Apple Developer ID + notarized
# — there's no way around that part without paying Apple for one.

set -euo pipefail

dmg_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src_app="$dmg_dir/UsageLine.app"
dest_app="/Applications/UsageLine.app"

if [[ ! -d "$src_app" ]]; then
  echo "No se encontró UsageLine.app junto a este script." >&2
  echo "Este archivo debe correr desde dentro del .dmg montado." >&2
  read -n 1 -s -r -p "Presiona cualquier tecla para cerrar..."
  exit 1
fi

echo "Instalando UsageLine en /Applications..."
rm -rf "$dest_app"
cp -R "$src_app" "$dest_app"

echo "Corrigiendo la firma local (evita el error 'developer cannot be verified')..."
codesign --force --deep --sign - "$dest_app"
xattr -d com.apple.quarantine "$dest_app" 2>/dev/null || true

echo "Abriendo UsageLine..."
open "$dest_app"

echo ""
echo "Listo. Puedes cerrar esta ventana."
read -n 1 -s -r -p "Presiona cualquier tecla para cerrar..."
