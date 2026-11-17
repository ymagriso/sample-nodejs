#!/usr/bin/env bash
# Write an informational GitHub Step Summary when deploy is skipped on a release re-run.
set -euo pipefail

summary_msg="### Deploy Skipped on Re-Run

Skipped the deploy job on workflow re-run (attempt \`${ATTEMPT}\`) for version \`v${VERSION}\`.
OCI artifacts were rebuilt and pushed to the private registry.

Run the **Deploy** workflow manually with version \`${VERSION}\` if you want to deploy this release to \`k8s-resources\`."

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  printf '%s\n' "$summary_msg" >> "$GITHUB_STEP_SUMMARY"
else
  printf '%s\n' "$summary_msg"
fi
