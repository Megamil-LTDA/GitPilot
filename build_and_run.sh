#!/bin/bash

# GitPilot - Build and Run Script
# Run this script to build and launch GitPilot independently from Xcode

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="GitPilot"
BUILD_DIR="${SCRIPT_DIR}/build"
APP_PATH="${BUILD_DIR}/Build/Products/Release/${PROJECT_NAME}.app"

echo "🛫 Building GitPilot..."

# Create build directory
mkdir -p "${BUILD_DIR}"

# Build the project
xcodebuild \
    -project "${SCRIPT_DIR}/${PROJECT_NAME}.xcodeproj" \
    -scheme "${PROJECT_NAME}" \
    -configuration Release \
    -derivedDataPath "${BUILD_DIR}" \
    -quiet \
    build

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo ""
    
    # Check if app is already running
    if pgrep -x "${PROJECT_NAME}" > /dev/null; then
        echo "⚠️  GitPilot is already running. Killing existing instance..."
        pkill -x "${PROJECT_NAME}" || true
        sleep 1
    fi
    
    echo "🚀 Launching GitPilot..."
    open "${APP_PATH}"
    
    echo ""
    echo "✅ GitPilot is now running in your menu bar!"
    echo "   Look for the ✈️ icon with a colored dot."
    echo ""
    echo "📁 App location: ${APP_PATH}"
    echo ""
    echo "💡 To install permanently:"
    echo "   cp -R \"${APP_PATH}\" /Applications/"
else
    echo "❌ Build failed!"
    exit 1
fi
