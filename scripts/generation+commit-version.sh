#!/bin/bash
set -e

# Resolve directories relative to script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="$SCRIPT_DIR/../VERSION"

if [ ! -f "$VERSION_FILE" ]; then
    echo "Error: VERSION file not found at $VERSION_FILE" >&2
    exit 1
fi

# Run the version generation script first to ensure swift files are in sync
"$SCRIPT_DIR/generate-version.sh"

# Read version and trim whitespace/newlines
VERSION=$(cat "$VERSION_FILE" | xargs)

# Stage the version changes
git add "$VERSION_FILE" "$SCRIPT_DIR/../Sources/M3U8FalconCLI/Version.swift"

# Commit the changes locally
git commit -m "Bump m3u8-falcon CLI version to v$VERSION"

echo "✅ Successfully committed release v$VERSION!"
echo "   Review your changes with 'git log -n 1' or 'git tag -n'."
