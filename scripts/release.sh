#!/bin/bash
set -euo pipefail

# FluxTerm release script
# Usage: ./scripts/release.sh [major|minor|patch]
#
# Bumps the version, creates a git tag, and pushes it.
# The CI workflow (.github/workflows/release.yml) then handles:
#   build → bundle → GitHub release → update Homebrew tap

BUMP="${1:-}"

if [[ ! "$BUMP" =~ ^(major|minor|patch)$ ]]; then
    echo "Usage: ./scripts/release.sh [major|minor|patch]"
    echo ""
    echo "Examples:"
    echo "  ./scripts/release.sh patch   # 0.1.1 → 0.1.2"
    echo "  ./scripts/release.sh minor   # 0.1.1 → 0.2.0"
    echo "  ./scripts/release.sh major   # 0.1.1 → 1.0.0"
    exit 1
fi

# Get latest version tag
LATEST_TAG=$(git tag --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1)

if [ -z "$LATEST_TAG" ]; then
    echo "Error: No existing version tags found (expected vX.Y.Z format)"
    exit 1
fi

# Parse version components
VERSION="${LATEST_TAG#v}"
IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION"

# Bump
case "$BUMP" in
    major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
    minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
    patch) PATCH=$((PATCH + 1)) ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
NEW_TAG="v${NEW_VERSION}"

# Preflight checks
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$BRANCH" != "main" ]; then
    echo "Warning: You are on branch '$BRANCH', not 'main'."
    read -rp "Continue anyway? [y/N] " CONFIRM
    [[ "$CONFIRM" =~ ^[Yy]$ ]] || exit 0
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Error: Working tree has uncommitted changes. Commit or stash them first."
    exit 1
fi

# Confirm
echo ""
echo "  Current version:  $VERSION"
echo "  Bump type:        $BUMP"
echo "  New version:      $NEW_VERSION"
echo "  Tag:              $NEW_TAG"
echo "  Branch:           $BRANCH"
echo ""
read -rp "Create and push tag $NEW_TAG? [y/N] " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

# Tag and push
git tag -a "$NEW_TAG" -m "Release $NEW_VERSION"
git push origin "$NEW_TAG"

echo ""
echo "Tag $NEW_TAG pushed. CI will now:"
echo "  1. Build arm64, x86_64, and universal binaries"
echo "  2. Create .app bundle"
echo "  3. Create GitHub Release with artifacts"
echo "  4. Update Homebrew tap"
echo ""
echo "Track progress: https://github.com/faizal97/flux-term/actions"
