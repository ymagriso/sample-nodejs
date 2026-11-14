#!/usr/bin/env python3
"""Run Trivy repository filesystem vulnerability and secret scan and generate a Markdown summary."""

import json

from trivy_common import (
    SKIP_DIRS,
    format_vuln_details,
    parse_vulnerabilities,
    publish_summary_and_outputs,
    run_trivy_formats,
)


def run_trivy_fs(
    target_dir: str = ".",
    sarif_output: str = "trivy-fs.sarif",
    json_output: str = "trivy-fs.json",
    skip_dirs: set[str] = SKIP_DIRS,
) -> None:
    """Execute Trivy fs scan for lockfile vulnerabilities and secrets."""
    skip_arg = ",".join(sorted(skip_dirs))
    print("Running Trivy filesystem vulnerability & secret scan...", flush=True)
    run_trivy_formats(
        [
            "trivy",
            "fs",
            "--scanners",
            "vuln,secret",
            "--severity",
            "HIGH,CRITICAL",
            "--skip-dirs",
            skip_arg,
            target_dir,
        ],
        sarif_output=sarif_output,
        json_output=json_output,
    )


def parse_secrets(report: dict) -> list[tuple[str, str, str, str, int]]:
    """Extract secret findings from a Trivy fs JSON report."""
    secrets = []
    for res in report.get("Results") or []:
        target = res.get("Target", "")
        for s in res.get("Secrets") or []:
            secrets.append(
                (
                    s.get("Severity", "UNKNOWN"),
                    target,
                    s.get("RuleID", ""),
                    (s.get("Title") or "").replace("|", "\\|"),
                    int(s.get("StartLine") or 0),
                )
            )
    return secrets


def summarize_fs_report(report: dict) -> tuple[str, int, int]:
    """Build Markdown summary for Trivy fs report and return (summary, fixable_crit, secret_count)."""
    crit, high, fixable, fixable_crit, vulns_list = parse_vulnerabilities(report)
    secrets = parse_secrets(report)
    targets = [res.get("Target", "") for res in (report.get("Results") or []) if res.get("Target")]

    status = (
        "✅ Clean"
        if (crit == 0 and high == 0 and not secrets)
        else ("🔴 Critical" if (crit > 0 or secrets) else "🟠 High")
    )

    lines = [
        "## 🔍 Trivy Repository Filesystem Scan (`trivy fs`)\n\n",
        f"- **Evaluated targets:** {', '.join(f'`{t}`' for t in targets) or '`.`'}\n",
        f"- **Lockfile / Dependency CVEs:** `{crit}` Critical (`{fixable_crit}` fixable), `{high}` High ({fixable} fixable) — {status}\n",
        f"- **Secret findings (`CRITICAL` / `HIGH`):** `{len(secrets)}`\n\n",
    ]

    if vulns_list:
        lines.append(
            format_vuln_details(
                "Repository Dependency Vulnerabilities",
                crit,
                high,
                fixable,
                vulns_list,
                include_target=True,
            )
        )
        lines.append("\n")

    if secrets:
        lines.append("| Severity | File | Line | Rule ID | Title |\n")
        lines.append("| :--- | :--- | :---: | :--- | :--- |\n")
        for sev, target, rid, title, start_line in secrets[:50]:
            lines.append(f"| **{sev}** | `{target}` | {start_line} | `{rid}` | {title} |\n")
        lines.append("\n")

    if not vulns_list and not secrets:
        lines.append("> ✅ No `HIGH` or `CRITICAL` dependency CVEs or leaked secrets detected.\n\n")

    return "".join(lines), fixable_crit, len(secrets)


def main() -> None:
    run_trivy_fs()

    with open("trivy-fs.json", encoding="utf-8") as f:
        report = json.load(f)

    summary_md, fixable_crit, secret_count = summarize_fs_report(report)
    publish_summary_and_outputs(
        summary_md,
        {
            "fs_fixable_critical": fixable_crit,
            "fs_secrets": secret_count,
        },
    )


if __name__ == "__main__":
    main()
