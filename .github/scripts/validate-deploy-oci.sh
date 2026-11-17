#!/usr/bin/env bash
# Validate that both the container image and Helm OCI chart exist for the target release version.
set -euo pipefail

if [ -z "${REGISTRY_HOST:-}" ] || [ "$REGISTRY_HOST" = "registry." ]; then
  echo "::error::CUSTOM_DOMAIN secret is required." >&2
  exit 1
fi

printf '%s' "$REGISTRY_PASS" | helm registry login "$REGISTRY_HOST" \
  --username "$REGISTRY_USER" \
  --password-stdin

image_ok=true
chart_ok=true

if ! docker manifest inspect "${REGISTRY_HOST}/devops-demo:${VERSION}" >/dev/null 2>&1; then
  image_ok=false
fi

mkdir -p /tmp/helm-verify
if ! helm pull "oci://${REGISTRY_HOST}/charts/devops-demo" --version "${VERSION}" --destination /tmp/helm-verify >/dev/null 2>&1; then
  chart_ok=false
fi

if [ "$image_ok" != "true" ] || [ "$chart_ok" != "true" ]; then
  echo "::error::OCI artifact check failed for v${VERSION} (image_ok=${image_ok}, chart_ok=${chart_ok})." >&2
  summary_msg="### Deploy Failed: Missing OCI Artifacts for \`v${VERSION}\`

Git tag \`v${VERSION}\` exists, but the private registry lacks one or more artifacts:
- Container image (\`devops-demo:${VERSION}\`): \`${image_ok}\`
- Helm chart (\`charts/devops-demo:${VERSION}\`): \`${chart_ok}\`

Re-run the **Release** workflow for \`v${VERSION}\` (and ensure cluster VMs are running) to push the OCI artifacts, then retry **Deploy**."
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    printf '%s\n' "$summary_msg" >> "$GITHUB_STEP_SUMMARY"
  else
    printf '%s\n' "$summary_msg"
  fi
  exit 1
fi
