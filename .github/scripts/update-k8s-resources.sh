#!/usr/bin/env bash
# Update argocd/apps/devops-demo.yaml in k8s-resources and push to main.
set -euo pipefail

repo_dir="${1:-k8s-resources}"
app_file="${repo_dir}/argocd/apps/devops-demo.yaml"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

sed -E -i "0,/^([[:space:]]*targetRevision:[[:space:]]*).*/s//\1${VERSION}/" "$app_file"
sed -E -i "0,/^([[:space:]]*tag:[[:space:]]*).*/s//\1${VERSION}/" "$app_file"

if [ -n "$(git -C "$repo_dir" status --porcelain)" ]; then
  "${script_dir}/set-git-bot-identity.sh" "$repo_dir"
  git -C "$repo_dir" add argocd/apps/devops-demo.yaml
  git -C "$repo_dir" commit -m "ci(devops-demo): release v${VERSION}"
  git -C "$repo_dir" pull --rebase origin main
  git -C "$repo_dir" push origin main
  status_msg="Updated \`argocd/apps/devops-demo.yaml\` in \`ymagriso/k8s-resources\` to \`${VERSION}\`."
else
  echo "k8s-resources already at version ${VERSION}"
  status_msg="\`ymagriso/k8s-resources\` is already at version \`${VERSION}\`."
fi

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  printf '### Deploy Complete\n\n%s\n' "$status_msg" >> "$GITHUB_STEP_SUMMARY"
else
  printf '### Deploy Complete\n\n%s\n' "$status_msg"
fi
