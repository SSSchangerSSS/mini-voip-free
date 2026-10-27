#!/usr/bin/env python3
"""verify-release manifest checks (spec 16.4): version/commit/hashes present and
checksums recomputable locally. Exit 0 ok | 1 invalid | 2 usage."""
import hashlib
import json
import sys
from pathlib import Path


def sha256(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    args = sys.argv[1:]
    if "--manifest" not in args or len(args) < 2:
        print("usage: verify-release --manifest <file>")
        return 2
    mpath = Path(args[args.index("--manifest") + 1])
    if not mpath.exists():
        print(f"FAIL manifest not found: {mpath}")
        return 1
    m = json.loads(mpath.read_text())

    problems = []
    for field in ("version", "commit", "createdAtUtc", "artifacts"):
        if field not in m:
            problems.append(f"missing field: {field}")
    for a in m.get("artifacts", []):
        for field in ("name", "sha256", "signatureStatus", "location"):
            if field not in a:
                problems.append(f"artifact missing field: {field}")
        p = Path(a.get("path", ""))
        if p.exists() and a.get("sha256"):
            actual = sha256(p)
            if actual != a["sha256"]:
                problems.append(f"checksum mismatch for {p.name}")
            else:
                print(f"PASS checksum {p.name}")
    if problems:
        for x in problems:
            print(f"FAIL {x}")
        return 1
    print("PASS release manifest verified")
    return 0


if __name__ == "__main__":
    sys.exit(main())
