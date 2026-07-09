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

## Related Documentation

- [Project README](../../README.md)
- [Architecture](../../docs/architecture.md)
- [Security Model](../../docs/security-model.md)
- [Deployment Model](../../docs/deployment-model.md)
- [Project Transition to AI Operations Platform](../../docs/project-transition-to-ai-operations-platform.md)
- [Cloud Run Runtime Notes](docs/gcp-cloud-run-runtime.md)

## Cloud Run Constraints Addressed

- One foreground process only (no `systemd`, no Docker-in-Docker).
- Listener must be reachable on Cloud Run `PORT`.
- Container filesystem is ephemeral; state paths are prepared as writable but not durable.
- Secrets are injected at runtime from environment variables or mounted secret files.
- Service should remain IAM-restricted in later deployment steps.

## Files

- `Dockerfile`: Node-based image + pinned OpenClaw install + non-root runtime user.
- `cloudbuild.versioned.yaml`: Cloud Build config for pinned image builds with explicit `OPENCLAW_VERSION` override.
- `entrypoint.sh`: strict startup wrapper that renders runtime config and starts Gateway.
- `config/openclaw.template.json`: non-sensitive template with placeholder values.
- `scripts/deploy_onboarding_ui.sh`: build + deploy temporary IAM-protected UI onboarding revision.
- `scripts/disable_onboarding_ui.sh`: rollback helper to disable Control UI.
- `scripts/validate_post_onboarding.sh`: authenticated probe helper after onboarding.

## Runtime Inputs

Required (token mode default):

- `OPENCLAW_GATEWAY_TOKEN` or `OPENCLAW_GATEWAY_TOKEN_FILE`

Optional:

- `PORT` (Cloud Run sets this automatically; defaults to `8080` locally)
- `OPENCLAW_GATEWAY_AUTH_MODE` (`token` or `password`; default `token`)
- `OPENCLAW_GATEWAY_PASSWORD` or `OPENCLAW_GATEWAY_PASSWORD_FILE` (required only when auth mode is `password`)
- `OPENCLAW_GATEWAY_BIND` (default `lan`; `loopback` is blocked by entrypoint)
- `OPENCLAW_CONTROL_UI_ENABLED` (default `false`)
- `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS_JSON` or `OPENCLAW_CONTROL_UI_ALLOWED_ORIGINS_JSON_FILE` (optional JSON array of allowed UI origins; when UI is enabled and this is unset, runtime defaults to `["http://127.0.0.1:PORT","http://localhost:PORT"]`)
- `OPENCLAW_PLUGIN_ENTRIES_JSON` or `OPENCLAW_PLUGIN_ENTRIES_JSON_FILE` (future plugin/provider injection hook)
- `OPENCLAW_MCP_SERVERS_JSON` or `OPENCLAW_MCP_SERVERS_JSON_FILE` (optional JSON object for OpenClaw-managed MCP server definitions)
- `OPENAI_API_KEY` or `OPENAI_API_KEY_FILE` (recommended for OpenAI-compatible provider auth)
- `GEMINI_API_KEY` or `GEMINI_API_KEY_FILE` (supported alias; used when `OPENAI_API_KEY` is unset)
- `GOOGLE_API_KEY` or `GOOGLE_API_KEY_FILE` (supported alias for native Google provider auth)
- `OPENCLAW_OPENAI_BASE_URL` (default `https://generativelanguage.googleapis.com/v1beta/openai/`)
- `OPENCLAW_PRIMARY_MODEL` (default `openai/gemini-3.5-flash`)
- `OPENCLAW_OPENAI_MODEL_ID` (default `gemini-3.5-flash`)
- `OPENCLAW_OPENAI_MODEL_NAME` (default `Gemini (AI Studio OpenAI Compat)`)
- `OPENCLAW_GOOGLE_BASE_URL` (default `https://generativelanguage.googleapis.com/v1beta`)
- `OPENCLAW_GOOGLE_MODEL_ID` (default `gemini-2.5-flash`)
- `OPENCLAW_GOOGLE_MODEL_NAME` (default `Gemini (Native Google API)`)
- `GH_TOKEN` or `GITHUB_TOKEN` (optional GitHub CLI token; use only read-only scoped credentials in this phase)

## Gemini API Key Integration (Experimental)

This container now supports Google AI Studio Gemini API keys through OpenClaw's OpenAI-compatible provider path.

