#!/usr/bin/env bash
# Compute Docker image tag output for build.yml.
set -euo pipefail

if [ "${PUSH:-false}" = "true" ]; then
  if [ -z "${CUSTOM_DOMAIN:-}" ]; then
    echo "::error::CUSTOM_DOMAIN secret must be set when push=true." >&2
    exit 1
  fi
  tag="registry.${CUSTOM_DOMAIN}/${IMAGE_NAME}:${IMAGE_VERSION}"
else
  tag="${IMAGE_NAME}:${IMAGE_VERSION}"
fi

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "tag=${tag}" >> "$GITHUB_OUTPUT"
else
  echo "tag=${tag}"
fi
