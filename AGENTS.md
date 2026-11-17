# Repository Guidelines (sample-nodejs)

## CI, Release, and Deploy Workflows
- Store multi-line workflow scripts under `.github/scripts/`, and keep `GITHUB_OUTPUT` and `GITHUB_STEP_SUMMARY` writes guarded so scripts run locally.
- Keep `.github/scripts/**`, `.github/workflows/*.yml`, and `**.md` in `release.yml` `paths-ignore` so CI, script, and doc edits do not trigger a release.
- Run `tag` before `deploy` in `release.yml`, skip `deploy` on re-runs (`github.run_attempt != '1'`), and write a summary notice in `deploy-skipped`.
- In `deploy.yml`, validate semver, check `refs/tags/v<version>`, verify both OCI artifacts exist, and update `ymagriso/k8s-resources` via `actions/checkout`.