- Provider route: `openai/*`
- Default model: `openai/gemini-3.5-flash`
- Default base URL: `https://generativelanguage.googleapis.com/v1beta/openai/`
- Auth key source:
  - `OPENAI_API_KEY` (preferred)
  - or `GEMINI_API_KEY` alias when `OPENAI_API_KEY` is not set

This runtime also renders a native OpenClaw `google` provider path in parallel:

- Provider route: `google/*`
- Default native model: `google/gemini-2.5-flash`
- Default base URL: `https://generativelanguage.googleapis.com/v1beta`
- Auth key source:
  - `GEMINI_API_KEY`
  - or `GOOGLE_API_KEY`
  - fallback to `OPENAI_API_KEY` if neither native key alias is set

Cloud Run recommended secret mapping:

```bash
--set-secrets OPENAI_API_KEY=gemini-api-key-experimental:latest
```

or:

```bash
--set-secrets GEMINI_API_KEY=gemini-api-key-experimental:latest
```

## GitHub Read-Only Repository Access (Prepared)

The simple supported path for OpenClaw 2026.5.27 is the bundled `github` skill backed by GitHub CLI (`gh`).

This image installs `gh` and exposes only the bundled `github` skill by default. Use a read-only fine-grained PAT through `GH_TOKEN` or `GITHUB_TOKEN`; do not run interactive `gh auth login` in the container.

At startup, the entrypoint writes an ephemeral GitHub CLI `hosts.yml` under the non-root OpenClaw home directory from the Secret Manager-provided token. This is required because OpenClaw exec runs may not inherit token environment variables. The file is mode `0600`, exists only inside the running container filesystem, and must contain only a read-only token.

The runtime enables only the `exec` tool for this path, with gateway-host exec policy set to allowlist mode. The baked approval policy allows `gh` read commands for only:

- `DimitryZH/ai-agent-host`
- `DimitryZH/compose-to-aspire-demo`

It does not allow shell pipelines, redirection, file mutation tools, branch creation, PR creation, issue creation, or arbitrary commands.

Recommended Secret Manager input:

- `openclaw-github-readonly-token-experimental`: GitHub fine-grained PAT with read-only access only.

Cloud Run secret mapping pattern:

```bash
--set-secrets GH_TOKEN=openclaw-github-readonly-token-experimental:latest,GITHUB_TOKEN=openclaw-github-readonly-token-experimental:latest
```

Read-only validation commands:

```bash
gh repo view DimitryZH/ai-agent-host --json name,description,defaultBranchRef,owner
gh api repos/DimitryZH/ai-agent-host/contents/README.md --jq '.name,.path,.download_url'
gh repo view DimitryZH/compose-to-aspire-demo --json name,description,defaultBranchRef,owner
gh api repos/DimitryZH/compose-to-aspire-demo/contents/README.md --jq '.name,.path,.download_url'
```

The PAT must be scoped only to:

- `DimitryZH/ai-agent-host`
- `DimitryZH/compose-to-aspire-demo`

Do not grant access to `DimitryZH/ai-operations-platform` for this read-only
validation scope.

Required GitHub permissions:

- Metadata: read-only
- Contents: read-only

Forbidden permissions:

- Contents write
- Pull requests write
- Issues write
- Actions/workflows write
- Administration
- Secrets
- Environments
- Organization permissions

Keep repository writes blocked by credential scope. The bundled `github` skill documents broader `gh` workflows, so the read-only PAT is the enforcement boundary for this validation scope.

## GitHub MCP Repository Access (Optional)

This container can also load OpenClaw-managed MCP server definitions from Secret Manager through `OPENCLAW_MCP_SERVERS_JSON`.

For GitHub repository read-only access, prefer the official GitHub MCP server with read-only mode enabled and a repository-scoped credential. Keep the token out of repository files.

Recommended Secret Manager inputs:

- `openclaw-github-readonly-token-experimental`: GitHub credential with read-only access only.
- `openclaw-mcp-servers-experimental`: MCP server definition JSON.

Example MCP server definition shape, assuming a Cloud Run-compatible `github-mcp-server` command is packaged into the image:

```json
{
  "github": {
    "command": "github-mcp-server",
    "args": [
      "stdio"
    ],
    "env": {
      "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_PERSONAL_ACCESS_TOKEN}",
      "GITHUB_READ_ONLY": "1",
      "GITHUB_TOOLSETS": "repos"
    }
  }
}
```

Do not use Docker-in-Docker for this Cloud Run service. If the selected GitHub MCP distribution only supports Docker on the operator machine, package a Cloud Run-compatible binary or use a remote MCP endpoint instead.

