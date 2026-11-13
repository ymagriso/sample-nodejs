# DevOps Sample Node.js App

## Overview

A lightweight Node.js application. It features basic web endpoints, Prometheus metrics integration, and is designed for Kubernetes deployment and CI/CD pipeline demonstrations.

## Features

- Express.js web server
- Prometheus metrics integration
- Readiness and liveness probe endpoints
- Customizable port via environment variable
- Helm chart (`charts/devops-demo`) packaged and published as an OCI artifact

## Prerequisites

- Node.js (v22.1.0)
- Helm (for chart validation / packaging)

## Development

```bash
npm ci          # install dependencies
npm start       # run the server (PORT defaults to 8080)
npm test        # run unit tests (node:test + supertest)
npm run lint    # run ESLint
helm lint charts/devops-demo
```

## CI & Release Architecture

GitHub Actions is split into a reusable build workflow and separate PR/release triggers:

- **Reusable Build Workflow ([.github/workflows/build.yml](.github/workflows/build.yml)):**
  Runs ESLint, unit tests, `npm audit --audit-level=high`, a local server smoke test, Docker image build + container smoke test, and Helm chart lint/template/packaging. When `push: true`, it also pushes the container image (`registry.<CUSTOM_DOMAIN>/devops-demo:<version>`) and Helm chart (`oci://registry.<CUSTOM_DOMAIN>/charts/devops-demo:<version>`) to the private OCI registry.
- **Pull Request CI ([.github/workflows/ci.yml](.github/workflows/ci.yml)):**
  - `release-guard`: Validates `x.y.z` semver in `package.json`, ensures `package-lock.json` matches, and checks that the target release tag (`v<version>`) does not already exist.
  - `build`: Calls `build.yml` with `push: false` to verify code, container image, and Helm chart packaging before merge.
- **Release Pipeline ([.github/workflows/release.yml](.github/workflows/release.yml)):**
  Triggered on push to `main`:
  1. **`prepare`:** Checks if `package.json` `.version` was updated in the last commit. If unchanged, increments the patch version (`x.y.z -> x.y.(z+1)` via `npm version patch`), syncs `charts/devops-demo/Chart.yaml` (`version` and `appVersion`), and pushes a `[skip ci]` commit to `main`.
  2. **`build-and-push`:** Calls `build.yml` on the prepared commit with `push: true`.
  3. **`gitops-and-tag`:** Clones `ymagriso/k8s-resources` using an SSH Deploy Key (`K8S_RESOURCES_DEPLOY_KEY`), updates `targetRevision` and `image.tag` in `argocd/apps/devops-demo.yaml` directly on `main` for Argo CD reconciliation, and pushes an annotated Git tag `v<version>` pointing to the release commit.

### Required GitHub Secrets (`sample-nodejs`)

| Secret | Purpose |
|---|---|
| `CUSTOM_DOMAIN` | Base domain for the private OCI registry (`registry.<CUSTOM_DOMAIN>`) |
| `DOCKER_REGISTRY_USERNAME` | OCI registry username |
| `DOCKER_REGISTRY_PASSWORD` | OCI registry password |
| `K8S_RESOURCES_DEPLOY_KEY` | SSH private key with write access to `ymagriso/k8s-resources` |

## Kubernetes Workload Design: `Deployment` vs. `StatefulSet`

The Helm chart ([charts/devops-demo](charts/devops-demo)) deploys the application as a **`Deployment`** with `replicaCount: 1` (and `RollingUpdate` with `maxSurge: 1`, `maxUnavailable: 0`).

| Dimension | `Deployment` (Selected) | `StatefulSet` |
| :--- | :--- | :--- |
| **Workload Model** | Stateless, interchangeable replicas behind a `ClusterIP` Service | Stateful workloads requiring stable identity & dedicated per-pod storage |
| **Pod Naming & DNS** | Ephemeral pod hash (`devops-demo-7f8d5b-...`) | Deterministic ordinal (`devops-demo-0`, `devops-demo-1`) + Headless Service |
| **Rollout Strategy** | Concurrent `RollingUpdate`; zero downtime even at 1 replica (`maxSurge: 1`, `maxUnavailable: 0`) | Strictly sequential ordered updates (`N-1` down to `0`); slower rollouts |
| **Storage** | Ephemeral container filesystem (`readOnlyRootFilesystem: true`); no PVCs needed | 1-to-1 `volumeClaimTemplates` PVCs per pod (extra disk cost and manual cleanup on scale-down) |
| **Failover & Scaling** | Fast parallel scaling and immediate rescheduling on node loss | Conservative eviction on unreachable nodes to avoid split-brain |

**Why `Deployment` with `replicaCount: 1` fits `devops-demo`:**
1. **Stateless 12-Factor Architecture:** `app.js` holds no persistent local state; any replica can serve HTTP requests identically.
2. **Zero-Downtime Releases at Single Replica:** `maxSurge: 1` and `maxUnavailable: 0` create the new pod and wait for `/ready` (`200 Ready`) before terminating the old pod.
3. **Consistent Metrics & Resource Efficiency:** Prometheus metrics (`root_access_total`) are stored in-memory per pod, so a single replica avoids split counters across pods during demos while matching the single-replica footprint of core cluster services (`docker-registry`, `argocd`).
