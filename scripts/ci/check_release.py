import argparse
import json
from pathlib import Path


def evaluate(inventory: dict, components: dict, profile: str) -> dict:
    required = inventory["profiles"][profile]
    states = {name: components.get(name, {"state": "unverified", "reason": "no_evidence"}) for name in inventory["services"]}
    passed = all(states[name].get("state") == "pass" for name in required)
    return {"profile": profile, "state": "pass" if passed else "fail", "components": states,
            "fullSystemVerified": all(states[name].get("state") == "pass" for name in inventory["profiles"]["full"])}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--inventory", default="deploy/services.json")
    parser.add_argument("--reports", required=True)
    parser.add_argument("--profile", choices=["core", "full"], default="core")
    parser.add_argument("--sha", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    components = {}
    for path in Path(args.reports).rglob("*.json"):
        report = json.loads(path.read_text())
        if report.get("sha") != args.sha:
            continue
        if path.stem == "schema":
            components.update(report["components"])
        if path.stem.startswith("smoke-"):
            name = path.stem.removeprefix("smoke-")
            deploy_path = path.with_name("deploy-" + name + ".json")
            deployed = json.loads(deploy_path.read_text()) if deploy_path.exists() else {}
            components[name] = report if deployed.get("state") == "pass" and deployed.get("sha") == args.sha else {"state": "unverified", "reason": "no_verified_deployment"}
            for entry in report.get("dependencies", []):
                name = "ai-service-auth" if entry["name"] == "ai" else entry["name"]
                if name in {"backend", "ai", "frontend"}:
                    continue
                if name not in components or entry["state"] != "pass":
                    components[name] = entry
    workers = [v for k, v in components.items() if k.startswith("worker:")]
    components["workers"] = {"state": "pass" if workers and all(v["state"] == "pass" for v in workers) else "unverified"}
    result = evaluate(json.loads(Path(args.inventory).read_text()), components, args.profile)
    result["sha"] = args.sha
    Path(args.output).write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(f"Release {args.profile}: {result['state']}; full system verified: {result['fullSystemVerified']}")
    raise SystemExit(0 if result["state"] == "pass" else 1)


if __name__ == "__main__":
    main()
