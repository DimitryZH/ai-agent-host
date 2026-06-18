# Phase 5 Remaining Gates

## Purpose

Track the remaining closure gates for Phase 5 after the Stateful VM runtime,
OpenClaw API path, Control UI access, and admin RPC pairing flow were
validated.

Do not execute disruptive gates from this checklist without explicit human
approval.

## Remaining Gates

### Pairing Persistence After Service Restart

- Purpose: prove that paired-device state survives a local `openclaw.service`
  restart.
- Risk: medium. A failed restart or unexpected state regression could interrupt
  the runtime.
- Suggested validation method: record current paired device state, restart the
  service during a controlled window, then confirm the same paired device still
  exists and the UI reconnects.
- Safe to perform now: yes, but only in a controlled maintenance window.
- Human approval required: yes.

### Pairing Persistence After MIG Recreate

- Purpose: prove that paired-device state survives instance replacement while
  the preserved disk remains authoritative.
- Risk: medium to high. This is intentionally disruptive and creates downtime.
- Suggested validation method: capture current pair state, perform one approved
  recreate or repair event, then validate pairing and API health on the
  replacement VM.
- Safe to perform now: yes, if downtime is acceptable and rollback is ready.
- Human approval required: yes.

### Snapshot Restore Drill

- Purpose: prove that a scheduled or manual snapshot can restore usable
  OpenClaw state.
- Risk: high. Requires isolated recovery procedure design and careful writer
  fencing.
- Suggested validation method: restore a snapshot into an isolated test disk
  and boot a fenced test gateway with non-production secrets.
- Safe to perform now: not on the production-like runtime without an isolated
  recovery target.
- Human approval required: yes.

### GitHub PR Mode Decision

- Purpose: decide whether the Stateful VM should ever run with PR-capable
  GitHub access instead of read-only mode.
- Risk: medium to high. Broadens mutation capability inside the long-lived
  runtime.
- Suggested validation method: document decision criteria, required controls,
  token handling, and a separate validation task before any enablement.
- Safe to perform now: the decision discussion is safe; enablement is not.
- Human approval required: yes for enablement.

### Vertex AI Migration Decision

- Purpose: decide whether the runtime should keep the current Gemini API path or
  move to a Vertex AI integration model.
- Risk: medium. Could change auth, quota, and operational complexity.
- Suggested validation method: architecture review followed by a separate
  low-risk experiment in a non-authoritative environment.
- Safe to perform now: yes as analysis only.
- Human approval required: yes for implementation work.

### Long-Term Operating Model: Always-On vs Start-Stop

- Purpose: decide whether this runtime should stay continuously available or run
  only during approved operator windows.
- Risk: medium. Affects cost, availability, and recovery expectations.
- Suggested validation method: compare cost, operational friction, pairing
  persistence implications, and expected usage cadence.
- Safe to perform now: yes as analysis only.
- Human approval required: yes for any operating-policy change that alters
  runtime uptime or automation.

### Cost Note

- Purpose: ensure the ongoing cost profile is explicitly accepted.
- Risk: low technically, medium operationally if left implicit.
- Suggested validation method: record approximate monthly cost components for
  VM, disk, snapshot storage, NAT, and operator access expectations.
- Safe to perform now: yes.
- Human approval required: yes for long-term acceptance.

### Final ROADMAP Status Update

- Purpose: move Phase 5 from closure-in-progress to complete only when the
  remaining gates are closed with evidence.
- Risk: low. Main risk is overstating maturity before the recovery and
  persistence drills are done.
- Suggested validation method: update `ROADMAP.md` after the restart/recreate
  drill, restore drill, and operating-model decisions are complete.
- Safe to perform now: partial status wording is safe; final completion is not.
- Human approval required: yes for declaring Phase 5 complete.
