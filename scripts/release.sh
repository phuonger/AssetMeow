#!/bin/bash
# Release script for AssetMeow
# Usage: ./scripts/release.sh 2.1.0
#
# This script:
# 1. Updates the version in project.pbxproj
# 2. Commits the version bump
# 3. Creates a git tag
# 4. Pushes to GitHub (which triggers the build workflow)

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 2.1.0"
    exit 1
fi

VERSION=$1
TAG="v${VERSION}"

echo "🐱 Releasing AssetMeow ${VERSION}..."

# Update MARKETING_VERSION in project.pbxproj
sed -i '' "s/MARKETING_VERSION = [^;]*/MARKETING_VERSION = ${VERSION}/" AssetMeow.xcodeproj/project.pbxproj

# Update CURRENT_PROJECT_VERSION (increment build number)
# Extract current build number and increment
CURRENT_BUILD=$(grep -m1 "CURRENT_PROJECT_VERSION" AssetMeow.xcodeproj/project.pbxproj | grep -o '[0-9]*')
NEW_BUILD=$((CURRENT_BUILD + 1))
sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*/CURRENT_PROJECT_VERSION = ${NEW_BUILD}/g" AssetMeow.xcodeproj/project.pbxproj

echo "  Version: ${VERSION} (build ${NEW_BUILD})"

# Commit and tag
git add -A
git commit -m "Release ${TAG}"
git tag -a "${TAG}" -m "Release ${VERSION}"

echo "  Tagged: ${TAG}"

# Push
git push origin main
git push origin "${TAG}"

echo ""
echo "✅ Done! GitHub Actions will now:"
echo "   1. Build the app"
echo "   2. Create a DMG and ZIP"
echo "   3. Create a GitHub Release"
echo "   4. Update appcast.xml for auto-updates"
echo ""
echo "   Monitor progress: https://github.com/phuonger/AssetMeow/actions"
