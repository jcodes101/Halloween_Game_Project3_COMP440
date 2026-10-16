#!/usr/bin/env python3
"""Download only Godot's single-threaded Web export templates from the official TPZ.

The official all-platform export-template archive is very large. This script uses
HTTP byte ranges to extract just version.txt and the two web_nothreads templates.
It uses only Python's standard library and validates ZIP sizes and CRCs.
"""

from __future__ import annotations

import argparse
import binascii
import io
import re
import struct
import urllib.request
import zipfile
import zlib
from pathlib import Path

USER_AGENT = "TheFamiliar-Godot-Web-Builder/1.0"
RANGE_SIZE = 64 * 1024
TARGETS = {
    "templates/version.txt": "version.txt",
    "templates/web_nothreads_debug.zip": "web_nothreads_debug.zip",
    "templates/web_nothreads_release.zip": "web_nothreads_release.zip",
}


def fetch_range(url: str, header: str, expected_size: int | None = None) -> tuple[bytes, int]:
    request = urllib.request.Request(
        url,
        headers={"Range": header, "User-Agent": USER_AGENT},
    )
    with urllib.request.urlopen(request, timeout=120) as response:
        if response.status != 206:
            raise RuntimeError(f"Server ignored the requested byte range (HTTP {response.status}).")
        content_range = response.headers.get("Content-Range", "")
        match = re.fullmatch(r"bytes (\d+)-(\d+)/(\d+)", content_range)
        if not match:
            raise RuntimeError(f"Unexpected Content-Range header: {content_range!r}")
        start, end, total = map(int, match.groups())
        data = response.read()
    if len(data) != end - start + 1:
        raise RuntimeError(f"Incomplete range response: received {len(data)} bytes for {content_range}.")
    if expected_size is not None and total != expected_size:
        raise RuntimeError(f"Archive size changed during download ({expected_size} != {total}).")
    return data, total


def read_central_directory(url: str) -> tuple[bytes, int, int]:
    # GitHub's release-asset CDN supports explicit byte ranges but may reject
    # the suffix form (``bytes=-N``), so learn the asset size with a one-byte
    # probe before requesting its final range.
    _, total_size = fetch_range(url, "bytes=0-0")
    tail_start = max(0, total_size - RANGE_SIZE)
    tail, _ = fetch_range(url, f"bytes={tail_start}-{total_size - 1}", total_size)
    eocd_offset = tail.rfind(b"PK\x05\x06")
    if eocd_offset < 0 or eocd_offset + 22 > len(tail):
        raise RuntimeError("The archive end-of-directory record was not found in its final 64 KB.")
    eocd = struct.unpack_from("<4s4H2LH", tail, eocd_offset)
    _, disk, cd_disk, disk_entries, entry_count, cd_size, cd_offset, comment_size = eocd
    if disk != 0 or cd_disk != 0 or disk_entries != entry_count:
        raise RuntimeError("Multi-disk or ZIP64 template archives are not supported by this downloader.")
    if entry_count == 0xFFFF or cd_size == 0xFFFFFFFF or cd_offset == 0xFFFFFFFF:
        raise RuntimeError("ZIP64 template archives are not supported by this downloader.")
    if eocd_offset + 22 + comment_size > len(tail):
        raise RuntimeError("The archive comment is truncated.")
    if cd_size > 32 * 1024 * 1024:
        raise RuntimeError(f"Unexpectedly large central directory: {cd_size} bytes.")
    central, _ = fetch_range(url, f"bytes={cd_offset}-{cd_offset + cd_size - 1}", total_size)
    return central, total_size, entry_count


