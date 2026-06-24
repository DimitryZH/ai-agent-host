# OpenClaw Stateful VM GitHub PR Mode Readiness

**Status:** Planning only; not enabled by default
**Scope:** GitHub draft pull request capability for the Stateful VM runtime

## Purpose

This document defines the readiness boundary for enabling GitHub draft pull
request validation from the OpenClaw Stateful VM runtime.

The goal is not to make GitHub write access part of the default runtime posture.
The goal is to define a controlled, reviewable, and reversible validation path
for a documentation-only draft pull request.

## Current Default Posture

The default Stateful VM posture remains conservative:

* private VM access only;
* no public OpenClaw endpoint;
* gateway token authentication remains required;
* Control UI access remains IAP/tunnel based;
* GitHub mode defaults to read-only;
* PR-capable GitHub access requires a separate approval boundary;
* no Terraform apply, cloud resource creation, or infrastructure mutation is
  allowed through the GitHub validation workflow.

The default tool policy should remain metadata-only or read-only-safe unless a
specific validation stage explicitly approves broader access.

## Why PR Mode Is Separate

GitHub PR mode is a write-capable runtime mode.

Even when constrained, it can create:

* a branch;
* a repository file update;
* a draft pull request.

For that reason, PR mode must not replace the default read-only or metadata-only
runtime posture. It should be enabled only for a controlled validation window and
only with a narrowly scoped approval policy.

## Existing Controlled PR Validation Shape

The repository includes a dedicated GitHub PR exec approval policy for a narrow
draft PR validation scenario.

The intended first validation is documentation-only:

* repository: `DimitryZH/ai-agent-host`;
* branch pattern: `openclaw/pr-validation-YYYYMMDD-HHMMSS`;
* file path: `docs/openclaw-pr-validation.md`;
* pull request type: draft;
* pull request title and body: fixed validation wording;
* infrastructure changes: not allowed;
* secrets or token values in code: not allowed.

The Base64 string used in the approval policy is static Markdown content for the
validation document. It is not a secret.

## Required Approval Gates

Before enabling GitHub PR mode on the Stateful VM runtime, record explicit human
approval for all of the following:

1. approve PR-mode validation scope;
2. approve using a PR-capable GitHub token secret;
3. approve selecting the PR exec approval policy;
4. approve enabling `OPENCLAW_GITHUB_MODE=pr` for the validation window;
5. approve allowing only the minimum tool surface required for the test;
6. approve the exact target repository and branch naming pattern;
7. approve rollback to the default metadata-only or read-only-safe posture.

## Required Runtime Conditions

The PR validation runtime must satisfy these conditions:

* `OPENCLAW_GITHUB_MODE=pr` is enabled only for the approved validation window;
* a separate PR-capable GitHub token secret is used;
* no token value is printed, committed, logged, or pasted into evidence;
* the selected exec approval policy is the controlled PR policy;
* `exec` is the only required agent-facing tool for this validation;
* file write/edit/patch tools remain disabled;
* process and code execution tools remain disabled;
* browser automation remains disabled;
* cron and scheduled execution remain disabled;
* gateway/admin mutation tools remain disabled;
* public ingress remains disabled;
* Terraform apply remains out of scope;
* cloud resource creation remains out of scope.

## Allowed First Validation

The first approved PR validation may only perform this controlled sequence:

1. read the main branch reference;
2. create a branch matching `openclaw/pr-validation-YYYYMMDD-HHMMSS`;
3. create or update `docs/openclaw-pr-validation.md` with the fixed validation
   content;
4. create a draft pull request with the fixed validation title and body.

No merge, auto-approval, workflow dispatch, repository settings change, secret
change, issue mutation, or infrastructure change is allowed.

## Explicitly Not Allowed

The following are not allowed in the first PR validation:

* creating arbitrary branches;
* committing arbitrary workspace contents;
* pushing local Git state;
* creating non-draft pull requests;
* merging pull requests;
* approving pull requests;
* modifying GitHub Actions workflows;
* dispatching workflows;
* changing repository settings;
* creating or modifying GitHub secrets;
* changing Terraform, runtime infrastructure, cloud resources, or deployment
  state;
* exposing gateway tokens, GitHub tokens, model API keys, or browser/session
  contents.

## Validation Checklist

After an approved PR validation run, confirm:

* only one expected branch was created;
* only the expected documentation file changed;
* the PR is draft;
* the PR title and body match the approved validation text;
* no infrastructure files changed;
* no secret values appear in the diff;
* no GitHub Actions workflow was modified or dispatched;
* runtime mode can be returned to the default posture;
* Control UI remains reachable through the private tunnel;
* gateway health and readiness still pass.

## Rollback And Cleanup

After validation:

1. return GitHub mode to the default non-PR posture;
2. return tool access to metadata-only or read-only-safe mode;
3. revoke or disable PR-capable token usage when no longer needed;
4. close the draft PR if it is no longer useful;
5. delete the validation branch if appropriate;
6. record the validation result and any follow-up decisions.

## Final Recommendation

Treat GitHub PR mode as a controlled validation capability, not as a default
runtime capability.

The first Stateful VM GitHub PR test should remain documentation-only, draft
only, and bounded by a dedicated approval policy.
