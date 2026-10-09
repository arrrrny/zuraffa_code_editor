#!/bin/bash
set -e
# Merge the current publish branch into master, tag it, push, and delete it.
# Pass -f to force-push master (use with care).

GREEN='\033[0;32m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'

FORCE=""
[ "$1" == "-f" ] && FORCE="--force"

BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$BRANCH" != publish-* ]]; then
    echo -e "${RED}Not on a publish branch (on '$BRANCH').${NC}"; exit 1
fi

VERSION=${BRANCH#publish-}
echo -e "${BLUE}Merging $BRANCH into master and tagging $VERSION${NC}"

git checkout master
git merge --no-ff "$BRANCH" -m "Merge $BRANCH"
git tag -a "$VERSION" -m "$VERSION"
git push origin master $FORCE
git push origin "$VERSION"
git branch -d "$BRANCH"
git push origin --delete "$BRANCH"

echo -e "${GREEN}Released $VERSION.${NC}"
