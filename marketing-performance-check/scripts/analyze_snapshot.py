#!/usr/bin/env python3
"""Validate and summarize a public-safe normalized marketing snapshot."""

from __future__ import annotations

import argparse
import json
import math
import sys
from dataclasses import dataclass
from datetime import date, datetime
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError


SECRET_TERMS = {
    "access_token",
    "api_key",
    "client_secret",
    "credential",
    "credentials",
    "password",
    "private_key",
    "refresh_token",
    "secret",
    "token",
}
VALID_SOURCE_STATUSES = {"ok", "partial", "failed"}


@dataclass(frozen=True)
class Period:
    name: str
    start: date
    end: date

    @property
    def days(self) -> int:
        return (self.end - self.start).days + 1


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate periods, freshness, privacy, and metric deltas in a normalized marketing snapshot."
    )
    parser.add_argument("snapshot", type=Path, help="Path to a normalized snapshot JSON file")
    parser.add_argument(
        "--format",
        choices=("markdown", "json"),
        default="markdown",
        help="Output format (default: markdown)",
    )
    return parser.parse_args()


def contains_secret_key(value: Any, path: str = "$") -> list[str]:
    findings: list[str] = []
    if isinstance(value, dict):
        for key, child in value.items():
            normalized = str(key).lower().replace("-", "_")
            if any(term in normalized for term in SECRET_TERMS):
                findings.append(f"{path}.{key}")
            findings.extend(contains_secret_key(child, f"{path}.{key}"))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            findings.extend(contains_secret_key(child, f"{path}[{index}]"))
    return findings


def parse_iso_date(value: Any, label: str, errors: list[str]) -> date | None:
    if not isinstance(value, str):
        errors.append(f"{label} must be an ISO date string")
        return None
    try:
        return date.fromisoformat(value)
    except ValueError:
        errors.append(f"{label} must use YYYY-MM-DD")
        return None


def parse_period(name: str, value: Any, errors: list[str]) -> Period | None:
    if not isinstance(value, dict):
        errors.append(f"periods.{name} must be an object")
        return None
    start = parse_iso_date(value.get("start"), f"periods.{name}.start", errors)
    end = parse_iso_date(value.get("end"), f"periods.{name}.end", errors)
    if start is None or end is None:
        return None
    if end < start:
        errors.append(f"periods.{name}.end must not be before start")
        return None
    return Period(name=name, start=start, end=end)


def is_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def percent_change(current: float, previous: float) -> float | None:
    if previous == 0:
        return None
    return ((current - previous) / abs(previous)) * 100


def classify_change(delta: float, higher_is_better: Any) -> str:
    if delta == 0 or not isinstance(higher_is_better, bool):
        return "neutral"
    favorable = delta > 0 if higher_is_better else delta < 0
    return "favorable" if favorable else "unfavorable"


