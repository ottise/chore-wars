import argparse
from datetime import date
import json
from pathlib import Path


def audit(report, exceptions, today):
    findings = []
    for project in report.get("projects", []):
        for framework in project.get("frameworks", []):
            for package in framework.get("topLevelPackages", []) + framework.get("transitivePackages", []):
                for vulnerability in package.get("vulnerabilities", []):
                    finding = {"package": package["id"], "version": package["resolvedVersion"], "advisory": vulnerability["advisoryurl"]}
                    allowed = any(all(entry[k] == finding[k] for k in finding) and date.fromisoformat(entry["expires"]) >= today for entry in exceptions)
                    findings.append({**finding, "state": "tracked-exception" if allowed else "fail"})
    if not report.get("projects") or report.get("logs"):
        raise ValueError("audit_report_incomplete_or_feed_error")
    return findings


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("report")
    args = parser.parse_args()
    report = json.loads(Path(args.report).read_text(encoding="utf-8-sig"))
    policy = json.loads(Path("deploy/security-exceptions.json").read_text())
    findings = audit(report, policy["exceptions"], date.today())
    print(json.dumps(findings, indent=2))
    raise SystemExit(1 if any(f["state"] == "fail" for f in findings) else 0)


if __name__ == "__main__":
    main()
