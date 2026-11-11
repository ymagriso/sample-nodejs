# DevOps Sample Node.js App

## Overview

A lightweight Node.js application. It features basic web endpoints, Prometheus metrics integration, and is designed for Kubernetes deployment and CI/CD pipeline demonstrations.

## Features

- Express.js web server
- Prometheus metrics integration
- Readiness and liveness probe endpoints
- Customizable port via environment variable

## Prerequisites

- Node.js (v22.1.0)

## Development

```bash
npm ci          # install dependencies
npm start       # run the server (PORT defaults to 8080)
npm test        # run unit tests (node:test + supertest)
npm run lint    # run ESLint
```

## CI

GitHub Actions ([.github/workflows/ci.yml](.github/workflows/ci.yml)) runs on every pull request to `main`:
lint, unit tests, `npm audit` (fails on high/critical), a server smoke test, and a Docker image build + container smoke test (no push).
