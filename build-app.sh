#!/bin/bash

# Build script for MacWidget.app
# This script builds the Swift package and creates a proper macOS .app bundle

set -e

# Configuration
APP_NAME="MacWidget"
BUNDLE_NAME="${APP_NAME}.app"
BUILD_DIR=".build/release"
OUTPUT_DIR="build"

echo "🔨 Building ${APP_NAME} in release mode..."
swift build -c release

echo "📦 Creating app bundle..."

# Clean and create output directory
rm -rf "${OUTPUT_DIR}/${BUNDLE_NAME}"
mkdir -p "${OUTPUT_DIR}/${BUNDLE_NAME}/Contents/MacOS"
mkdir -p "${OUTPUT_DIR}/${BUNDLE_NAME}/Contents/Resources"

# Copy executable
cp "${BUILD_DIR}/${APP_NAME}" "${OUTPUT_DIR}/${BUNDLE_NAME}/Contents/MacOS/"

# Copy Info.plist
cp "Resources/Info.plist" "${OUTPUT_DIR}/${BUNDLE_NAME}/Contents/"

# Create PkgInfo
echo -n "APPL????" > "${OUTPUT_DIR}/${BUNDLE_NAME}/Contents/PkgInfo"

echo "✅ Build complete!"
echo "   App bundle created at: ${OUTPUT_DIR}/${BUNDLE_NAME}"
echo ""
echo "To run the app:"
echo "   open ${OUTPUT_DIR}/${BUNDLE_NAME}"
echo ""
echo "To install to Applications folder:"
echo "   cp -r ${OUTPUT_DIR}/${BUNDLE_NAME} /Applications/"
