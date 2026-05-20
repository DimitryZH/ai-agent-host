#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/openclaw-bootstrap.log"
OPENCLAW_USER="openclaw"
OPENCLAW_HOME="/var/lib/openclaw"
OPENCLAW_CONFIG_DIR="$OPENCLAW_HOME/.openclaw"
OPENCLAW_ENV_FILE="$OPENCLAW_CONFIG_DIR/.env"
OPENCLAW_CONFIG_FILE="$OPENCLAW_CONFIG_DIR/openclaw.json"
OPENCLAW_UID=""
OPENCLAW_GROUP=""

mkdir -p /var/log
touch "$LOG_FILE"
chmod 600 "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

log() {
  printf '[%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"
}

run_as_openclaw() {
  runuser -u "$OPENCLAW_USER" -- env \
    HOME="$OPENCLAW_HOME" \
    PATH="/usr/bin:/bin:/usr/local/bin" \
    XDG_RUNTIME_DIR="/run/user/$OPENCLAW_UID" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$OPENCLAW_UID/bus" \
    "$@"
}

on_error() {
  exit_code=$?
  line_no="$1"
  log "ERROR: bootstrap failed at line $line_no with exit code $exit_code"

  if [ -n "$OPENCLAW_UID" ]; then
    systemctl status "user@$OPENCLAW_UID.service" --no-pager || true
    if [ -S "/run/user/$OPENCLAW_UID/bus" ]; then
      run_as_openclaw systemctl --user status openclaw-gateway.service --no-pager || true
      run_as_openclaw journalctl --user -u openclaw-gateway.service -n 50 --no-pager || true
    fi
  fi

  exit "$exit_code"
}

trap 'on_error $LINENO' ERR

log "Starting OpenClaw bootstrap"

if [ "$(id -u)" -ne 0 ]; then
  log "This bootstrap script must run as root"
  exit 1
fi

if ! command -v runuser >/dev/null 2>&1; then
  log "runuser command is required but not found"
  exit 1
fi

if ! id -u "$OPENCLAW_USER" >/dev/null 2>&1; then
  log "Creating dedicated runtime user: $OPENCLAW_USER"
  useradd --system --create-home --home-dir "$OPENCLAW_HOME" --shell /bin/bash "$OPENCLAW_USER"
else
  log "Runtime user already exists: $OPENCLAW_USER"
fi

OPENCLAW_UID="$(id -u "$OPENCLAW_USER")"
OPENCLAW_GROUP="$(id -gn "$OPENCLAW_USER")"

install -d -o "$OPENCLAW_USER" -g "$OPENCLAW_GROUP" -m 0750 "$OPENCLAW_HOME"
install -d -o "$OPENCLAW_USER" -g "$OPENCLAW_GROUP" -m 0750 "$OPENCLAW_CONFIG_DIR"

if ! command -v openclaw >/dev/null 2>&1; then
  log "Installing OpenClaw CLI version ${openclaw_version}"
  curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard --version ${openclaw_version}
else
  log "OpenClaw CLI already installed; skipping reinstall"
  openclaw --version || true
fi

if ! command -v openclaw >/dev/null 2>&1; then
  log "OpenClaw CLI installation failed"
  exit 1
fi

tmp_env="$(mktemp)"
cat <<EOF > "$tmp_env"
AWS_PROFILE=default
AWS_REGION=${aws_region}
AWS_DEFAULT_REGION=${aws_region}
EOF
install -o "$OPENCLAW_USER" -g "$OPENCLAW_GROUP" -m 0640 "$tmp_env" "$OPENCLAW_ENV_FILE"
rm -f "$tmp_env"
log "Wrote $OPENCLAW_ENV_FILE"

tmp_cfg="$(mktemp)"
cat <<EOF > "$tmp_cfg"
{
  "gateway": {
    "mode": "local",
    "port": ${openclaw_port},
    "bind": "loopback",
    "controlUi": {
      "enabled": true,
      "allowInsecureAuth": false
    },
    "auth": {
      "mode": "token",
      "token": "${openclaw_token}"
    }
  },
  "plugins": {
    "entries": {
      "amazon-bedrock": {
        "enabled": true,
        "config": {
          "discovery": {
            "enabled": true,
            "region": "${aws_region}"
          }
        }
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "${openclaw_model}"
      }
    }
  }
}
EOF
install -o "$OPENCLAW_USER" -g "$OPENCLAW_GROUP" -m 0640 "$tmp_cfg" "$OPENCLAW_CONFIG_FILE"
rm -f "$tmp_cfg"
log "Wrote $OPENCLAW_CONFIG_FILE"

log "Preparing user systemd session for $OPENCLAW_USER"
loginctl enable-linger "$OPENCLAW_USER" >/dev/null 2>&1 || true
systemctl start "user@$OPENCLAW_UID.service"

for i in $(seq 1 20); do
  if [ -S "/run/user/$OPENCLAW_UID/bus" ]; then
    break
  fi
  log "Waiting for user bus at /run/user/$OPENCLAW_UID/bus ($i/20)"
  sleep 2
done

if [ ! -S "/run/user/$OPENCLAW_UID/bus" ]; then
  log "User bus not available for $OPENCLAW_USER"
  exit 1
fi

log "Installing/updating OpenClaw gateway service"
run_as_openclaw openclaw gateway install --force

log "Enabling and starting OpenClaw gateway service"
run_as_openclaw systemctl --user enable --now openclaw-gateway.service

log "OpenClaw gateway status"
run_as_openclaw openclaw gateway status || true
run_as_openclaw systemctl --user status openclaw-gateway.service --no-pager || true

log "OpenClaw bootstrap completed successfully"
