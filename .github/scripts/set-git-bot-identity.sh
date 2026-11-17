#!/usr/bin/env bash
# Resolve the GitHub Actions bot login and numeric ID dynamically and configure git user.name/user.email.
set -euo pipefail

repo_dir="${1:-.}"
actor_login="${2:-github-actions[bot]}"
encoded_login="${actor_login//\[/%5B}"
encoded_login="${encoded_login//\]/%5D}"

bot_json=$(gh api "users/${encoded_login}")
bot_login=$(printf '%s' "$bot_json" | jq -r '.login')
bot_id=$(printf '%s' "$bot_json" | jq -r '.id')

if [ -z "$bot_login" ] || [ "$bot_login" = "null" ] || [ -z "$bot_id" ] || [ "$bot_id" = "null" ]; then
  echo "::error::Failed to resolve bot identity for ${actor_login} via GitHub API." >&2
  exit 1
fi

git -C "$repo_dir" config user.name "$bot_login"
git -C "$repo_dir" config user.email "${bot_id}+${bot_login}@users.noreply.github.com"
