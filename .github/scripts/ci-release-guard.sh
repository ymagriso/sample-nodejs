#!/usr/bin/env bash
# Validate PR package.json semver, package-lock.json alignment, and target release tag availability.
set -euo pipefail

git fetch origin "$BASE_REF" --tags --quiet

BASE_SHA=$(git rev-parse "origin/${BASE_REF}")
MERGE_BASE=$(git merge-base "$BASE_SHA" "$PR_SHA")

read_pkg_version() {
  git show "$1" | node -e "console.log(JSON.parse(require('fs').readFileSync(0, 'utf8')).version)"
}

BASE_VERSION=$(read_pkg_version "${BASE_SHA}:package.json")
ANCESTOR_VERSION=$(read_pkg_version "${MERGE_BASE}:package.json")
PR_VERSION=$(read_pkg_version "${PR_SHA}:package.json")
PR_LOCK_VERSION=$(read_pkg_version "${PR_SHA}:package-lock.json")

SEMVER_RE='^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$'
if ! [[ "$PR_VERSION" =~ $SEMVER_RE ]]; then
  echo "::error::package.json version '$PR_VERSION' must follow semver (x.y.z or x.y.z-prerelease)."
  exit 1
fi

if [ "$PR_VERSION" != "$PR_LOCK_VERSION" ]; then
  echo "::error::package.json version ($PR_VERSION) does not match package-lock.json version ($PR_LOCK_VERSION). Run 'npm install --package-lock-only'."
  exit 1
fi

if [ "$PR_VERSION" != "$ANCESTOR_VERSION" ]; then
  TARGET_VERSION="$PR_VERSION"
  echo "PR manually changed version: $ANCESTOR_VERSION -> $TARGET_VERSION (base is $BASE_VERSION)"
elif ! git rev-parse -q --verify "refs/tags/v${BASE_VERSION}" >/dev/null; then
  TARGET_VERSION="$BASE_VERSION"
  echo "Base version v${BASE_VERSION} has no release tag yet; release on main will publish $TARGET_VERSION"
else
  if [[ "$BASE_VERSION" == *-* ]]; then
    TARGET_VERSION="${BASE_VERSION%%-*}"
  else
    IFS='.' read -r MAJOR MINOR PATCH <<< "$BASE_VERSION"
    TARGET_VERSION="${MAJOR}.${MINOR}.$((PATCH + 1))"
  fi
  echo "PR left version unchanged ($ANCESTOR_VERSION); release on main ($BASE_VERSION) will bump to $TARGET_VERSION"
fi

if git rev-parse -q --verify "refs/tags/v${TARGET_VERSION}" >/dev/null; then
  echo "::error::Git tag v${TARGET_VERSION} already exists. Bump package.json to an unreleased version."
  exit 1
fi

echo "Release guard passed: target version v${TARGET_VERSION} is available."
