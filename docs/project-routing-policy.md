# Project Routing Policy

This policy defines where future agent and DevBox work belongs across the current approved repositories.

## Ownership

### `ai-agent-host`

`ai-agent-host` owns infrastructure and runtime-hosting concerns, including:

- OpenClaw Cloud Run runtime
- agent hosting infrastructure
- future execution environments
- reusable GCP DevBox infrastructure

New reusable GCP DevBox infrastructure for OpenClaw or Codex execution belongs in this repository.

Target Google Cloud project:

```text
ai-agent-host-497515
```

Future GCP DevBox infrastructure as code should be created under:

```text
gcp/devbox/
```

Do not create Terraform or cloud resources until a later implementation phase explicitly requests that work.

### `compose-to-aspire-demo`

`compose-to-aspire-demo` owns application conversion research and validation, including:

- Docker Compose to Aspire migration experiments
- conversion validation
- Aspire AppHost work
- historical experiment results

Historical DevBox experiments in `compose-to-aspire-demo` document prior validation work. They do not establish ownership for new reusable DevBox infrastructure.

## Routing Rule

When future agents need a location for reusable GCP DevBox infrastructure, route that work to:

```text
ai-agent-host/gcp/devbox/
```

When future agents need a location for Docker Compose to Aspire conversion work, route that work to:

```text
compose-to-aspire-demo
```

## Rationale

Reusable DevBox infrastructure is part of the agent execution environment. It belongs with the hosting and infrastructure repository so it can share the same GCP project, security model, deployment standards, and operational documentation as the OpenClaw runtime.

Compose-to-Aspire conversion work remains separate because it is application migration research, not reusable infrastructure ownership.
