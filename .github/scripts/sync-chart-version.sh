#!/usr/bin/env bash
# Sync version and appVersion in charts/devops-demo/Chart.yaml.
set -euo pipefail

version="${1:?version argument is required}"
chart_path="${2:-charts/devops-demo/Chart.yaml}"

sed -E -i "s/^version:[[:space:]]*.*/version: ${version}/" "$chart_path"
sed -E -i "s/^appVersion:[[:space:]]*.*/appVersion: \"${version}\"/" "$chart_path"
