#!/bin/bash

# Setze Basisverzeichnisse
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="/var/mobile/relo"
LAUNCH_AGENTS="/var/mobile/Library/LaunchAgents"

echo "[*] Erstelle Zielverzeichnisse..."
mkdir -p "$TARGET_DIR/config"
mkdir -p "$LAUNCH_AGENTS"

echo "[*] Kopiere Skript und Konfigurationsdateien..."
cp "$SRC_DIR/autorelo.sh" "$TARGET_DIR/"
cp "$SRC_DIR/config/"*.conf "$TARGET_DIR/config/"
chmod +x "$TARGET_DIR/autorelo.sh"

echo "[*] Installiere .plist-Dateien aus plist/..."
for plist_file in "$SRC_DIR/plist/"*.plist; do
  plist_name=$(basename "$plist_file")
  echo "    - $plist_name"

  cp "$plist_file" "$LAUNCH_AGENTS/"
  launchctl unload "$LAUNCH_AGENTS/$plist_name" 2>/dev/null
  launchctl load "$LAUNCH_AGENTS/$plist_name"
done

echo "[✓] Alle LaunchAgents wurden installiert und geladen."
