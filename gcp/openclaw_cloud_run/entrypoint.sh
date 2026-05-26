#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

log() {
  printf '[%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"
}

fail() {
  log "ERROR: $*"
  exit 1
}

require_command() {
  local cmd="$1"
  command -v "${cmd}" >/dev/null 2>&1 || fail "Required command not found: ${cmd}"
}

read_secret() {
  local var_name="$1"
  local file_var_name="${var_name}_FILE"
  local value="${!var_name:-}"
  local file_path="${!file_var_name:-}"

  if [[ -n "${value}" && -n "${file_path}" ]]; then
    fail "Set either ${var_name} or ${file_var_name}, not both."
  fi

  if [[ -n "${file_path}" ]]; then
    [[ -f "${file_path}" ]] || fail "${file_var_name} points to a non-existent file: ${file_path}"
    value="$(<"${file_path}")"
  fi

  printf '%s' "${value}"
}

normalize_bool() {
  local value="$1"
  case "${value,,}" in
    true|1|yes|on) printf 'true' ;;
    false|0|no|off) printf 'false' ;;
    *) fail "Invalid boolean value: ${value}" ;;
  esac
}

validate_object_json() {
  local label="$1"
  local raw_json="$2"

  if ! printf '%s' "${raw_json}" | jq -e 'type == "object"' >/dev/null 2>&1; then
    fail "${label} must be a valid JSON object."
  fi
}

require_command openclaw
require_command jq

export OPENCLAW_CONFIG_TEMPLATE="${OPENCLAW_CONFIG_TEMPLATE:-/opt/openclaw/config/openclaw.template.json}"
export OPENCLAW_CONFIG_PATH="${OPENCLAW_CONFIG_PATH:-/var/lib/openclaw/runtime/openclaw.json}"
export OPENCLAW_STATE_DIR="${OPENCLAW_STATE_DIR:-/var/lib/openclaw/state}"
export OPENCLAW_RUNTIME_DIR="${OPENCLAW_RUNTIME_DIR:-/var/lib/openclaw/runtime}"
export OPENCLAW_GATEWAY_BIND="${OPENCLAW_GATEWAY_BIND:-lan}"
export OPENCLAW_GATEWAY_AUTH_MODE="${OPENCLAW_GATEWAY_AUTH_MODE:-token}"
export OPENCLAW_GATEWAY_PORT="${PORT:-8080}"
export OPENCLAW_CONTROL_UI_ENABLED="${OPENCLAW_CONTROL_UI_ENABLED:-false}"

[[ -f "${OPENCLAW_CONFIG_TEMPLATE}" ]] || fail "Config template not found: ${OPENCLAW_CONFIG_TEMPLATE}"
[[ "${OPENCLAW_GATEWAY_PORT}" =~ ^[0-9]+$ ]] || fail "PORT must be numeric. Received: ${OPENCLAW_GATEWAY_PORT}"
[[ "${OPENCLAW_GATEWAY_BIND}" != "loopback" ]] || fail "OPENCLAW_GATEWAY_BIND=loopback is incompatible with Cloud Run ingress."

if [[ "${OPENCLAW_GATEWAY_AUTH_MODE}" != "token" && "${OPENCLAW_GATEWAY_AUTH_MODE}" != "password" ]]; then
  fail "OPENCLAW_GATEWAY_AUTH_MODE must be token or password."
fi

OPENCLAW_GATEWAY_TOKEN="$(read_secret OPENCLAW_GATEWAY_TOKEN)"
OPENCLAW_GATEWAY_PASSWORD="$(read_secret OPENCLAW_GATEWAY_PASSWORD)"
OPENCLAW_PLUGIN_ENTRIES_JSON="$(read_secret OPENCLAW_PLUGIN_ENTRIES_JSON)"

if [[ "${OPENCLAW_GATEWAY_AUTH_MODE}" == "token" && -z "${OPENCLAW_GATEWAY_TOKEN}" ]]; then
  fail "OPENCLAW_GATEWAY_TOKEN (or OPENCLAW_GATEWAY_TOKEN_FILE) is required when OPENCLAW_GATEWAY_AUTH_MODE=token."
fi

if [[ "${OPENCLAW_GATEWAY_AUTH_MODE}" == "password" && -z "${OPENCLAW_GATEWAY_PASSWORD}" ]]; then
  fail "OPENCLAW_GATEWAY_PASSWORD (or OPENCLAW_GATEWAY_PASSWORD_FILE) is required when OPENCLAW_GATEWAY_AUTH_MODE=password."
fi

if [[ -z "${OPENCLAW_PLUGIN_ENTRIES_JSON}" ]]; then
  OPENCLAW_PLUGIN_ENTRIES_JSON='{}'
else
  validate_object_json "OPENCLAW_PLUGIN_ENTRIES_JSON" "${OPENCLAW_PLUGIN_ENTRIES_JSON}"
fi

OPENCLAW_CONTROL_UI_ENABLED_JSON="$(normalize_bool "${OPENCLAW_CONTROL_UI_ENABLED}")"

install -d -m 0750 "${OPENCLAW_RUNTIME_DIR}"
install -d -m 0750 "${OPENCLAW_STATE_DIR}"

log "Rendering runtime config at ${OPENCLAW_CONFIG_PATH}"
jq \
  --argjson port "${OPENCLAW_GATEWAY_PORT}" \
  --arg bind "${OPENCLAW_GATEWAY_BIND}" \
  --arg auth_mode "${OPENCLAW_GATEWAY_AUTH_MODE}" \
  --arg token "${OPENCLAW_GATEWAY_TOKEN}" \
  --arg password "${OPENCLAW_GATEWAY_PASSWORD}" \
  --argjson control_ui_enabled "${OPENCLAW_CONTROL_UI_ENABLED_JSON}" \
  --argjson plugin_entries "${OPENCLAW_PLUGIN_ENTRIES_JSON}" \
  '
  .gateway.mode = "local"
  | .gateway.port = $port
  | .gateway.bind = $bind
  | .gateway.controlUi.enabled = $control_ui_enabled
  | .gateway.auth.mode = $auth_mode
  | .gateway.auth.token = (if $auth_mode == "token" then $token else "" end)
  | .gateway.auth.password = (if $auth_mode == "password" then $password else "" end)
  | .plugins.entries = ((.plugins.entries // {}) + $plugin_entries)
  ' \
  "${OPENCLAW_CONFIG_TEMPLATE}" > "${OPENCLAW_CONFIG_PATH}"

export OPENCLAW_CONFIG_PATH
export OPENCLAW_STATE_DIR

gateway_cmd=(openclaw gateway run --port "${OPENCLAW_GATEWAY_PORT}" --bind "${OPENCLAW_GATEWAY_BIND}" --auth "${OPENCLAW_GATEWAY_AUTH_MODE}")
if [[ "${OPENCLAW_GATEWAY_AUTH_MODE}" == "token" ]]; then
  export OPENCLAW_GATEWAY_TOKEN
else
  export OPENCLAW_GATEWAY_PASSWORD
fi

log "Starting OpenClaw Gateway in foreground mode on port ${OPENCLAW_GATEWAY_PORT}"
exec "${gateway_cmd[@]}"
