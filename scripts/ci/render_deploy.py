"""One hook request; poll Render for a verified Live deployment at the tested SHA."""
import argparse
import json
import os
from pathlib import Path
import re
import time
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

import httpx

TERMINAL_FAILURES = {"build_failed", "pre_deploy_failed", "update_failed", "canceled", "deactivated"}


def hook_for_sha(url: str, sha: str, service: str) -> str:
    parts = urlsplit(url)
    if parts.scheme != "https" or parts.hostname != "api.render.com" or parts.path != f"/deploy/{service}" or parts.fragment or parts.username:
        raise ValueError("invalid_deploy_hook")
    query = dict(parse_qsl(parts.query))
    if not query.get("key") or not re.fullmatch(r"[a-f0-9]{40}", sha):
        raise ValueError("invalid_hook_or_sha")
    query["ref"] = sha
    return urlunsplit((parts.scheme, parts.netloc, parts.path, urlencode(query), ""))


def deploy(client, hook: str, token: str, service: str, sha: str, timeout: int = 1500) -> dict:
    endpoint = f"https://api.render.com/v1/services/{service}/deploys"
    headers = {"Authorization": f"Bearer {token}"}
    # Snapshot before POST avoids mistaking an earlier Live deployment at the same SHA for this run.
    before = client.get(endpoint, headers=headers, params={"limit": 20})
    before.raise_for_status()
    old_ids = {row["deploy"]["id"] for row in before.json()}
    deploy_id = None
    try:
        response = client.post(hook_for_sha(hook, sha, service))
        if response.status_code not in (200, 202):
            raise ValueError("hook_rejected")
        if response.content:
            payload = response.json()
            deploy_id = payload.get("deploy", {}).get("id") or payload.get("id")
    except (httpx.TimeoutException, httpx.NetworkError):
        pass  # Uncertain POST: discover the deploy; never blindly POST again.
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        response = client.get(endpoint + (f"/{deploy_id}" if deploy_id else ""), headers=headers, params=None if deploy_id else {"limit": 20})
        if response.status_code == 429:
            time.sleep(min(60, max(5, int(response.headers.get("Retry-After", "15")))))
            continue
        response.raise_for_status()
        candidates = [response.json()] if deploy_id else [r["deploy"] for r in response.json()]
        for candidate in candidates:
            commit = candidate.get("commit", {}).get("id")
            if not deploy_id and (candidate.get("id") in old_ids or commit != sha):
                continue
            if commit != sha:
                raise ValueError("deployment_sha_mismatch")
            deploy_id = candidate["id"]
            state = candidate.get("status")
            if state == "live":
                return {"sha": sha, "serviceId": service, "deployId": deploy_id, "state": "pass", "live": True}
            if state in TERMINAL_FAILURES:
                raise ValueError("deployment_failed")
        time.sleep(10)
    raise ValueError("deployment_timeout_or_unverified_queue")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--service", required=True)
    parser.add_argument("--sha", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    result = {"sha": args.sha, "serviceId": args.service, "state": "fail", "live": False}
    try:
        if not re.fullmatch(r"srv-[a-z0-9]+", args.service):
            raise ValueError("invalid_service_id")
        inventory = json.loads(Path("deploy/services.json").read_text())
        allowed = {entry.get("serviceId") or os.getenv(entry.get("serviceIdEnv", "")) for entry in inventory["services"].values() if entry.get("kind") in {"web", "static"}}
        if args.service not in allowed:
            raise ValueError("service_not_in_inventory")
        with httpx.Client(timeout=30, follow_redirects=False) as client:
            result = deploy(client, os.environ["RENDER_DEPLOY_HOOK"], os.environ["RENDER_API_KEY"], args.service, args.sha)
    except Exception as error:
        result["reason"] = str(error) if isinstance(error, ValueError) else "deployment_request_failed"
    Path(args.output).write_text(json.dumps(result, indent=2), encoding="utf-8")
    raise SystemExit(0 if result["state"] == "pass" else 1)


if __name__ == "__main__":
    main()
