# GCP Cloud Run Runtime

## Purpose

This document records the Cloud Run runtime path as a validated
proof-of-concept and container contract reference for AI Agent Host.

Cloud Run proved useful runtime behavior, but it is not treated as the durable
state-owning OpenClaw runtime today. The current mature runtime is the GCP
Stateful VM path, which reuses lessons from this Cloud Run work while moving
authoritative OpenClaw state to a preserved Persistent Disk.

## Validated Role

The Cloud Run path validated:

- container build and startup contract;
- Secret Manager integration;
- Gemini path;
- Cloud Logging integration;
- Control UI onboarding;
- GitHub control behavior;
- Artifact Registry image publishing;
- IAM-restricted service posture.

## Boundary

Cloud Run remains a proof-of-concept and runtime contract reference.

It is not the durable state-owning runtime today because the OpenClaw gateway
needs a practical persistent single-writer state boundary. The Stateful VM
runtime is the current state-owning path.

## Historical Local Validation

The earlier minimal Cloud Run validation path used a local container build and
health check pattern. Preserve these commands as historical validation examples
only; they do not represent the current Stateful VM runtime.

Build the minimal runtime image locally:

```bash
docker build -t ai-agent-runtime:local ./gcp/cloud_run
```

Run the container on local port `8080`:

```bash
docker run --rm -p 8080:8080 --name ai-agent-runtime-local ai-agent-runtime:local
```

Check health:

```bash
curl -sS http://localhost:8080/health
```

Expected behavior:

- HTTP `200`;
- JSON health response.

## OpenClaw Cloud Run Runtime

The OpenClaw Cloud Run experiment lives in:

```text
gcp/openclaw_cloud_run/
```

That implementation validates the OpenClaw container shape for Cloud Run:

- one foreground process;
- Cloud Run `PORT` behavior;
- non-root runtime user;
- Secret Manager-backed runtime values;
- Control UI onboarding mode;
- read-only GitHub controls;
- Cloud Run-compatible logging.

## Deployment Posture

Cloud Run deployment examples and helper scripts remain useful for controlled
experiments. Do not treat Cloud Run as the production-like state-owning runtime
without a separate durable-state design review.

Any future Cloud Run durable-state research is optional and deferred unless
platform capabilities change enough to justify revisiting the decision.

## Related Documents

- [OpenClaw Cloud Run README](../README.md)
- [Project README](../../../README.md)
- [Architecture](../../../docs/architecture.md)
- [Deployment Model](../../../docs/deployment-model.md)
- [Project Transition to AI Operations Platform](../../../docs/project-transition-to-ai-operations-platform.md)
