#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

PROJECT_ID="${PROJECT_ID:-ai-agent-host-497515}"
REGION="${REGION:-us-central1}"
SERVICE_NAME="${SERVICE_NAME:-openclaw-runtime-experimental}"
REPOSITORY="${REPOSITORY:-ai-agent-runtime}"
IMAGE_NAME="${IMAGE_NAME:-openclaw-cloud-run}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

TIMESTAMP_UTC="$(date -u +%Y%m%dT%H%M%SZ)"
IMAGE_TAG="onboarding-ui-${TIMESTAMP_UTC}"
IMAGE_URI="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "[1/3] Building and pushing image via Cloud Build: ${IMAGE_URI}"
gcloud builds submit \
  "${RUNTIME_DIR}" \
  --project "${PROJECT_ID}" \
  --tag "${IMAGE_URI}"

echo "[2/3] Deploying UI-enabled onboarding revision"
gcloud run deploy "${SERVICE_NAME}" \
  --project "${PROJECT_ID}" \
  --region "${REGION}" \
  --image "${IMAGE_URI}" \
  --no-allow-unauthenticated \
  --max-instances=1 \
  --update-env-vars "OPENCLAW_CONTROL_UI_ENABLED=true,OPENCLAW_PRIMARY_MODEL=google/gemini-2.5-flash,OPENCLAW_GOOGLE_MODEL_ID=gemini-2.5-flash,OPENCLAW_OPENAI_MODEL_ID=gemini-3.5-flash"

echo "[3/3] Deployed"
echo "Service: ${SERVICE_NAME}"
echo "Image:   ${IMAGE_URI}"
echo
echo "Recommended secure access path:"
echo "gcloud run services proxy ${SERVICE_NAME} --project=${PROJECT_ID} --region=${REGION} --port=8080"
echo "Then open: http://127.0.0.1:8080/"
