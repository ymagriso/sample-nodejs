#!/usr/bin/env bash
# Run HTTP smoke probes against either the local Node.js server or the built container.
set -euo pipefail

mode="${1:-local}"
port="${PORT:-8080}"

wait_for_ready() {
  for _ in $(seq 1 20); do
    if curl -sf "http://localhost:${port}/ready" > /dev/null; then
      return 0
    fi
    sleep 1
  done
  echo "::error::Server did not become ready on port ${port}." >&2
  return 1
}

case "$mode" in
  local)
    node app.js > server.log 2>&1 &
    wait_for_ready
    curl -sf "http://localhost:${port}/ready"   | grep -q '^Ready$'
    curl -sf "http://localhost:${port}/live"    | grep -q '^Alive$'
    curl -sf "http://localhost:${port}/my-app"  | grep -q 'Hello, World!'
    curl -sf "http://localhost:${port}/metrics" | grep -q 'root_access_total'
    echo "Smoke test passed"
    ;;
  container)
    docker run -d --name app -p "${port}:8080" "$IMAGE_TAG"
    wait_for_ready
    curl -sf "http://localhost:${port}/live" | grep -q '^Alive$'
    echo "Container smoke test passed"
    ;;
  *)
    echo "::error::Invalid smoke test mode '${mode}'. Expected 'local' or 'container'." >&2
    exit 1
    ;;
esac
