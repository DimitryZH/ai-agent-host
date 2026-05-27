# Experimental OpenClaw Cloud Run Container

This path contains an experimental container skeleton for running OpenClaw Gateway on Cloud Run.

Scope of this experiment:

- verify image structure and startup contract
- verify Cloud Run-compatible process model (`PORT`, foreground process)
- keep security defaults restrictive
- avoid deployment changes in this phase

This is intentionally separate from `gcp/cloud_run/`:

- `gcp/cloud_run/` is the proven minimal Flask runtime baseline used to validate Cloud Run + Terraform + IAM flow.
- `gcp/openclaw_cloud_run/` is a higher-risk runtime experiment to answer container/runtime feasibility before any infrastructure rollout changes.

## Cloud Run Constraints Addressed

- One foreground process only (no `systemd`, no Docker-in-Docker).
- Listener must be reachable on Cloud Run `PORT`.
- Container filesystem is ephemeral; state paths are prepared as writable but not durable.
- Secrets are injected at runtime from environment variables or mounted secret files.
- Service should remain IAM-restricted in later deployment steps.

## Files

- `Dockerfile`: Node-based image + pinned OpenClaw install + non-root runtime user.
- `entrypoint.sh`: strict startup wrapper that renders runtime config and starts Gateway.
- `config/openclaw.template.json`: non-sensitive template with placeholder values.

## Runtime Inputs

Required (token mode default):

- `OPENCLAW_GATEWAY_TOKEN` or `OPENCLAW_GATEWAY_TOKEN_FILE`

Optional:

- `PORT` (Cloud Run sets this automatically; defaults to `8080` locally)
- `OPENCLAW_GATEWAY_AUTH_MODE` (`token` or `password`; default `token`)
- `OPENCLAW_GATEWAY_PASSWORD` or `OPENCLAW_GATEWAY_PASSWORD_FILE` (required only when auth mode is `password`)
- `OPENCLAW_GATEWAY_BIND` (default `lan`; `loopback` is blocked by entrypoint)
- `OPENCLAW_CONTROL_UI_ENABLED` (default `false`)
- `OPENCLAW_PLUGIN_ENTRIES_JSON` or `OPENCLAW_PLUGIN_ENTRIES_JSON_FILE` (future plugin/provider injection hook)
- `OPENAI_API_KEY` or `OPENAI_API_KEY_FILE` (recommended for OpenAI-compatible provider auth)
- `GEMINI_API_KEY` or `GEMINI_API_KEY_FILE` (supported alias; used when `OPENAI_API_KEY` is unset)
- `OPENCLAW_OPENAI_BASE_URL` (default `https://generativelanguage.googleapis.com/v1beta/openai/`)
- `OPENCLAW_PRIMARY_MODEL` (default `openai/gemini-3.5-flash`)
- `OPENCLAW_GEMINI_MODEL_ID` (default derived from `OPENCLAW_PRIMARY_MODEL`)
- `OPENCLAW_GEMINI_MODEL_NAME` (default `Gemini (AI Studio OpenAI Compat)`)

## Gemini API Key Integration (Experimental)

This container now supports Google AI Studio Gemini API keys through OpenClaw's OpenAI-compatible provider path.

- Provider route: `openai/*`
- Default model: `openai/gemini-3.5-flash`
- Default base URL: `https://generativelanguage.googleapis.com/v1beta/openai/`
- Auth key source:
  - `OPENAI_API_KEY` (preferred)
  - or `GEMINI_API_KEY` alias when `OPENAI_API_KEY` is not set

Cloud Run recommended secret mapping:

```bash
--set-secrets OPENAI_API_KEY=gemini-api-key-experimental:latest
```

or:

```bash
--set-secrets GEMINI_API_KEY=gemini-api-key-experimental:latest
```

## Local Build

```bash
docker build -t openclaw-cloud-run:local ./gcp/openclaw_cloud_run
```

## Local Run

```bash
docker run --rm \
  -p 8080:8080 \
  -e PORT=8080 \
  -e OPENCLAW_GATEWAY_TOKEN=replace-with-dev-token \
  --name openclaw-cloud-run-local \
  openclaw-cloud-run:local
```

Example secret-file pattern:

```bash
docker run --rm \
  -p 8080:8080 \
  -e PORT=8080 \
  -e OPENCLAW_GATEWAY_TOKEN_FILE=/var/run/secrets/openclaw/token \
  -v "$(pwd)/dev-secrets:/var/run/secrets/openclaw:ro" \
  openclaw-cloud-run:local
```

## Expected Limitations

- Control UI is disabled by default and not validated in this phase.
- Durable state is not implemented; local container writes are ephemeral.
- Provider integrations (Gemini/Vertex/etc.) are not configured yet.
- Cloud Run deployment wiring (Terraform/service variables) is intentionally deferred.
- Exact production command/config tuning for OpenClaw Gateway still needs runtime verification.

## Why Real Deployment Is Deferred

Deployment is deferred to keep this phase focused on container/runtime feasibility only. The repository currently has a stable minimal Cloud Run baseline; this path is the incremental next step before touching Terraform service wiring, secrets contracts, or operational runbooks.

## Relevance To `ai-operations-platform`

This experiment establishes the first container contract for hosting OpenClaw in a serverless model. That contract can later feed platform-level concerns such as controlled rollout, secret lifecycle, runtime policy, and multi-service operational automation.
