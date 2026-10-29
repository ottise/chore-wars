import json
from datetime import date
from pathlib import Path

import httpx
import pytest

from scripts.ci.check_release import evaluate
from scripts.ci.check_results import inspect_report
from scripts.ci.migration_manifest import ROOT, manifest
from scripts.ci.render_deploy import hook_for_sha, deploy
from scripts.ci.smoke_test import verify
from scripts.ci.audit_dependencies import audit

SHA = "a" * 40


def test_missing_empty_failed_and_skipped_reports_fail(tmp_path):
    path = tmp_path / "report.xml"
    for content in ('<testsuite/>', '<testsuite><testcase><skipped/></testcase></testsuite>', '<testsuite><testcase><failure/></testcase></testsuite>'):
        path.write_text(content)
        assert inspect_report(path)["state"] == "fail"
    path.write_text('<testsuite><testcase name="real"/></testsuite>')
    assert inspect_report(path)["state"] == "pass"
    with pytest.raises(FileNotFoundError):
        inspect_report(tmp_path / "absent")


def test_manifest_has_real_migrations_and_heads():
    value = manifest(ROOT, SHA)
    assert len(value["core"]) >= 27
    assert "bf301aab6012" in value["ai_heads"]
    assert all(len(r["sha256"]) == 64 for r in value["core"])


def test_hook_host_and_ref_are_strict():
    result = hook_for_sha("https://api.render.com/deploy/srv-test?key=private&ref=old", SHA, "srv-test")
    assert "ref=" + SHA in result and "ref=old" not in result
    with pytest.raises(ValueError):
        hook_for_sha("https://evil.example/deploy/srv-test?key=x", SHA, "srv-test")


def test_queued_hook_is_not_live_until_verified():
    calls = []
    def route(request):
        calls.append(request.method)
        if request.method == "POST":
            return httpx.Response(202)
        if len(calls) == 1:
            return httpx.Response(200, json=[])
        return httpx.Response(200, json=[{"deploy": {"id": "dep-new", "commit": {"id": SHA}, "status": "live"}}])
    with httpx.Client(transport=httpx.MockTransport(route)) as client:
        result = deploy(client, "https://api.render.com/deploy/srv-test?key=x", "secret", "srv-test", SHA, timeout=1)
    assert result["live"] and calls.count("POST") == 1


def test_uncertain_hook_timeout_is_discovered_without_second_post():
    calls = []
    def route(request):
        calls.append(request.method)
        if request.method == "POST":
            raise httpx.ReadTimeout("uncertain", request=request)
        rows = [] if len(calls) == 1 else [{"deploy": {"id": "dep-new", "commit": {"id": SHA}, "status": "live"}}]
        return httpx.Response(200, json=rows)
    with httpx.Client(transport=httpx.MockTransport(route)) as client:
        result = deploy(client, "https://api.render.com/deploy/srv-test?key=x", "secret", "srv-test", SHA, timeout=1)
    assert result["live"] and calls.count("POST") == 1


def test_hook_acceptance_cannot_hide_wrong_sha():
    calls = []
    def route(request):
        calls.append(request.method)
        if request.method == "POST":
            return httpx.Response(200, json={"deploy": {"id": "dep-wrong"}})
        if len(calls) == 1:
            return httpx.Response(200, json=[])
        return httpx.Response(200, json={"id": "dep-wrong", "commit": {"id": "b" * 40}, "status": "live"})
    with httpx.Client(transport=httpx.MockTransport(route)) as client:
        with pytest.raises(ValueError, match="deployment_sha_mismatch"):
            deploy(client, "https://api.render.com/deploy/srv-test?key=x", "secret", "srv-test", SHA, timeout=1)


def test_old_version_html_and_redirect_never_pass():
    for status, body in [(200, '{"sha":"old"}'), (200, '<html>gateway</html>'), (302, '')]:
        with httpx.Client(transport=httpx.MockTransport(lambda _: httpx.Response(status, text=body))) as client:
            assert verify(client, "https://example.com", SHA, "ai", attempts=3, interval=0)["state"] == "fail"


def test_three_stable_samples_and_auth_boundary():
    def route(request):
        if request.url.path == "/health/version":
            return httpx.Response(200, json={"sha": SHA})
        if request.url.path == "/health/ready":
            return httpx.Response(200, text="Healthy")
        if request.url.path == "/api/auth/google":
            return httpx.Response(403)
        return httpx.Response(401)
    with httpx.Client(transport=httpx.MockTransport(route)) as client:
        assert verify(client, "https://example.com", SHA, "backend", attempts=3, interval=0)["state"] == "pass"


def test_backend_health_cannot_hide_missing_google_endpoint():
    def route(request):
        if request.url.path == "/health/version":
            return httpx.Response(200, json={"sha": SHA})
        if request.url.path == "/health/ready":
            return httpx.Response(200, text="Healthy")
        if request.url.path == "/api/auth/google":
            return httpx.Response(404)
        return httpx.Response(401)
    with httpx.Client(transport=httpx.MockTransport(route)) as client:
        assert verify(client, "https://example.com", SHA, "backend", attempts=3, interval=0)["state"] == "fail"


def test_core_pass_does_not_claim_full():
    inventory = json.loads((ROOT / "deploy/services.json").read_text())
    components = {name: {"state": "pass"} for name in inventory["profiles"]["core"]}
    result = evaluate(inventory, components, "core")
    assert result["state"] == "pass" and not result["fullSystemVerified"]
    assert evaluate(inventory, components, "full")["state"] == "fail"


def test_security_exception_cannot_hide_new_or_expired_advisory():
    report = {"projects": [{"frameworks": [{"topLevelPackages": [{"id": "Mapping", "resolvedVersion": "1", "vulnerabilities": [{"advisoryurl": "https://advisory"}]}]}]}]}
    exception = [{"package": "Mapping", "version": "1", "advisory": "https://advisory", "expires": "2026-11-11"}]
    assert audit(report, exception, date(2026, 10, 28))[0]["state"] == "tracked-exception"
    assert audit(report, exception, date(2026, 11, 12))[0]["state"] == "fail"
    assert audit(report, [], date(2026, 10, 28))[0]["state"] == "fail"