Cloud Run secret mapping pattern:

```bash
--set-secrets OPENCLAW_MCP_SERVERS_JSON=openclaw-mcp-servers-experimental:latest
```

If the MCP server needs a separate token environment variable at runtime, inject it from Secret Manager as well:

```bash
--set-secrets GITHUB_PERSONAL_ACCESS_TOKEN=openclaw-github-readonly-token-experimental:latest
```

Read-only requirements:

- Scope access only to `DimitryZH/ai-agent-host` and `DimitryZH/compose-to-aspire-demo`.
- Do not grant access to `DimitryZH/ai-operations-platform` for this read-only
  validation scope.
- Grant repository contents read access only.
- Do not grant contents write, pull requests write, issues write, actions write, repository administration, organization administration, or secret management permissions.
- Keep `GITHUB_READ_ONLY=1` enabled for this validation scope.

## Controlled UI Onboarding Mode (IAM Protected)

Use this only as a temporary onboarding mode to initialize identity/workspace state.

Security posture remains:

- Cloud Run IAM restricted (`--no-allow-unauthenticated`)
- gateway token auth enabled
- `max-instances=1`
- no public anonymous access

### Deploy UI-Enabled Revision

From repo root:

```bash
bash gcp/openclaw_cloud_run/scripts/deploy_onboarding_ui.sh
```

This script:

1. builds/pushes image tag `onboarding-ui-YYYYMMDDTHHMMSSZ`
2. deploys `openclaw-runtime-experimental`
3. sets `OPENCLAW_CONTROL_UI_ENABLED=true`
4. preserves IAM restriction and `max-instances=1`

### Access UI Safely

Direct browser access to an IAM-protected Cloud Run URL is not the recommended onboarding path.
Use local IAM proxying:

```bash
gcloud run services proxy openclaw-runtime-experimental \
  --project=ai-agent-host-497515 \
  --region=us-central1 \
  --port=8080
```

Then open:

- `http://127.0.0.1:8080/`
- if needed, `http://127.0.0.1:8080/__openclaw__/control-ui-config.json` (diagnostic check)

Gateway auth still applies. Use the configured gateway token when prompted by the UI/auth flow.

### Roll Back To Headless

```bash
bash gcp/openclaw_cloud_run/scripts/disable_onboarding_ui.sh
```

Equivalent command:

```bash
gcloud run services update openclaw-runtime-experimental \
  --project=ai-agent-host-497515 \
  --region=us-central1 \
  --update-env-vars OPENCLAW_CONTROL_UI_ENABLED=false
```

### Post-Onboarding Validation

```bash
bash gcp/openclaw_cloud_run/scripts/validate_post_onboarding.sh
```

## Local Build

```bash
docker build -t openclaw-cloud-run:local ./gcp/openclaw_cloud_run
```

Build with an explicit OpenClaw version override:

```bash
docker build \
  --build-arg OPENCLAW_VERSION=2026.5.27 \
  -t openclaw-cloud-run:openclaw-2026-5-27 \
  ./gcp/openclaw_cloud_run
```

Cloud Build equivalent:

```bash
gcloud builds submit gcp/openclaw_cloud_run \
  --project ai-agent-host-497515 \
  --config gcp/openclaw_cloud_run/cloudbuild.versioned.yaml \
  --substitutions _IMAGE_URI=us-central1-docker.pkg.dev/ai-agent-host-497515/ai-agent-runtime/openclaw-cloud-run:openclaw-2026-5-27,_OPENCLAW_VERSION=2026.5.27
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

- Control UI is disabled by default; enabling it is an explicit temporary onboarding mode.
- Durable state is not implemented; Cloud Run local filesystem writes are ephemeral.
- Native Google/Gemini provider path works, but OpenAI-compatible Gemini route remains an active compatibility gap.
- Cloud Run deployment wiring (Terraform/service variables) is intentionally deferred.
- Exact production command/config tuning for OpenClaw Gateway still needs runtime verification.

## Why Real Deployment Is Deferred

Deployment is deferred to keep this phase focused on container/runtime feasibility only. The repository currently has a stable minimal Cloud Run baseline; this path is the incremental next step before touching Terraform service wiring, secrets contracts, or operational runbooks.

## Relevance To `ai-operations-platform`

This experiment establishes the first container contract for hosting OpenClaw in a serverless model. That contract can later feed platform-level concerns such as controlled rollout, secret lifecycle, runtime policy, and multi-service operational automation.
