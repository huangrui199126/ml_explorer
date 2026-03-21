#!/bin/bash
# Build and install MLExplorer on iPhone wirelessly via Xcode
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "Opening project in Xcode and triggering build..."

# Open project in Xcode
open MLExplorer.xcodeproj

sleep 3

# Trigger Cmd+R (Run) in Xcode
osascript \
    -e 'tell application "Xcode" to activate' \
    -e 'tell application "System Events" to keystroke "r" using command down'

echo "Build started on Xcode — check your iPhone in ~30 seconds."
