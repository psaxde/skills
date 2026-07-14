#!/usr/bin/env python3
"""Validate a Pinterest batch manifest and its final 1000x1500 creatives."""

from __future__ import annotations

import argparse
import csv
import json
import re
import struct
import sys
from collections import Counter
from datetime import date
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlparse


ALLOWED_STATUSES = {
    "draft",
    "ready_for_preview",
    "approved",
    "scheduled",
    "published",
    "failed",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--images-root", type=Path)
    parser.add_argument("--require-utm", action="store_true")
    parser.add_argument("--allow-past", action="store_true")
    return parser.parse_args()


def first(row: dict[str, Any], *names: str, default: Any = "") -> Any:
    for name in names:
        value = row.get(name)
        if value not in (None, ""):
            return value
    return default


def load_manifest(path: Path) -> list[dict[str, Any]]:
    if path.suffix.lower() == ".csv":
        with path.open(newline="", encoding="utf-8-sig") as handle:
            return list(csv.DictReader(handle))

    with path.open(encoding="utf-8") as handle:
        payload = json.load(handle)
    if isinstance(payload, dict):
        payload = payload.get("pins")
    if not isinstance(payload, list) or not all(isinstance(item, dict) for item in payload):
        raise ValueError("JSON manifest must be a list or an object with a pins list")
    return payload


def normalize(row: dict[str, Any], index: int) -> dict[str, Any]:
    return {
        "id": str(first(row, "id", "pin_id", default=f"row-{index + 1}")).strip(),
        "date": str(first(row, "date", "schedule_date")).strip(),
        "time": str(first(row, "time", "schedule_time")).strip(),
        "board": str(first(row, "board")).strip(),
        "title": str(first(row, "title", "pin_title")).strip(),
        "description": str(first(row, "description", "pin_description")).strip(),
        "alt": str(first(row, "alt", "alt_text")).strip(),
        "link": str(first(row, "link", "utm_url", "destination_url")).strip(),
        "creative_file": str(first(row, "creative_file", "image", "file")).strip(),
        "status": str(first(row, "status", default="draft")).strip(),
        "ai_modified": first(row, "ai_modified", default=None),
    }


def image_dimensions(path: Path) -> tuple[int, int]:
    with path.open("rb") as handle:
        header = handle.read(32)
        if header.startswith(b"\x89PNG\r\n\x1a\n"):
            return struct.unpack(">II", header[16:24])
        if not header.startswith(b"\xff\xd8"):
            raise ValueError("unsupported image format; expected JPG or PNG")

        handle.seek(2)
        while True:
            marker_start = handle.read(1)
            if not marker_start:
                break
            if marker_start != b"\xff":
                continue
            marker = handle.read(1)
            while marker == b"\xff":
                marker = handle.read(1)
            if marker in {b"\xd8", b"\xd9"}:
                continue
            length_raw = handle.read(2)
            if len(length_raw) != 2:
                break
            length = struct.unpack(">H", length_raw)[0]
            if marker[0] in {0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF}:
                payload = handle.read(5)
                if len(payload) != 5:
                    break
                height, width = struct.unpack(">HH", payload[1:5])
                return width, height
            handle.seek(max(0, length - 2), 1)
    raise ValueError("could not read image dimensions")


def as_bool(value: Any) -> bool | None:
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        lowered = value.strip().lower()
        if lowered in {"true", "1", "yes", "ja"}:
            return True
        if lowered in {"false", "0", "no", "nein"}:
            return False
    return None


def main() -> int:
    args = parse_args()
    manifest = args.manifest.expanduser().resolve()
    images_root = (args.images_root or manifest.parent).expanduser().resolve()
    errors: list[dict[str, str]] = []
    warnings: list[dict[str, str]] = []

    def issue(level: str, pin_id: str, field: str, message: str) -> None:
        target = errors if level == "error" else warnings
        target.append({"pin": pin_id, "field": field, "message": message})

    try:
        raw_rows = load_manifest(manifest)
    except Exception as exc:
        result = {
            "ok": False,
            "manifest": str(manifest),
            "count": 0,
            "errors": [{"pin": "batch", "field": "manifest", "message": str(exc)}],
            "warnings": [],
        }
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 1

    rows = [normalize(row, index) for index, row in enumerate(raw_rows)]
    if not rows:
        issue("error", "batch", "manifest", "manifest contains no pins")

    ids = Counter(row["id"] for row in rows)
    titles = Counter(row["title"] for row in rows if row["title"])
    slots = Counter((row["date"], row["time"]) for row in rows if row["date"] and row["time"])
    links = Counter(row["link"] for row in rows if row["link"])

    for row in rows:
        pin_id = row["id"]
        if not pin_id:
            issue("error", "unknown", "id", "missing id")
        elif ids[pin_id] > 1:
            issue("error", pin_id, "id", "duplicate id")

        title = row["title"]
        if not title:
            issue("error", pin_id, "title", "missing title")
        elif len(title) > 100:
            issue("error", pin_id, "title", f"title is {len(title)} characters; maximum is 100")
        elif titles[title] > 1:
            issue("error", pin_id, "title", "duplicate title")

        description = row["description"]
        if not description:
            issue("error", pin_id, "description", "missing description")
        elif len(description) > 500:
            issue("error", pin_id, "description", f"description is {len(description)} characters; maximum is 500")
        elif len(description) < 80:
            issue("warning", pin_id, "description", "description is unusually short")

        alt = row["alt"]
        if not alt:
            issue("error", pin_id, "alt", "missing alt text")
        elif len(alt) < 20:
            issue("warning", pin_id, "alt", "alt text is unusually short")
        elif len(alt) > 500:
            issue("error", pin_id, "alt", "alt text exceeds 500 characters")

        if not row["board"]:
            issue("error", pin_id, "board", "missing board")

        try:
            scheduled_date = date.fromisoformat(row["date"])
            if not args.allow_past and scheduled_date < date.today():
                issue("warning", pin_id, "date", "schedule date is in the past")
        except ValueError:
            issue("error", pin_id, "date", "expected ISO date YYYY-MM-DD")

        if not re.fullmatch(r"(?:[01]\d|2[0-3]):[0-5]\d", row["time"]):
            issue("error", pin_id, "time", "expected 24-hour time HH:MM")
        elif slots[(row["date"], row["time"])] > 1:
            issue("warning", pin_id, "time", "another pin uses the same schedule slot")

        parsed = urlparse(row["link"])
        if parsed.scheme not in {"http", "https"} or not parsed.netloc:
            issue("error", pin_id, "link", "missing or invalid http(s) destination")
        else:
            if links[row["link"]] > 1:
                issue("warning", pin_id, "link", "another pin uses the same destination; verify the creative is materially different")
            if args.require_utm:
                query = parse_qs(parsed.query)
                for key in ("utm_source", "utm_medium", "utm_campaign", "utm_content"):
                    if not query.get(key):
                        issue("error", pin_id, "link", f"required parameter {key} is missing")

        creative = row["creative_file"]
        if not creative:
            issue("error", pin_id, "creative_file", "missing creative file path")
        else:
            creative_path = Path(creative).expanduser()
            if not creative_path.is_absolute():
                creative_path = images_root / creative_path
            if not creative_path.is_file():
                issue("error", pin_id, "creative_file", f"file not found: {creative_path}")
            else:
                try:
                    dimensions = image_dimensions(creative_path)
                    if dimensions != (1000, 1500):
                        issue("error", pin_id, "creative_file", f"expected 1000x1500, found {dimensions[0]}x{dimensions[1]}")
                except Exception as exc:
                    issue("error", pin_id, "creative_file", str(exc))

        if row["status"] not in ALLOWED_STATUSES:
            issue("error", pin_id, "status", f"unsupported status: {row['status']}")

        if as_bool(row["ai_modified"]) is None:
            issue("error", pin_id, "ai_modified", "expected true or false")

    result = {
        "ok": not errors,
        "manifest": str(manifest),
        "images_root": str(images_root),
        "count": len(rows),
        "errors": errors,
        "warnings": warnings,
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
