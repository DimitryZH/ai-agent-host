#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

PROJECT_ID="${PROJECT_ID:-ai-agent-host-497515}"
REGION="${REGION:-us-central1}"
SERVICE_NAME="${SERVICE_NAME:-openclaw-runtime-experimental}"
GATEWAY_SECRET_NAME="${GATEWAY_SECRET_NAME:-openclaw-gateway-token-experimental}"
MODEL_OVERRIDE="${MODEL_OVERRIDE:-google/gemini-2.5-flash}"

SERVICE_URL="${SERVICE_URL:-$(gcloud run services describe "${SERVICE_NAME}" --project "${PROJECT_ID}" --region "${REGION}" --format='value(status.url)')}"
ID_TOKEN="${ID_TOKEN:-$(gcloud auth print-identity-token)}"
GATEWAY_TOKEN="${GATEWAY_TOKEN:-$(gcloud secrets versions access latest --secret="${GATEWAY_SECRET_NAME}" --project "${PROJECT_ID}")}"

AUTH_HEADER="Authorization: Bearer ${GATEWAY_TOKEN}"
IAM_HEADER="X-Serverless-Authorization: Bearer ${ID_TOKEN}"

echo "[1/4] readyz"
curl -sS -H "${IAM_HEADER}" -H "${AUTH_HEADER}" "${SERVICE_URL}/readyz"
echo

echo "[2/4] models"
curl -sS -H "${IAM_HEADER}" -H "${AUTH_HEADER}" "${SERVICE_URL}/v1/models"
echo

echo "[3/4] deterministic probe"
curl -sS -H "${IAM_HEADER}" -H "${AUTH_HEADER}" -H "Content-Type: application/json" -H "x-openclaw-model: ${MODEL_OVERRIDE}" \
  -d '{"model":"openclaw/default","messages":[{"role":"user","content":"Reply with the single word: OK"}]}' \
  "${SERVICE_URL}/v1/chat/completions"
echo

echo "[4/4] identity probe"
curl -sS -H "${IAM_HEADER}" -H "${AUTH_HEADER}" -H "Content-Type: application/json" -H "x-openclaw-model: ${MODEL_OVERRIDE}" \
  -d '{"model":"openclaw/default","messages":[{"role":"user","content":"Who are you and who is your operator?"}]}' \
  "${SERVICE_URL}/v1/chat/completions"
echo
