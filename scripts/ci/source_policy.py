"""Check tracked source only. Never opens ignored local credentials."""
from pathlib import Path
import re
import subprocess

root = Path(__file__).resolve().parents[2]
paths = subprocess.check_output(["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"], cwd=root).decode().split("\0")
patterns = [r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----", r"postgres(?:ql)?://[^\s/:]+:[^\s@<>]{16,}@[^\s]+render\.com", r"https://api\.render\.com/deploy/srv-[^\s?]+\?key=[a-zA-Z0-9]{16,}"]
bad = []
for name in paths:
    path = root / name
    if not name or not path.is_file() or path.stat().st_size > 2_000_000:
        continue
    try:
        content = path.read_text(encoding="utf-8-sig")
    except UnicodeError:
        continue
    if any(re.search(pattern, content) for pattern in patterns):
        bad.append(name)
if bad:
    raise SystemExit("Possible committed credential in: " + ", ".join(bad))
print("Tracked-source credential patterns: passed")
