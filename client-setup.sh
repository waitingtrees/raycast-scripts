#!/bin/bash
# Client setup script for Raycast script syncing
# Usage: bash <(curl -s https://raw.githubusercontent.com/waitingtrees/raycast-scripts/main/client-setup.sh) /path/to/scripts clientname

set -e

SCRIPTS_DIR="$1"
CLIENT_NAME="$2"

if [ -z "$SCRIPTS_DIR" ] || [ -z "$CLIENT_NAME" ]; then
  echo "❌ Usage: bash <(curl ...) /path/to/their/scripts/folder clientname"
  exit 1
fi

# Normalize path (resolve ~, remove trailing slash)
SCRIPTS_DIR="${SCRIPTS_DIR%/}"
SCRIPTS_DIR="${SCRIPTS_DIR/#\~/$HOME}"

if [ ! -d "$SCRIPTS_DIR" ]; then
  echo "❌ Directory not found: $SCRIPTS_DIR"
  exit 1
fi

CLONE_DIR="$SCRIPTS_DIR/cole-scripts"
NTFY_TOPIC="waitingtrees-${CLIENT_NAME}-scripts"
PLIST_NAME="com.waitingtrees.${CLIENT_NAME}-scripts-sync"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"

# 1. Sparse checkout into subfolder
echo "⚡ Cloning scripts for $CLIENT_NAME..."
if [ -d "$CLONE_DIR" ]; then
  echo "⚠️  $CLONE_DIR already exists, pulling latest..."
  cd "$CLONE_DIR" && git pull
else
  mkdir -p "$CLONE_DIR"
  cd "$CLONE_DIR"
  git init
  git remote add origin https://github.com/waitingtrees/raycast-scripts.git
  git sparse-checkout init --cone
  git sparse-checkout set "clients/$CLIENT_NAME"
  git pull origin main
fi

chmod +x "$CLONE_DIR/clients/$CLIENT_NAME"/*.sh 2>/dev/null || true

# 2. Create the sync listener script
SYNC_SCRIPT="$CLONE_DIR/.sync-listener.sh"
cat > "$SYNC_SCRIPT" << SYNCEOF
#!/bin/bash
# Auto-sync listener — subscribes to ntfy.sh, pulls on notification
CLONE_DIR="$CLONE_DIR"
NTFY_TOPIC="$NTFY_TOPIC"

while true; do
  # Subscribe to ntfy — blocks until a message arrives, then loops
  # Uses /raw endpoint with long-poll (no poll=1 means it waits)
  curl -sf "https://ntfy.sh/\$NTFY_TOPIC/raw" > /dev/null 2>&1

  # Pull latest and fix permissions
  cd "\$CLONE_DIR" && git pull --quiet origin main 2>/dev/null
  chmod +x "\$CLONE_DIR/clients/"*/*.sh 2>/dev/null || true

  # Small delay to avoid tight loop on connection errors
  sleep 2
done
SYNCEOF
chmod +x "$SYNC_SCRIPT"

# 3. Install launchd plist for background auto-sync
cat > "$PLIST_PATH" << PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_NAME}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${SYNC_SCRIPT}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/${PLIST_NAME}.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/${PLIST_NAME}.err</string>
</dict>
</plist>
PLISTEOF

# Load the daemon
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"

echo ""
echo "✅ Setup complete!"
echo ""
echo "📁 Scripts synced to: $CLONE_DIR/clients/$CLIENT_NAME/"
echo "🔄 Auto-sync is running in the background (survives reboots)"
echo ""
echo "Raycast should auto-discover scripts in the subfolder."
echo "If not, add '$SCRIPTS_DIR' in Raycast → Settings → Script Commands."
