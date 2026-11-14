#!/usr/bin/env python3
"""Scan the built application container image with Trivy and generate a Markdown summary."""

import json
import os

from trivy_common import (
    format_vuln_details,
    parse_vulnerabilities,
    publish_summary_and_outputs,
    run_trivy_formats,
)

DEFAULT_IMAGE = "sample-nodejs:trivy-scan"


def run_trivy_image(
    image: str,
    sarif_output: str = "trivy-image.sarif",
    json_output: str = "trivy-image.json",
) -> None:
    """Execute Trivy image vulnerability scan producing both SARIF and JSON reports."""
    print(f"Scanning container image: {image}", flush=True)
    run_trivy_formats(
        [
            "trivy",
            "image",
            "--scanners",
            "vuln",
            "--severity",
            "HIGH,CRITICAL",
            image,
        ],
        sarif_output=sarif_output,
        json_output=json_output,
    )


def summarize_image_report(image: str, report: dict) -> tuple[str, int]:
    """Build Markdown summary for the scanned container image and return (summary, fixable_crit)."""
    crit, high, fixable, fixable_crit, vulns_list = parse_vulnerabilities(report)

    status = (
        "✅ Clean"
        if (crit == 0 and high == 0)
        else ("🔴 Critical" if crit > 0 else "🟠 High")
    )

    lines = [
        "## 📦 Trivy Container Image Vulnerability Scan (`trivy image`)\n\n",
        f"- **Image scanned:** `{image}`\n",
        f"- **Total findings:** `{crit}` Critical (`{fixable_crit}` fixable), `{high}` High\n\n",
        "| Image | Critical | High | Fixable | Status |\n",
        "| :--- | :---: | :---: | :---: | :--- |\n",
        f"| `{image}` | {crit} | {high} | {fixable} | {status} |\n\n",
    ]

    if vulns_list:
        lines.append("### 🔍 Container Image Vulnerability Details\n\n")
        lines.append(
            format_vuln_details(
                image,
                crit,
                high,
                fixable,
                vulns_list,
                include_target=True,
            )
        )
        lines.append("\n")
    else:
        lines.append("> ✅ No `HIGH` or `CRITICAL` vulnerabilities detected in the container image.\n\n")

    return "".join(lines), fixable_crit


def main() -> None:
    image = os.environ.get("IMAGE_TAG", DEFAULT_IMAGE).strip() or DEFAULT_IMAGE
    run_trivy_image(image)

    with open("trivy-image.json", encoding="utf-8") as f:
        report = json.load(f)

    summary_md, fixable_crit = summarize_image_report(image, report)
    publish_summary_and_outputs(summary_md, {"fixable_critical": fixable_crit})


if __name__ == "__main__":
    main()
