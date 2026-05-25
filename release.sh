#!/bin/bash
# release.sh -- release helper for gotta-go
#
# Usage:
#   ./release.sh prep <version>      Bump version, set sha256 placeholder, commit
#   ./release.sh finalize <version>  Compute sha256, update Cask, commit, push

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$REPO_ROOT/gotta-go.command"
BUNDLE_SCRIPT="$REPO_ROOT/Gotta Go.app/Contents/Resources/gotta-go.command"
PLIST="$REPO_ROOT/Gotta Go.app/Contents/Info.plist"
CASK="$REPO_ROOT/Casks/gotta-go.rb"
TARBALL_BASE="https://github.com/rderveloy/gotta-go/archive/refs/tags"

usage() {
    echo "Usage:"
    echo "  ./release.sh prep <version>      Bump version, set sha256 placeholder, commit"
    echo "  ./release.sh finalize <version>  Compute sha256, update Cask, commit, push"
    echo ""
    echo "Example: ./release.sh prep 2.0.6"
    exit 1
}

[ $# -lt 2 ] && usage
CMD="$1"
VERSION="$2"

if ! echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "Error: version must be in format X.Y.Z (e.g. 2.0.6)"
    exit 1
fi

case "$CMD" in
    prep)
        if [ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]; then
            echo "Error: uncommitted changes present. Commit or stash them first."
            exit 1
        fi

        echo "Bumping version to $VERSION..."

        sed -i '' "s/^VERSION=.*/VERSION=\"$VERSION\"/" "$SCRIPT"
        sed -i '' "s/<string>[0-9]*\.[0-9]*\.[0-9]*<\/string>/<string>$VERSION<\/string>/g" "$PLIST"
        sed -i '' "s/version \"[^\"]*\"/version \"$VERSION\"/" "$CASK"
        sed -i '' 's/sha256 "[^"]*"/sha256 "PLACEHOLDER_REPLACE_AFTER_RELEASE"/' "$CASK"

        cp "$SCRIPT" "$BUNDLE_SCRIPT"

        git -C "$REPO_ROOT" add \
            "$SCRIPT" "$BUNDLE_SCRIPT" "$PLIST" "$CASK"
        git -C "$REPO_ROOT" commit -m \
            "Bump to v$VERSION; Cask sha256 placeholder pending release tag"

        echo ""
        echo "Done. Next steps:"
        echo ""
        echo "  1. Push and open a PR, then merge to main"
        echo ""
        echo "  2. On main, tag and push:"
        echo "       git checkout main && git pull"
        echo "       git tag -a v$VERSION -m \"Version $VERSION\""
        echo "       git push origin v$VERSION"
        echo ""
        echo "  3. Create a GitHub Release from tag v$VERSION"
        echo ""
        echo "  4. Run: ./release.sh finalize $VERSION"
        ;;

    finalize)
        TARBALL_URL="$TARBALL_BASE/v${VERSION}.tar.gz"

        echo "Fetching tarball and computing sha256 for v$VERSION..."
        SHA=$(curl -sL "$TARBALL_URL" | shasum -a 256 | awk '{print $1}')

        if [ -z "$SHA" ]; then
            echo "Error: could not compute sha256."
            echo "Make sure the tag is pushed and the GitHub Release exists."
            exit 1
        fi

        echo "sha256: $SHA"
        echo "Updating Cask..."

        sed -i '' "s/sha256 \"[^\"]*\"/sha256 \"$SHA\"/" "$CASK"

        git -C "$REPO_ROOT" add "$CASK"
        git -C "$REPO_ROOT" commit -m "Cask: set v$VERSION sha256"
        git -C "$REPO_ROOT" push

        echo ""
        echo "Done. v$VERSION is ready to install:"
        echo ""
        echo "  brew update && brew install --cask gotta-go"
        ;;

    *)
        usage
        ;;
esac
