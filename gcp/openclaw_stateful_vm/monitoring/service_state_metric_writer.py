"""Build a dry-run Cloud Monitoring model from service-state metrics JSON."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Sequence

from gcp.openclaw_stateful_vm.monitoring.service_state_checker import (
    DEFAULT_SERVICES,
    METRIC_NAMES,
)


DEFAULT_METRIC_PREFIX = "custom.googleapis.com/openclaw/service_state"
ALLOWED_TOP_LEVEL_KEYS = {"ok", "strict", "metrics"}
ALLOWED_METRIC_KEYS = {"name", "value", "labels"}
ALLOWED_LABEL_KEYS = {"service"}
ALLOWED_VALUES = {0, 1}
METRIC_SUFFIX_PREFIX = "openclaw_service_state_"


class ValidationError(ValueError):
    """Raised when the metrics-json payload is not safe to model."""


def read_input(input_file: str | None) -> str:
    if input_file is None:
        return sys.stdin.read()
    return Path(input_file).read_text(encoding="utf-8")


def load_payload(raw_input: str) -> dict[str, Any]:
    try:
        payload = json.loads(raw_input)
    except json.JSONDecodeError as exc:
        raise ValidationError(f"invalid JSON: {exc.msg}") from exc

    if not isinstance(payload, dict):
        raise ValidationError("payload must be a JSON object")

    extra_keys = set(payload) - ALLOWED_TOP_LEVEL_KEYS
    if extra_keys:
        raise ValidationError(f"unexpected top-level keys: {sorted(extra_keys)}")

    metrics = payload.get("metrics")
    if not isinstance(metrics, list):
        raise ValidationError("payload must include a metrics list")

    return payload


def metric_type(metric_prefix: str, metric_name: str) -> str:
    suffix = metric_name.removeprefix(METRIC_SUFFIX_PREFIX)
    return f"{metric_prefix.rstrip('/')}/{suffix}"


def validate_metric(metric: Any) -> dict[str, Any]:
    if not isinstance(metric, dict):
        raise ValidationError("metric entry must be an object")

    extra_keys = set(metric) - ALLOWED_METRIC_KEYS
    missing_keys = ALLOWED_METRIC_KEYS - set(metric)
    if extra_keys:
        raise ValidationError(f"unexpected metric keys: {sorted(extra_keys)}")
    if missing_keys:
        raise ValidationError(f"missing metric keys: {sorted(missing_keys)}")

    name = metric["name"]
    if name not in METRIC_NAMES:
        raise ValidationError(f"unsupported metric name: {name}")

    value = metric["value"]
    if type(value) is not int or value not in ALLOWED_VALUES:
        raise ValidationError(f"unsupported metric value for {name}: {value}")

    labels = metric["labels"]
    if not isinstance(labels, dict):
        raise ValidationError("metric labels must be an object")
    if set(labels) != ALLOWED_LABEL_KEYS:
        raise ValidationError(f"unsupported metric labels: {sorted(labels)}")

    service = labels["service"]
    if service not in DEFAULT_SERVICES:
        raise ValidationError(f"unsupported service label: {service}")

    return {
        "name": name,
        "value": value,
        "labels": {
            "service": service,
        },
    }


def build_dry_run_model(
    payload: dict[str, Any],
    *,
    project: str,
    metric_prefix: str = DEFAULT_METRIC_PREFIX,
) -> dict[str, Any]:
    metrics = [validate_metric(metric) for metric in payload["metrics"]]

    return {
        "dry_run": True,
        "project": project,
        "metric_prefix": metric_prefix.rstrip("/"),
        "time_series": [
            {
                "metric_type": metric_type(metric_prefix, metric["name"]),
                "value": metric["value"],
                "labels": metric["labels"],
            }
            for metric in metrics
        ],
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Prepare bounded dry-run Cloud Monitoring writes from service-state metrics JSON."
    )
    parser.add_argument(
        "--project",
        required=True,
        help="Google Cloud project id for the future metric write model.",
    )
    parser.add_argument(
        "--input-file",
        help="Path to checker metrics-json input. Defaults to stdin.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        default=True,
        help="Build the write model without calling Cloud Monitoring. This is the default.",
    )
    parser.add_argument(
        "--write",
        action="store_true",
        help="Reserved for a future live writer. Currently returns an error without API calls.",
    )
    parser.add_argument(
        "--metric-prefix",
        default=DEFAULT_METRIC_PREFIX,
        help="Custom metric type prefix for the dry-run model.",
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.write:
        print(
            "--write is not implemented; this module currently supports dry-run only",
            file=sys.stderr,
        )
        return 2

    try:
        payload = load_payload(read_input(args.input_file))
        model = build_dry_run_model(
            payload,
            project=args.project,
            metric_prefix=args.metric_prefix,
        )
    except (OSError, ValidationError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    print(json.dumps(model, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
