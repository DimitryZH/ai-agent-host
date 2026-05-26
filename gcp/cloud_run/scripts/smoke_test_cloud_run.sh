#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-your-project-id}"
REGION="${REGION:-us-central1}"
SERVICE_NAME="${SERVICE_NAME:-ai-agent-runtime}"
HEALTH_PATH="${HEALTH_PATH:-/health}"

info() {
  echo "[INFO] $*"
}

pass() {
  echo "[PASS] $*"
}

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

require_command() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    fail "Required command is missing: ${cmd}"
  fi
}

require_command gcloud
require_command curl

info "Using PROJECT_ID=${PROJECT_ID}"
info "Using REGION=${REGION}"
info "Using SERVICE_NAME=${SERVICE_NAME}"

active_account="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null || true)"
if [[ -z "${active_account}" ]]; then
  fail "No active gcloud account found. Run: gcloud auth login"
fi
info "Active gcloud account: ${active_account}"

SERVICE_URL="$(gcloud run services describe "${SERVICE_NAME}" \
  --region "${REGION}" \
  --project "${PROJECT_ID}" \
  --format='value(status.url)')"

if [[ -z "${SERVICE_URL}" ]]; then
  fail "Could not resolve Cloud Run service URL."
fi
pass "Resolved service URL: ${SERVICE_URL}"

health_url="${SERVICE_URL%/}${HEALTH_PATH}"
info "Health endpoint: ${health_url}"

auth_token="$(gcloud auth print-identity-token)"
if [[ -z "${auth_token}" ]]; then
  fail "Failed to mint identity token via gcloud."
fi

auth_body_file="$(mktemp)"
unauth_body_file="$(mktemp)"
cleanup() {
  rm -f "${auth_body_file}" "${unauth_body_file}"
}
trap cleanup EXIT

auth_code="$(curl -sS \
  -o "${auth_body_file}" \
  -w "%{http_code}" \
  -H "Authorization: Bearer ${auth_token}" \
  "${health_url}")"

if [[ "${auth_code}" == "200" ]]; then
  pass "Authenticated /health returned HTTP 200."
  info "Authenticated response body:"
  cat "${auth_body_file}"
  echo
else
  info "Authenticated response body:"
  cat "${auth_body_file}" || true
  echo
  fail "Authenticated /health expected HTTP 200 but got HTTP ${auth_code}."
fi

unauth_code="$(curl -sS \
  -o "${unauth_body_file}" \
  -w "%{http_code}" \
  "${health_url}")"

if [[ "${unauth_code}" == "403" ]]; then
  pass "Unauthenticated /health correctly returned HTTP 403."
else
  info "Unauthenticated response body:"
  cat "${unauth_body_file}" || true
  echo
  fail "Unauthenticated /health expected HTTP 403 but got HTTP ${unauth_code}."
fi

pass "Cloud Run smoke test succeeded."
