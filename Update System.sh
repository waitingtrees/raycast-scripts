#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Update System
# @raycast.mode fullOutput

# Optional parameters:
# @raycast.icon ♻️
# @raycast.packageName Maintenance

# Documentation:
# @raycast.description Updates Homebrew, upgrades packages/casks, and cleans up.

START_TIME=$(date +%s)
ERRORS=0

echo "Starting system update..."
echo "----------------------------------------"

# Check if brew is installed
if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew is not installed."
    exit 1
fi

echo "📦 Upgrading formulae and casks..."
if ! brew upgrade; then
    echo "⚠️ Some packages failed to upgrade"
    ((ERRORS++))
fi

echo "----------------------------------------"
echo "🧹 Cleaning up..."
brew cleanup

# Clean and optimize system
echo "----------------------------------------"
echo "✨ Cleaning and optimizing system..."
sudo mo clean

# Update Mac App Store apps via mas
if command -v mas &> /dev/null; then
    echo "----------------------------------------"
    echo "🛍️ Updating Mac App Store apps..."
    if ! mas upgrade; then
        echo "⚠️ Some App Store apps failed to update"
        ((ERRORS++))
    fi
else
    echo "----------------------------------------"
    echo "ℹ️ 'mas' CLI not found. Install it with 'brew install mas' to update App Store apps."
fi

# Install macOS system updates
echo "----------------------------------------"
echo "🖥️ Installing macOS system updates..."
if ! sudo softwareupdate -ia; then
    echo "⚠️ System update failed"
    ((ERRORS++))
fi

ELAPSED=$(( $(date +%s) - START_TIME ))
MINS=$((ELAPSED / 60))
SECS=$((ELAPSED % 60))

echo "----------------------------------------"
if [ "$ERRORS" -gt 0 ]; then
    echo "⚠️ System update finished with $ERRORS error(s) in ${MINS}m ${SECS}s"
else
    echo "✅ System update complete in ${MINS}m ${SECS}s"
fi
