import argparse
import ast
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def manifest(root: Path, sha: str) -> dict:
    core = []
    for path in sorted((root / "backend/src/Infrastructure/Migrations").glob("*.cs")):
        if path.name.endswith(".Designer.cs") or not re.match(r"\d{14}_", path.name):
            continue
        designer = path.with_name(path.stem + ".Designer.cs")
        content = path.read_bytes() + (designer.read_bytes() if designer.exists() else b"")
        core.append({"id": path.stem, "sha256": hashlib.sha256(content).hexdigest()})
    revisions = []
    for path in sorted((root / "ai-service/migrations/versions").glob("*.py")):
        values = {}
        for node in ast.parse(path.read_text(encoding="utf-8-sig")).body:
            if isinstance(node, (ast.Assign, ast.AnnAssign)):
                targets = node.targets if isinstance(node, ast.Assign) else [node.target]
                for target in targets:
                    if isinstance(target, ast.Name) and target.id in {"revision", "down_revision"}:
                        values[target.id] = ast.literal_eval(node.value)
        if "revision" in values:
            revisions.append({"id": values["revision"], "parent": values.get("down_revision"), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    parents = {p for r in revisions for p in (r["parent"] if isinstance(r["parent"], (list, tuple)) else [r["parent"]]) if p}
    heads = sorted(r["id"] for r in revisions if r["id"] not in parents)
    if not core or not heads:
        raise ValueError("missing_migrations")
    return {"sha": sha, "core": core, "ai": revisions, "ai_heads": heads}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default="migration-manifest.json")
    parser.add_argument("--baseline")
    parser.add_argument("--base-ref")
    args = parser.parse_args()
    sha = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    result = manifest(ROOT, sha)
    if args.base_ref and set(args.base_ref) != {"0"}:
        if not re.fullmatch(r"[a-f0-9]{40}", args.base_ref):
            raise SystemExit("Invalid baseline SHA")
        names = subprocess.check_output(["git", "ls-tree", "-r", "--name-only", args.base_ref, "backend/src/Infrastructure/Migrations", "ai-service/migrations/versions"], cwd=ROOT, text=True).splitlines()
        for name in names:
            if name.endswith("ModelSnapshot.cs") or not name.endswith((".cs", ".py")):
                continue
            previous = subprocess.check_output(["git", "show", f"{args.base_ref}:{name}"], cwd=ROOT)
            if not (ROOT / name).exists() or (ROOT / name).read_bytes().replace(b"\r\n", b"\n") != previous.replace(b"\r\n", b"\n"):
                raise SystemExit("Existing migration modified: " + name)
    if args.baseline:
        baseline = json.loads(Path(args.baseline).read_text())
        for framework in ("core", "ai"):
            current = {r["id"]: r["sha256"] for r in result[framework]}
            if any(current.get(r["id"]) != r["sha256"] for r in baseline[framework]):
                raise SystemExit("Applied migration removed or changed")
    Path(args.output).write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
