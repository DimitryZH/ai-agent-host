"""Status-only Telegram adapter primitives for the Stateful VM runtime.

This package is intentionally not wired into systemd, Terraform, Secret Manager,
or the live OpenClaw runtime. It provides fixed command handling that can be
validated before any approved adapter enablement step.
"""