def analyze(snapshot: Any) -> dict[str, Any]:
    errors: list[str] = []
    warnings: list[str] = []
    rows: list[dict[str, Any]] = []

    if not isinstance(snapshot, dict):
        return {"valid": False, "errors": ["Snapshot root must be an object"], "warnings": [], "metrics": []}

    secret_paths = contains_secret_key(snapshot)
    if secret_paths:
        errors.append("Secret-bearing field names are forbidden: " + ", ".join(secret_paths))

    generated_at = snapshot.get("generated_at")
    if not isinstance(generated_at, str):
        errors.append("generated_at must be an ISO 8601 timestamp")
    else:
        try:
            parsed_timestamp = datetime.fromisoformat(generated_at.replace("Z", "+00:00"))
            if parsed_timestamp.tzinfo is None:
                errors.append("generated_at must include a timezone offset")
        except ValueError:
            errors.append("generated_at must be a valid ISO 8601 timestamp")

    timezone = snapshot.get("timezone")
    if not isinstance(timezone, str) or not timezone.strip():
        errors.append("timezone must be a non-empty IANA timezone name")
    else:
        try:
            ZoneInfo(timezone)
        except ZoneInfoNotFoundError:
            errors.append(f"timezone is not a recognized IANA timezone: {timezone}")

    periods_value = snapshot.get("periods")
    if not isinstance(periods_value, dict):
        errors.append("periods must be an object")
        periods_value = {}

    current = parse_period("current", periods_value.get("current"), errors)
    previous = parse_period("previous", periods_value.get("previous"), errors)
    year_over_year = None
    if "year_over_year" in periods_value:
        year_over_year = parse_period("year_over_year", periods_value.get("year_over_year"), errors)

    if current and previous:
        if current.days != previous.days:
            warnings.append(
                f"Current and previous periods differ in length ({current.days} vs {previous.days} days)"
            )
        if current.start <= previous.end and previous.start <= current.end:
            warnings.append("Current and previous periods overlap")
    if current and year_over_year and current.days != year_over_year.days:
        warnings.append(
            f"Current and year-over-year periods differ in length ({current.days} vs {year_over_year.days} days)"
        )

    sources = snapshot.get("sources")
    if not isinstance(sources, list) or not sources:
        errors.append("sources must be a non-empty array")
        sources = []

    seen_source_names: set[str] = set()
    seen_metrics: set[tuple[str, str]] = set()

    for source_index, source in enumerate(sources):
        source_path = f"sources[{source_index}]"
        if not isinstance(source, dict):
            errors.append(f"{source_path} must be an object")
            continue

        source_name = source.get("name")
        if not isinstance(source_name, str) or not source_name.strip():
            errors.append(f"{source_path}.name must be a non-empty string")
            source_name = f"source-{source_index}"
        elif source_name in seen_source_names:
            errors.append(f"Duplicate source name: {source_name}")
        seen_source_names.add(source_name)

        status = source.get("status")
        if status not in VALID_SOURCE_STATUSES:
            errors.append(f"{source_path}.status must be one of: failed, ok, partial")
        elif status != "ok":
            warnings.append(f"Source {source_name} has status {status}")

        as_of = parse_iso_date(source.get("as_of"), f"{source_path}.as_of", errors)
        if as_of and current and as_of < current.end:
            warnings.append(
                f"Source {source_name} is complete only through {as_of.isoformat()}, before the current period end {current.end.isoformat()}"
            )

        metrics = source.get("metrics")
        if not isinstance(metrics, list) or not metrics:
            warnings.append(f"Source {source_name} has no metrics")
            continue

        for metric_index, metric in enumerate(metrics):
            metric_path = f"{source_path}.metrics[{metric_index}]"
            if not isinstance(metric, dict):
                errors.append(f"{metric_path} must be an object")
                continue

            metric_name = metric.get("name")
            if not isinstance(metric_name, str) or not metric_name.strip():
                errors.append(f"{metric_path}.name must be a non-empty string")
                continue

            metric_key = (source_name, metric_name)
            if metric_key in seen_metrics:
                errors.append(f"Duplicate metric {source_name}/{metric_name}")
                continue
            seen_metrics.add(metric_key)

            current_value = metric.get("current")
            previous_value = metric.get("previous")
            if not is_number(current_value):
                errors.append(f"{metric_path}.current must be a finite number")
                continue
            if not is_number(previous_value):
                errors.append(f"{metric_path}.previous must be a finite number")
                continue

            delta = current_value - previous_value
            row: dict[str, Any] = {
                "source": source_name,
                "metric": metric_name,
                "unit": metric.get("unit", "value"),
                "current": current_value,
                "previous": previous_value,
                "absolute_change": delta,
                "percent_change": percent_change(current_value, previous_value),
                "assessment": classify_change(delta, metric.get("higher_is_better")),
            }

            yoy_value = metric.get("year_over_year")
            if yoy_value is not None:
                if is_number(yoy_value):
                    row["year_over_year"] = yoy_value
                    row["year_over_year_percent_change"] = percent_change(current_value, yoy_value)
                else:
                    errors.append(f"{metric_path}.year_over_year must be a finite number or null")

            rows.append(row)

    return {
        "valid": not errors,
        "errors": errors,
        "warnings": warnings,
        "periods": {
            name: {
                "start": period.start.isoformat(),
                "end": period.end.isoformat(),
                "days": period.days,
            }
            for name, period in (
                ("current", current),
                ("previous", previous),
                ("year_over_year", year_over_year),
            )
            if period is not None
        },
        "metrics": rows,
    }


def format_number(value: Any) -> str:
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        return f"{value:.2f}".rstrip("0").rstrip(".")
    return str(value)


def format_percent(value: float | None) -> str:
    return "n/a" if value is None else f"{value:+.1f}%"


def render_markdown(result: dict[str, Any]) -> str:
    lines = ["# Snapshot validation", ""]
    lines.append(f"**Valid:** {'yes' if result['valid'] else 'no'}")

    if result["errors"]:
        lines.extend(["", "## Errors", ""])
        lines.extend(f"- {message}" for message in result["errors"])
    if result["warnings"]:
        lines.extend(["", "## Warnings", ""])
        lines.extend(f"- {message}" for message in result["warnings"])

    if result["metrics"]:
        lines.extend(
            [
                "",
                "## Metric comparison",
                "",
                "| Source | Metric | Current | Previous | Change | Assessment |",
                "|---|---|---:|---:|---:|---|",
            ]
        )
        for row in result["metrics"]:
            lines.append(
                "| {source} | {metric} | {current} | {previous} | {change} | {assessment} |".format(
                    source=row["source"],
                    metric=row["metric"],
                    current=format_number(row["current"]),
                    previous=format_number(row["previous"]),
                    change=format_percent(row["percent_change"]),
                    assessment=row["assessment"],
                )
            )

    return "\n".join(lines) + "\n"


def main() -> int:
    args = parse_args()
    try:
        snapshot = json.loads(args.snapshot.read_text(encoding="utf-8"))
    except FileNotFoundError:
        print(f"Snapshot not found: {args.snapshot}", file=sys.stderr)
        return 2
    except (OSError, json.JSONDecodeError) as error:
        print(f"Could not read snapshot: {error}", file=sys.stderr)
        return 2

    result = analyze(snapshot)
    if args.format == "json":
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        print(render_markdown(result), end="")
    return 0 if result["valid"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
