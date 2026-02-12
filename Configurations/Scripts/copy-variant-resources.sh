#!/bin/bash
#
# copy-variant-resources.sh
# Copies variant-specific resources at build time
#

set -e

VARIANT_DIR="${PROJECT_DIR}/Configurations/Variants/${BRAND_IDENTIFIER}"
MAIN_ASSETS_DIR="${PROJECT_DIR}/VoiceFlow/Assets.xcassets"

if [ -z "$BRAND_IDENTIFIER" ]; then
    echo "error: BRAND_IDENTIFIER is not set. Ensure your xcconfig defines BRAND_IDENTIFIER."
    exit 1
fi

if [ ! -d "$VARIANT_DIR" ]; then
    echo "error: Variant directory not found: $VARIANT_DIR"
    exit 1
fi

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║ Copying variant resources for: ${BRAND_IDENTIFIER}"
echo "╚════════════════════════════════════════════════════════════════╝"

# COPY ASSETS.XCASSETS
VARIANT_ASSETS="${VARIANT_DIR}/Assets.xcassets"

if [ -d "$VARIANT_ASSETS" ]; then
    echo "→ Merging variant Assets.xcassets into main"
    # Copy variant assets over main (merge, don't replace entirely)
    cp -R "$VARIANT_ASSETS/" "$MAIN_ASSETS_DIR/"
    echo "  ✓ Variant assets merged"
else
    echo "→ No variant Assets.xcassets found, skipping"
fi

echo ""
echo "✓ Done!"
echo ""
