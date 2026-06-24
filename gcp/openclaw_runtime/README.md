# OpenClaw Shared Runtime Contract

**Status:** Planning scaffold
**Runtime impact:** None
**Current source of truth:** `gcp/openclaw_cloud_run/`

## Purpose

This directory is reserved for the shared OpenClaw runtime contract that is used
by multiple GCP runtime targets.

The current repository has two OpenClaw GCP runtime paths:

* Cloud Run proof-of-concept runtime;
* Stateful VM runtime.

The Stateful VM runtime currently reuses the validated Cloud Run image and
runtime contract instead of maintaining a separate VM-specific OpenClaw build.

## Why This Exists

The following files are currently stored under `gcp/openclaw_cloud_run/`, but
they are conceptually shared runtime assets:

* OpenClaw runtime config template;
* GitHub read-only exec approval policy;
* GitHub controlled draft PR exec approval policy;
* container entrypoint logic;
* seeded workspace guidance files.

These assets are not purely Cloud Run-specific anymore. They define the
OpenClaw container behavior that is reused by the Stateful VM runtime.

## Current Layout

Current source-of-truth paths remain unchanged:

```text
gcp/openclaw_cloud_run/config/openclaw.template.json
gcp/openclaw_cloud_run/config/exec-approvals.github-readonly.json
gcp/openclaw_cloud_run/config/exec-approvals.github-pr.json
gcp/openclaw_cloud_run/entrypoint.sh
gcp/openclaw_cloud_run/Dockerfile
gcp/openclaw_cloud_run/workspace/
```

No runtime files have been moved yet.

## Future Target Layout

A future refactor may move shared runtime assets into this directory:

```text
gcp/openclaw_runtime/
  config/
    openclaw.template.json
    exec-approvals.github-readonly.json
    exec-approvals.github-pr.json
  workspace/
    AGENTS.md
    SOUL.md
    BOOTSTRAP.md
  entrypoint.sh
```

Cloud Run and Stateful VM runtime paths would then consume the shared runtime
contract from this directory instead of treating Cloud Run as the owner of the
shared files.

## Migration Requirements

Before moving any runtime files, the refactor must update and validate:

* Docker build paths;
* entrypoint copy/render paths;
* references in Cloud Run docs;
* references in Stateful VM docs;
* CI or local build validation;
* image rebuild workflow;
* deployment readiness plan for Stateful VM;
* rollback plan.

## Safety Boundary

This scaffold does not change runtime behavior.

Do not move active runtime files into this directory until the Dockerfile,
entrypoint, image build, and Stateful VM deployment path are updated and
validated together.


# OpenClaw Shared Runtime Config

**Status:** Mirror copy; not yet the active build source
**Runtime impact:** None

This directory contains shared OpenClaw runtime configuration assets that are
intended to become the common runtime contract for both Cloud Run and Stateful VM
targets.

The current active source-of-truth remains:

```text
gcp/openclaw_cloud_run/config/
```

These files are copied here as a preparation step for a later refactor. They are
not consumed by the current Docker build or Stateful VM runtime yet.

## Included Files

```text
openclaw.template.json
exec-approvals.github-readonly.json
exec-approvals.github-pr.json
```

## Safety Boundary

Do not delete or modify the active Cloud Run config path until the Dockerfile,
entrypoint, image build, and Stateful VM deployment path are updated and
validated together.
