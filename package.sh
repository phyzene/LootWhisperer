#!/bin/bash
# Package PzLootWhisperer for CurseForge upload.
# Run from the addon root: bash package.sh
# Produces: PzLootWhisperer-<version>.zip

set -e

# Read version from TOC
VERSION=$(grep "## Version:" PzLootWhisperer.toc | sed 's/## Version: //' | tr -d '\r\n ')
if [ -z "$VERSION" ]; then
    echo "Error: Could not read version from TOC file."
    exit 1
fi

OUTDIR="release"
ADDON="PzLootWhisperer"
ZIPNAME="${ADDON}-${VERSION}.zip"
STAGING="${OUTDIR}/${ADDON}"

echo "Packaging ${ADDON} v${VERSION}..."

# Clean previous build
rm -rf "$OUTDIR"
mkdir -p "$STAGING"

# Copy addon files
cp PzLootWhisperer.toc "$STAGING/"
cp Core.lua "$STAGING/"
cp Config.lua "$STAGING/"

# Copy Libs (including embeds.xml and all library folders)
cp -r Libs "$STAGING/Libs"

# Remove anything that shouldn't ship
rm -rf "$STAGING/Libs/.git" 2>/dev/null || true

# Create zip (CurseForge expects the addon folder at the root of the zip)
cd "$OUTDIR"
zip -r "../${ZIPNAME}" "$ADDON"
cd ..

# Cleanup staging
rm -rf "$OUTDIR"

echo "Done: ${ZIPNAME}"