def find_targets(central: bytes, expected_count: int) -> dict[str, tuple[int, ...]]:
    found: dict[str, tuple[int, ...]] = {}
    offset = 0
    parsed = 0
    fixed = struct.Struct("<4s6H3I5H2I")
    while offset < len(central):
        if offset + fixed.size > len(central):
            raise RuntimeError("The ZIP central-directory entry is truncated.")
        fields = fixed.unpack_from(central, offset)
        if fields[0] != b"PK\x01\x02":
            raise RuntimeError(f"Invalid ZIP central-directory signature at byte {offset}.")
        flags, method = fields[3], fields[4]
        crc, compressed_size, uncompressed_size = fields[7:10]
        name_size, extra_size, comment_size = fields[10:13]
        local_header_offset = fields[16]
        name_start = offset + fixed.size
        name_end = name_start + name_size
        if name_end + extra_size + comment_size > len(central):
            raise RuntimeError("The ZIP central-directory filename or metadata is truncated.")
        name_bytes = central[name_start:name_end]
        encoding = "utf-8" if flags & 0x800 else "cp437"
        name = name_bytes.decode(encoding)
        if name in TARGETS:
            if compressed_size == 0xFFFFFFFF or uncompressed_size == 0xFFFFFFFF or local_header_offset == 0xFFFFFFFF:
                raise RuntimeError(f"ZIP64 metadata is not supported for {name}.")
            if flags & 0x1:
                raise RuntimeError(f"Encrypted template entry is unsupported: {name}.")
            found[name] = (
                flags,
                method,
                crc,
                compressed_size,
                uncompressed_size,
                local_header_offset,
            )
        offset = name_end + extra_size + comment_size
        parsed += 1
    if parsed != expected_count:
        raise RuntimeError(f"Parsed {parsed} ZIP entries; expected {expected_count}.")
    missing = set(TARGETS) - set(found)
    if missing:
        raise RuntimeError("Official TPZ is missing expected files: " + ", ".join(sorted(missing)))
    return found


def extract_entry(url: str, total_size: int, metadata: tuple[int, ...]) -> bytes:
    flags, method, expected_crc, compressed_size, uncompressed_size, local_offset = metadata
    header, _ = fetch_range(url, f"bytes={local_offset}-{local_offset + 29}", total_size)
    local = struct.unpack("<4s5H3I2H", header)
    if local[0] != b"PK\x03\x04":
        raise RuntimeError(f"Invalid ZIP local-header signature at byte {local_offset}.")
    local_flags, local_method = local[2], local[3]
    name_size, extra_size = local[9], local[10]
    if local_method != method or local_flags != flags:
        raise RuntimeError("ZIP local and central directory metadata disagree.")
    payload_offset = local_offset + 30 + name_size + extra_size
    compressed, _ = fetch_range(
        url,
        f"bytes={payload_offset}-{payload_offset + compressed_size - 1}",
        total_size,
    )
    if method == 0:
        data = compressed
    elif method == 8:
        data = zlib.decompress(compressed, -15)
    else:
        raise RuntimeError(f"Unsupported outer ZIP compression method: {method}.")
    if len(data) != uncompressed_size:
        raise RuntimeError(f"Extracted entry size mismatch ({len(data)} != {uncompressed_size}).")
    if binascii.crc32(data) & 0xFFFFFFFF != expected_crc:
        raise RuntimeError("Extracted entry failed its ZIP CRC check.")
    return data


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", default="4.7.2", help="Godot stable version, for example 4.7.2")
    parser.add_argument("--output", required=True, type=Path, help="Godot export_templates/<version>.stable directory")
    args = parser.parse_args()
    if not re.fullmatch(r"\d+\.\d+\.\d+", args.version):
        parser.error("--version must have the form major.minor.patch")

    url = (
        "https://github.com/godotengine/godot-builds/releases/download/"
        f"{args.version}-stable/Godot_v{args.version}-stable_export_templates.tpz"
    )
    central, total_size, entry_count = read_central_directory(url)
    entries = find_targets(central, entry_count)
    args.output.mkdir(parents=True, exist_ok=True)

    version_data = extract_entry(url, total_size, entries["templates/version.txt"])
    version_text = version_data.decode("utf-8").strip()
    if version_text != f"{args.version}.stable" and not version_text.startswith(f"{args.version}.stable."):
        raise RuntimeError(f"Template version mismatch: expected {args.version}.stable, found {version_text!r}.")
    (args.output / "version.txt").write_bytes(version_data)

    for archive_name in ("web_nothreads_debug.zip", "web_nothreads_release.zip"):
        path = f"templates/{archive_name}"
        payload = extract_entry(url, total_size, entries[path])
        with zipfile.ZipFile(io.BytesIO(payload)) as template:
            corrupt_entry = template.testzip()
            if corrupt_entry is not None:
                raise RuntimeError(f"{archive_name} failed its inner ZIP CRC check at {corrupt_entry}.")
            if not any(name.endswith(".wasm") for name in template.namelist()):
                raise RuntimeError(f"{archive_name} does not contain a WebAssembly module.")
        (args.output / archive_name).write_bytes(payload)
        print(f"Installed {archive_name}: {len(payload):,} bytes ({version_text}).")
    print(f"Installed matching Web templates from the official {args.version} stable archive ({total_size:,} bytes total).")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        raise SystemExit(f"Godot Web template download failed: {error}") from error
