#!/bin/bash

# Automated Release Script for NeoAgent
# Handles version bumping, tagging, and GitHub Release creation.

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

usage() {
  echo "Usage: ./scripts/release.sh [patch|minor|major]"
  echo "Example: ./scripts/release.sh patch"
  exit 1
}

# Check for gh CLI
if ! command -v gh &> /dev/null; then
  echo -e "${RED}Error: gh CLI is not installed.${NC} Please install it via 'brew install gh' and authenticate with 'gh auth login'."
  exit 1
fi

BUMP_TYPE=$1
if [[ -z "$BUMP_TYPE" ]]; then
  usage
fi

if [[ "$BUMP_TYPE" != "patch" && "$BUMP_TYPE" != "minor" && "$BUMP_TYPE" != "major" ]]; then
  echo -e "${RED}Error: Invalid bump type '$BUMP_TYPE'.${NC}"
  usage
fi

# Ensure clean working directory
if [[ -n $(git status --porcelain) ]]; then
  echo -e "${RED}Error: Your working directory is not clean.${NC} Please commit or stash your changes first."
  exit 1
fi

# Ensure we are on main branch
CURRENT_BRANCH=$(git branch --show-current)
if [[ "$CURRENT_BRANCH" != "main" ]]; then
  echo -e "${RED}Error: You must be on the 'main' branch to release.${NC} (Current branch: $CURRENT_BRANCH)"
  exit 1
fi

# Pull latest changes
echo -e "${GREEN}Pulling latest changes...${NC}"
git pull origin main

# Perform version bump
echo -e "${GREEN}Bumping version ($BUMP_TYPE)...${NC}"
NEW_VERSION=$(npm version "$BUMP_TYPE" --no-git-tag-version)
echo -e "${GREEN}New version: $NEW_VERSION${NC}"

# Update version in package.json and commit
git add package.json package-lock.json
git commit -m "chore: release $NEW_VERSION"
git tag -a "$NEW_VERSION" -m "release $NEW_VERSION"

# Push changes and tags
echo -e "${GREEN}Pushing changes and tags to origin...${NC}"
if [[ "$DRY_RUN" == "1" ]]; then
  echo "DRY_RUN: git push origin main && git push origin $NEW_VERSION"
else
  git push origin main
  git push origin "$NEW_VERSION"
fi

# Create GitHub Release
echo -e "${GREEN}Creating GitHub Release...${NC}"
if [[ "$DRY_RUN" == "1" ]]; then
  echo "DRY_RUN: gh release create $NEW_VERSION --generate-notes"
else
  gh release create "$NEW_VERSION" --generate-notes
fi

echo -e "${GREEN}Release $NEW_VERSION completed successfully!${NC}"
