"""Reject absent, empty, failed or unexpectedly skipped TRX/JUnit reports."""
import argparse
import json
from pathlib import Path
import xml.etree.ElementTree as ET


def inspect_report(path: Path, allow_skips: int = 0) -> dict:
    root = ET.parse(path).getroot()
    if root.tag.endswith("TestRun"):
        results = [node for node in root.iter() if node.tag.endswith("UnitTestResult")]
        failed = sum(n.get("outcome") != "Passed" for n in results if n.get("outcome") != "NotExecuted")
        skipped = sum(n.get("outcome") == "NotExecuted" for n in results)
        total = len(results)
    else:
        results = list(root.iter("testcase"))
        failed = sum(n.find("failure") is not None or n.find("error") is not None for n in results)
        skipped = sum(n.find("skipped") is not None for n in results)
        total = len(results)
    return {"file": path.name, "total": total, "failed": failed, "skipped": skipped,
            "state": "pass" if total > 0 and failed == 0 and skipped <= allow_skips else "fail"}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("reports", nargs="+")
    parser.add_argument("--allow-skips", type=int, default=0)
    args = parser.parse_args()
    try:
        reports = [inspect_report(Path(p), args.allow_skips) for p in args.reports]
        print(json.dumps(reports))
        return 0 if all(r["state"] == "pass" for r in reports) else 1
    except (OSError, ET.ParseError):
        print('{"state":"fail","reason":"missing_or_invalid_report"}')
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
