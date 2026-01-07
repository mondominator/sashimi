#!/bin/bash

# Setup script for Sashimi development environment

set -e

echo "Setting up Sashimi development environment..."
echo ""

# Change to project root
cd "$(dirname "$0")/.."
PROJECT_ROOT=$(pwd)

# 1. Configure git hooks
echo "1. Configuring git hooks..."
git config core.hooksPath .githooks
echo "   Git hooks configured to use .githooks directory"

# 2. Check for required tools
echo ""
echo "2. Checking required tools..."

check_tool() {
    if command -v "$1" &> /dev/null; then
        echo "   ✓ $1 is installed"
        return 0
    else
        echo "   ✗ $1 is NOT installed"
        return 1
    fi
}

MISSING_TOOLS=0

check_tool "xcodegen" || MISSING_TOOLS=$((MISSING_TOOLS + 1))
check_tool "swiftlint" || MISSING_TOOLS=$((MISSING_TOOLS + 1))
check_tool "xcpretty" || MISSING_TOOLS=$((MISSING_TOOLS + 1))

if [ $MISSING_TOOLS -gt 0 ]; then
    echo ""
    echo "   To install missing tools:"
    echo "   brew install xcodegen swiftlint"
    echo "   gem install xcpretty"
fi

# 3. Generate Xcode project
echo ""
echo "3. Generating Xcode project..."
if command -v xcodegen &> /dev/null; then
    xcodegen generate
    echo "   ✓ Xcode project generated"
else
    echo "   ⚠ Skipped (xcodegen not installed)"
fi

# 4. Resolve Swift packages
echo ""
echo "4. Resolving Swift packages..."
if [ -f "Sashimi.xcodeproj/project.pbxproj" ]; then
    xcodebuild -resolvePackageDependencies -project Sashimi.xcodeproj -scheme Sashimi 2>/dev/null
    echo "   ✓ Swift packages resolved"
else
    echo "   ⚠ Skipped (Xcode project not found)"
fi

echo ""
echo "Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Open Sashimi.xcodeproj in Xcode"
echo "  2. Select a development team in Signing & Capabilities"
echo "  3. Build and run on tvOS Simulator or device"
echo ""
