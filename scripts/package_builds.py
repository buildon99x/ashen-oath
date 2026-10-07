#!/usr/bin/env python3
"""Create self-contained platform ZIPs and their SHA-256 manifest."""
import hashlib
import pathlib
import sys
import zipfile

out = pathlib.Path(sys.argv[1]).resolve()
packages = []
for platform in ("windows", "linux"):
    name = "ASHEN-OATH-" + platform + "-x64.zip"
    path = out / name
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for member in sorted((out / platform).iterdir()):
            if member.is_file():
                archive.write(member, f"ASHEN-OATH-{platform}-x64/{member.name}")
    with zipfile.ZipFile(path) as archive:
        bad = archive.testzip()
        if bad:
            raise RuntimeError("Package CRC failure: " + bad)
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    packages.append(f"{digest}  {name}")
    print(f"{name}: {path.stat().st_size:,} bytes, SHA256 {digest}")
(out / "SHA256SUMS.txt").write_text("\n".join(packages) + "\n")
