#!/bin/bash
set -e
# Dry-run then publish zuraffa_code_editor to pub.dev.
# Needs flutter/dart on PATH and pub.dev credentials.

GREEN='\033[0;32m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'

APP_DIR="$(cd "$(dirname "$0")/.." >/dev/null 2>&1; pwd -P)"
cd "$APP_DIR"

echo -e "${BLUE}Dry run...${NC}"
flutter pub publish --dry-run

echo -e "${BLUE}Publishing...${NC}"
flutter pub publish --force

echo -e "${GREEN}Published. pub.dev may take a minute to index the version.${NC}"
echo -e "${BLUE}Next: ./scripts/push_to_master.sh -f${NC}"
