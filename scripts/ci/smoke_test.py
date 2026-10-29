import argparse
import json
import os
from pathlib import Path
import time
from urllib.parse import urlsplit

import httpx


def verify(client, base: str, sha: str, kind: str, attempts=60, interval=10) -> dict:
    uri = urlsplit(base)
    if uri.scheme != "https" or not uri.hostname or uri.username or uri.query or uri.fragment:
        raise ValueError("https_service_url_required")
    base = base.rstrip("/")
    stable = 0
    for _ in range(attempts):
        try:
            version = client.get(base + ("/deploy-version.json" if kind == "frontend" else "/health/version"))
            if version.status_code != 200 or version.json().get("sha") != sha:
                raise ValueError("wrong_version")
            if kind == "frontend":
                config = version.json()
                if config.get("sameOrigin") is not False or not config.get("api", "").startswith("https://") or not config.get("hubs", "").startswith("https://"):
                    raise ValueError("frontend_cloud_configuration_invalid")
                bootstrap = client.get(base + "/flutter_bootstrap.js")
                route = client.get(base + "/index.html")
                if bootstrap.status_code != 200 or "<html" in bootstrap.text.lower() or route.status_code != 200:
                    raise ValueError("frontend_assets_unavailable")
            ready = client.get(base + ("/" if kind == "frontend" else "/health/ready"))
            body_ok = ("flutter_bootstrap.js" in ready.text) if kind == "frontend" else (
                ready.text.strip() == "Healthy" or ready.json().get("status") == "ready")
            if ready.status_code != 200 or not body_ok:
                raise ValueError("not_ready")
            stable += 1
            if stable >= 3:
                if kind == "backend":
                    boundary = client.get(base + "/api/deployment/health")
                    if boundary.status_code != 401:
                        raise ValueError("deployment_health_auth_boundary_failed")
                    google = client.post(base + "/api/auth/google", json={"idToken": "invalid-deployment-route-probe"})
                    if google.status_code not in (400, 403, 409):
                        raise ValueError("google_auth_route_missing_or_broken")
                return {"sha": sha, "state": "pass", "stableReadiness": stable}
        except (httpx.HTTPError, ValueError):
            stable = 0
        time.sleep(interval)
    return {"sha": sha, "state": "fail", "reason": "readiness_version_or_auth_timeout"}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", required=True)
    parser.add_argument("--sha", required=True)
    parser.add_argument("--kind", choices=["backend", "ai", "frontend"], required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    with httpx.Client(timeout=10, follow_redirects=False) as client:
        result = verify(client, args.url, args.sha, args.kind)
        if args.kind == "backend" and result["state"] == "pass":
            key = os.getenv("DEPLOYMENT_HEALTH_KEY", "")
            if len(key) < 32:
                result = {"sha": args.sha, "state": "fail", "reason": "deployment_health_key_missing"}
            else:
                response = client.get(args.url.rstrip("/") + "/api/deployment/health", headers={"X-Deployment-Key": key}, timeout=20)
                if response.status_code != 200:
                    result["state"] = "fail"
                else:
                    result["dependencies"] = response.json().get("components", [])
    Path(args.output).write_text(json.dumps(result, indent=2), encoding="utf-8")
    raise SystemExit(0 if result["state"] == "pass" else 1)


if __name__ == "__main__":
    main()
