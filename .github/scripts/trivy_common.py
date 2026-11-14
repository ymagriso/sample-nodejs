#!/usr/bin/env python3
"""Shared helpers for Trivy scanning, report parsing, and GitHub Actions outputs."""

import os
import subprocess

SKIP_DIRS = {".git", ".github", "node_modules"}


def run_trivy_formats(
    base_cmd: list[str],
    sarif_output: str,
    json_output: str,
) -> None:
    """Execute a Trivy command producing both SARIF and JSON reports."""
    for fmt, out_file in (("sarif", sarif_output), ("json", json_output)):
        subprocess.run(
            [*base_cmd, "--format", fmt, "--output", out_file, "--exit-code", "0"],
            check=True,
        )


def parse_vulnerabilities(report: dict) -> tuple[int, int, int, int, list[tuple]]:
    """Parse Vulnerabilities from a Trivy JSON report into counts and sorted rows."""
    crit = 0
    high = 0
    fixable = 0
    fixable_crit = 0
    vulns_list = []

    for res in report.get("Results") or []:
        target = res.get("Target", "")
        for v in res.get("Vulnerabilities") or []:
            sev = v.get("Severity", "")
            fixed_ver = v.get("FixedVersion", "")
            if sev == "CRITICAL":
                crit += 1
                if fixed_ver:
                    fixable_crit += 1
            elif sev == "HIGH":
                high += 1
            if fixed_ver:
                fixable += 1
            vulns_list.append(
                (
                    sev,
                    v.get("VulnerabilityID", ""),
                    v.get("PkgName", ""),
                    v.get("InstalledVersion", ""),
                    fixed_ver or "*(unfixed)*",
                    (v.get("Title") or "").replace("|", "\\|")[:80],
                    target,
                )
            )

    vulns_list.sort(key=lambda x: (0 if x[0] == "CRITICAL" else 1, x[1], x[2]))
    return crit, high, fixable, fixable_crit, vulns_list


def format_vuln_details(
    label: str,
    crit: int,
    high: int,
    fixable: int,
    vulns_list: list[tuple],
    include_target: bool = False,
) -> str:
    """Format an expandable HTML <details> block for a list of vulnerabilities."""
    lines = [
        f"<details><summary><b>{label}</b> — {crit} Critical, {high} High ({fixable} fixable)</summary>\n\n",
    ]
    if include_target:
        lines.append("| Severity | Target | CVE | Package | Installed | Fixed Version | Title |\n")
        lines.append("| :--- | :--- | :--- | :--- | :--- | :--- | :--- |\n")
        for sev, cve, pkg, inst, fixv, title, target in vulns_list[:40]:
            lines.append(
                f"| **{sev}** | `{target}` | `{cve}` | `{pkg}` | `{inst}` | `{fixv}` | {title} |\n"
            )
    else:
        lines.append("| Severity | CVE | Package | Installed | Fixed Version | Title |\n")
        lines.append("| :--- | :--- | :--- | :--- | :--- | :--- |\n")
        for sev, cve, pkg, inst, fixv, title, _ in vulns_list[:40]:
            lines.append(
                f"| **{sev}** | `{cve}` | `{pkg}` | `{inst}` | `{fixv}` | {title} |\n"
            )

    if len(vulns_list) > 40:
        lines.append(f"\n*...and {len(vulns_list) - 40} more findings.*\n")
    lines.append("\n</details>\n")
    return "".join(lines)


def publish_summary_and_outputs(
    summary_md: str, outputs: dict[str, int | str]
) -> None:
    """Print Markdown summary and write GITHUB_STEP_SUMMARY and GITHUB_OUTPUT if set."""
    print(summary_md, flush=True)

    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        with open(summary_path, "a", encoding="utf-8") as out:
            out.write(summary_md)

    output_path = os.environ.get("GITHUB_OUTPUT")
    if output_path and outputs:
        with open(output_path, "a", encoding="utf-8") as gh_out:
            for key, value in outputs.items():
                gh_out.write(f"{key}={value}\n")
