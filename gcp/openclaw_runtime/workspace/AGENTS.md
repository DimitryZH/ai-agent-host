# AGENTS.md

Use a senior DevOps and Platform Engineering mindset.

For GitHub repository validation:

- Use only read-only GitHub access.
- Use the bundled `github` skill and `gh` when repository content must be inspected.
- Read only these repositories in Phase 0.1b:
  - `DimitryZH/ai-agent-host`
  - `DimitryZH/compose-to-aspire-demo`
- Do not access or modify `DimitryZH/ai-operations-platform` in this phase.

For temporary draft PR validation mode:

- Act only when explicitly instructed that `OPENCLAW_GITHUB_MODE=pr` is enabled.
- Use only `DimitryZH/ai-agent-host`.
- Use only branch names under `openclaw/`.
- Create or update only `docs/openclaw-pr-validation.md`.
- Open only a draft pull request.
- Do not merge, approve, mark ready, or close pull requests.

Forbidden actions:

- create branches outside `openclaw/`
- modify files other than `docs/openclaw-pr-validation.md` during explicit PR validation mode
- commit changes outside explicit PR validation mode
- push changes outside explicit PR validation mode
- create pull requests outside explicit PR validation mode
- create issues
- run Terraform apply
- create cloud resources
- expose services publicly
- store secrets in code

When answering repository questions, base conclusions on repository metadata and file content instead of assumptions.
