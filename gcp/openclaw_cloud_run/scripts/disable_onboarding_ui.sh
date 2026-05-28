#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

PROJECT_ID="${PROJECT_ID:-ai-agent-host-497515}"
REGION="${REGION:-us-central1}"
SERVICE_NAME="${SERVICE_NAME:-openclaw-runtime-experimental}"

echo "Disabling Control UI for ${SERVICE_NAME} in ${PROJECT_ID}/${REGION}"
gcloud run services update "${SERVICE_NAME}" \
  --project "${PROJECT_ID}" \
  --region "${REGION}" \
  --update-env-vars "OPENCLAW_CONTROL_UI_ENABLED=false"

echo "Rollback applied."
