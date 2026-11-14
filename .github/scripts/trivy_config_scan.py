#!/usr/bin/env python3
"""Run Trivy IaC, Dockerfile, and Helm chart configuration scan and generate a Markdown summary."""

import json
import os

from trivy_common import SKIP_DIRS, publish_summary_and_outputs, run_trivy_formats


def get_scanned_items(root_dir: str = ".", skip_dirs: set[str] = SKIP_DIRS) -> list[str]:
    """Return formatted list of top-level directories and Dockerfiles evaluated by Trivy config."""
    items = []
    for entry in sorted(os.listdir(root_dir)):
        if entry in skip_dirs or entry.startswith("."):
            continue
        full_path = os.path.join(root_dir, entry)
        if os.path.isdir(full_path):
            items.append(f"`{entry}/`")
        elif entry == "Dockerfile" or entry.startswith("Dockerfile."):
            items.append(f"`{entry}`")
    return items


def run_trivy_config(
    target_dir: str = ".",
    sarif_output: str = "trivy-config.sarif",
    json_output: str = "trivy-config.json",
    skip_dirs: set[str] = SKIP_DIRS,
) -> None:
    """Execute Trivy config scan producing both SARIF and JSON reports."""
    skip_arg = ",".join(sorted(skip_dirs))
    print("Running Trivy Dockerfile & Helm chart misconfiguration scan...", flush=True)
    run_trivy_formats(
        [
            "trivy",
            "config",
            "--severity",
            "HIGH,CRITICAL",
            "--skip-dirs",
            skip_arg,
            target_dir,
        ],
        sarif_output=sarif_output,
        json_output=json_output,
    )


def summarize_config_report(
    data: dict, scanned_items: list[str]
) -> tuple[str, int, int]:
    """Parse Trivy config JSON report and return (markdown_summary, crit_count, high_count)."""
    results = data.get("Results") or []
    findings = []
    crit_count = 0
    high_count = 0

    for res in results:
        target = res.get("Target", "")
        for m in res.get("Misconfigurations") or []:
            sev = m.get("Severity", "UNKNOWN")
            if sev == "CRITICAL":
                crit_count += 1
            elif sev == "HIGH":
                high_count += 1
            findings.append((sev, target, m.get("ID", ""), m.get("Title", "")))

    lines = [
        "## 🛡️ Trivy Dockerfile & Helm Chart Scan (`trivy config`)\n\n",
        f"- **Scanned targets:** {', '.join(scanned_items) or '`.`'} (`{len(results)}` config targets evaluated)\n",
        f"- **Findings (`CRITICAL` / `HIGH`):** `{crit_count}` Critical, `{high_count}` High\n\n",
    ]
    if findings:
        lines.append("| Severity | Target | Rule ID | Title |\n")
        lines.append("| :--- | :--- | :--- | :--- |\n")
        for sev, target, rid, title in findings[:50]:
            safe_title = title.replace("|", "\\|")
            lines.append(f"| **{sev}** | `{target}` | `{rid}` | {safe_title} |\n")
        lines.append("\n")
    else:
        lines.append("> ✅ No `HIGH` or `CRITICAL` Dockerfile or Helm misconfigurations detected.\n\n")

    return "".join(lines), crit_count, high_count


def main() -> None:
    run_trivy_config()
    scanned_items = get_scanned_items()

    with open("trivy-config.json", encoding="utf-8") as f:
        data = json.load(f)

    summary_md, crit_count, _ = summarize_config_report(data, scanned_items)
    publish_summary_and_outputs(summary_md, {"config_critical": crit_count})


if __name__ == "__main__":
    main()
