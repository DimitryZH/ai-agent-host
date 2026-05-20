# GCP Cloud Run Runtime: Local Validation and Deployment Prep

This guide covers local container validation for the minimal GCP Cloud Run runtime and shows deployment command patterns.

Real Artifact Registry push and Cloud Run deployment are intentionally deferred in this phase.

## Prerequisites

- Docker installed and running.
- Repository root as current directory (`ai-agent-host/`).

## Local Build

Build the runtime image locally:

```bash
docker build -t ai-agent-runtime:local ./gcp/cloud_run
```

## Local Run

Run the container on local port `8080`:

```bash
docker run --rm -p 8080:8080 --name ai-agent-runtime-local ai-agent-runtime:local
```

The runtime reads Cloud Run-style `PORT` and defaults to `8080`.

## Health Check

In a separate terminal:

```bash
curl -sS http://localhost:8080/health
```

Expected behavior:

- HTTP `200`
- JSON similar to:

```json
{"ok": true, "status": "healthy"}
```

## Root Endpoint Check

```bash
curl -sS http://localhost:8080/
```

Expected behavior:

- HTTP `200`
- JSON containing:
  - `service`
  - `status` (current placeholder: `placeholder-runtime`)
  - `message`
  - `environment` (`port`, `revision`, `configuration`)
  - `timestamp_utc`

## Optional Helper Script

Use the local validation helper:

```bash
chmod +x gcp/cloud_run/scripts/local_validate.sh
./gcp/cloud_run/scripts/local_validate.sh
```

Windows note:

- Run the script from Git Bash (or another Bash-compatible shell).

What it does:

- Builds image locally.
- Runs container locally.
- Checks `/health`.
- Prints pass/fail output.
- Cleans up the container automatically.

## Artifact Registry Naming Convention

Use the standard Artifact Registry Docker URI format:

```text
REGION-docker.pkg.dev/PROJECT_ID/REPOSITORY/IMAGE:TAG
```

Example:

```text
us-central1-docker.pkg.dev/my-project/ai-agent-runtime/ai-agent-runtime:v0.1.0
```

## Future Push and Deploy Commands (Examples Only)

These commands are examples for the next phase and should not be run in this task.

Authenticate Docker for Artifact Registry:

```bash
gcloud auth configure-docker us-central1-docker.pkg.dev
```

Tag and push:

```bash
docker tag ai-agent-runtime:local us-central1-docker.pkg.dev/PROJECT_ID/ai-agent-runtime/ai-agent-runtime:v0.1.0
docker push us-central1-docker.pkg.dev/PROJECT_ID/ai-agent-runtime/ai-agent-runtime:v0.1.0
```

Deploy (manual example):

```bash
gcloud run deploy ai-agent-runtime \
  --image us-central1-docker.pkg.dev/PROJECT_ID/ai-agent-runtime/ai-agent-runtime:v0.1.0 \
  --region us-central1 \
  --platform managed \
  --no-allow-unauthenticated \
  --service-account cloudrun-runtime@PROJECT_ID.iam.gserviceaccount.com
```

Terraform alignment note:

- The Cloud Run image is controlled by `cloud_run_container_image` in `gcp/terraform/terraform.tfvars`.
- Update that value once an image has been pushed in a later phase.
