#!/bin/bash
set -e
# Publish ceremony for the single-package `zuraffa_code_editor` repo.
# Adapted from the zuraffa_permissions pipeline (publish-manager flow),
# simplified because this repo publishes one package from the repository root.

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

PUBSPEC="pubspec.yaml"
APP_DIR="$(cd "$(dirname "$0")/.." >/dev/null 2>&1; pwd -P)"

if [ "$#" -eq 0 ]; then
    VERSION=$(grep "^version:" "$APP_DIR/$PUBSPEC" | sed 's/version: //' | tr -d '[:space:]')
    [ -z "$VERSION" ] && echo -e "${RED}Usage: $0 <version>${NC}" && exit 1
else
    VERSION=$1
fi
if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}Version must be semver (X.Y.Z)${NC}"; exit 1
fi

BRANCH="publish-$VERSION"
ROOT_DIR="$(pwd)"
cd "$ROOT_DIR"

git diff --quiet || { echo -e "${RED}Working tree is dirty - commit or stash first.${NC}"; exit 1; }
git checkout -b "$BRANCH" 2>/dev/null || { echo -e "${RED}Branch $BRANCH already exists${NC}"; exit 1; }
echo -e "${GREEN}Created branch $BRANCH${NC}"

# Bump the package version.
sed -i '' "s/^version: .*/version: $VERSION/" "$PUBSPEC"
echo -e "${GREEN}Set version to $VERSION in $PUBSPEC${NC}"

# The changelog entry must already be in place at the top of CHANGELOG.md.
if ! grep -q "^## $VERSION$" CHANGELOG.md; then
    echo -e "${RED}CHANGELOG.md has no '## $VERSION' entry. Add release notes first.${NC}"
    exit 1
fi

git add -A
git commit -m "$VERSION" --quiet
echo -e "${GREEN}Committed $BRANCH${NC}"
echo -e "${BLUE}Next: git push -u origin $BRANCH && ./scripts/publish.sh${NC}"
