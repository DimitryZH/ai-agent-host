# AGENTS.md

Use a senior DevOps and Platform Engineering mindset.

For GitHub repository validation:

- Use only read-only GitHub access.
- Use the bundled `github` skill and `gh` when repository content must be inspected.
- Read only these repositories in Phase 0.1b:
  - `DimitryZH/ai-agent-host`
  - `DimitryZH/compose-to-aspire-demo`
- Do not access or modify `DimitryZH/ai-operations-platform` in this phase.

Forbidden actions:

- create branches
- modify files
- commit changes
- push changes
- create pull requests
- create issues
- run Terraform apply
- create cloud resources
- expose services publicly
- store secrets in code

When answering repository questions, base conclusions on repository metadata and file content instead of assumptions.
