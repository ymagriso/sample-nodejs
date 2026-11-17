#!/usr/bin/env bash
# Resolve release version, sync package-lock.json and Chart.yaml, and push bump commit on attempt 1.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
run_attempt="${RUN_ATTEMPT:-1}"

git fetch origin main --tags --quiet

curr_version=$(node -p "require('./package.json').version")
if git rev-parse -q --verify HEAD~1 >/dev/null; then
  prev_version=$(git show HEAD~1:package.json | node -e "console.log(JSON.parse(require('fs').readFileSync(0, 'utf8')).version)")
else
  prev_version=""
fi

if [ "$curr_version" != "$prev_version" ]; then
  echo "Version updated in last commit ($prev_version -> $curr_version)."
  version="$curr_version"
elif [ "$run_attempt" = "1" ]; then
  if ! git rev-parse -q --verify "refs/tags/v${curr_version}" >/dev/null; then
    echo "Current version v${curr_version} has not been tagged yet; releasing ${curr_version} without bumping."
    version="$curr_version"
  else
    echo "Version unchanged in last commit ($curr_version); bumping patch version..."
    npm version patch --no-git-tag-version >/dev/null
    version=$(node -p "require('./package.json').version")
  fi
else
  if git rev-parse -q --verify "refs/tags/v${curr_version}" >/dev/null \
    && git rev-parse -q --verify HEAD~1 >/dev/null \
    && git merge-base --is-ancestor "refs/tags/v${curr_version}^{commit}" HEAD~1; then
    echo "Re-run detected: previous version v${curr_version} was tagged before this commit; resolving patch bump..."
    npm version patch --no-git-tag-version >/dev/null
    version=$(node -p "require('./package.json').version")
  else
    echo "Re-run detected: keeping commit version ${curr_version}."
    version="$curr_version"
  fi
fi

SEMVER_RE='^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$'
if ! [[ "$version" =~ $SEMVER_RE ]]; then
  echo "::error::Invalid semver version '$version'" >&2
  exit 1
fi

if [ "$run_attempt" = "1" ] && git rev-parse -q --verify "refs/tags/v${version}" >/dev/null; then
  echo "::error::Git tag v${version} already exists!" >&2
  exit 1
fi

if [ "$(node -p "require('./package-lock.json').version")" != "$version" ]; then
  npm install --package-lock-only --ignore-scripts >/dev/null
fi

"${script_dir}/sync-chart-version.sh" "$version"

release_sha=""
if [ "$run_attempt" != "1" ]; then
  if git rev-parse -q --verify "refs/tags/v${version}" >/dev/null; then
    release_sha=$(git rev-list -n 1 "refs/tags/v${version}")
    echo "Re-run: tag v${version} already exists at ${release_sha}; skipping main bump push."
  else
    existing_bump=$(git log origin/main --grep="chore(release): bump version to v${version}" -n 1 --format=%H || true)
    if [ -n "$existing_bump" ]; then
      release_sha="$existing_bump"
      echo "Re-run: version bump commit ${release_sha} already exists on origin/main; skipping push."
    fi
  fi
fi

if [ -z "$release_sha" ]; then
  if [ -n "$(git status --porcelain)" ]; then
    "${script_dir}/set-git-bot-identity.sh" .
    git add package.json package-lock.json charts/devops-demo/Chart.yaml
    git commit -m "chore(release): bump version to v${version} [skip ci]"
    git push origin HEAD:main
  fi
  release_sha=$(git rev-parse HEAD)
fi

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "version=${version}" >> "$GITHUB_OUTPUT"
  echo "sha=${release_sha}" >> "$GITHUB_OUTPUT"
else
  echo "version=${version}"
  echo "sha=${release_sha}"
fi
