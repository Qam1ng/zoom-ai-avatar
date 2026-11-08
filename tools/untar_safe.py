"""Unpack a .tar.gz after checking that every entry stays inside the target folder.

usage: untar_safe.py <archive.tar.gz> <target_dir>
"""
import sys
import tarfile

src, dst = sys.argv[1], sys.argv[2]
with tarfile.open(src) as t:
    members = t.getmembers()
    bad = [m.name for m in members
           if m.name.startswith(("/", "\\")) or ".." in m.name.replace("\\", "/").split("/")
           or not (m.isdir() or m.isfile())]
    if bad:
        raise SystemExit(f"archive has unexpected entries, not unpacking: {bad[:5]}")
    t.extractall(dst, filter="data")
print(f"unpacked {len(members)} entries into {dst}")
