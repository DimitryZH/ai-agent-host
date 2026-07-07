"""Run the service-state checker and writer in local dry-run mode."""

from __future__ import annotations

import argparse
import json
import sys
from typing import Sequence

from gcp.openclaw_stateful_vm.monitoring import service_state_checker as checker
from gcp.openclaw_stateful_vm.monitoring import service_state_metric_writer as writer


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Build a bounded service-state Cloud Monitoring dry-run model."
    )
    parser.add_argument(
        "--project",
        required=True,
        help="Google Cloud project id for the dry-run metric write model.",
    )
    parser.add_argument(
        "--service",
        action="append",
        choices=checker.DEFAULT_SERVICES,
        help="Service to check. Repeat to check more than one. Defaults to both approved services.",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Also require loaded/enabled/success metadata.",
    )
    parser.add_argument(
        "--metric-prefix",
        default=writer.DEFAULT_METRIC_PREFIX,
        help="Custom metric type prefix for the dry-run model.",
    )
    parser.add_argument(
        "--format",
        choices=("json",),
        default="json",
        help="Output format. Only bounded JSON is supported.",
    )
    return parser


def build_dry_run_model(
    *,
    project: str,
    services: Sequence[str],
    strict: bool = False,
    metric_prefix: str = writer.DEFAULT_METRIC_PREFIX,
) -> tuple[dict[str, object], bool]:
    states = checker.evaluate_services(services)
    metrics_json = checker.render_metrics_json(states, strict=strict)
    payload = writer.load_payload(metrics_json)
    model = writer.build_dry_run_model(
        payload,
        project=project,
        metric_prefix=metric_prefix,
    )
    return model, all(state.is_healthy(strict=strict) for state in states)


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    services = args.service or list(checker.DEFAULT_SERVICES)

    try:
        model, healthy = build_dry_run_model(
            project=args.project,
            services=services,
            strict=args.strict,
            metric_prefix=args.metric_prefix,
        )
    except writer.ValidationError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    print(json.dumps(model, indent=2, sort_keys=True))
    return 0 if healthy else 1


if __name__ == "__main__":
    sys.exit(main())
