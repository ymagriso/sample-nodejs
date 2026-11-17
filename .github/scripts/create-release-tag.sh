#!/usr/bin/env bash
# Create and push the annotated Git release tag if not already present.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

git fetch origin --tags --quiet
if git rev-parse -q --verify "refs/tags/v${VERSION}" >/dev/null; then
  echo "Git tag v${VERSION} already exists; skipping tag creation."
  exit 0
fi

"${script_dir}/set-git-bot-identity.sh" .
git tag -a "v${VERSION}" "${TARGET_SHA}" -m "Release v${VERSION}"
git push origin "v${VERSION}"
