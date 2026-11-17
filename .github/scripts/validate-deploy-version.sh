#!/usr/bin/env bash
# Normalize deploy version input, enforce semver, and verify the Git release tag exists.
set -euo pipefail

version=$(printf '%s' "$RAW_VERSION" | xargs)
version="${version#v}"

write_summary() {
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    printf '%s\n' "$1" >> "$GITHUB_STEP_SUMMARY"
  else
    printf '%s\n' "$1"
  fi
}

SEMVER_RE='^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$'
if ! [[ "$version" =~ $SEMVER_RE ]]; then
  echo "::error::Invalid version '${RAW_VERSION}'. Provide semver such as 1.0.4 or v1.0.4." >&2
  write_summary "### Deploy Failed: Invalid Version

Provided value \`${RAW_VERSION}\` does not match semver (\`x.y.z\` or \`vx.y.z\`)."
  exit 1
fi

git fetch origin --tags --quiet
if ! git rev-parse -q --verify "refs/tags/v${version}" >/dev/null; then
  echo "::error::Git tag v${version} does not exist in sample-nodejs." >&2
  write_summary "### Deploy Failed: Tag Not Found

Git tag \`v${version}\` does not exist in \`sample-nodejs\`.

Check available release tags or merge changes to \`main\` to run \`Release\` first."
  exit 1
fi

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "version=${version}" >> "$GITHUB_OUTPUT"
else
  echo "version=${version}"
fi
