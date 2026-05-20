# Security Model

## Overview

The AI Agent Host project follows a least-privilege and infrastructure-first security model.

---

# Core Security Principles

## Least Privilege

All cloud resources should use minimal required permissions.

The project avoids:

- broad administrative permissions
- unrestricted runtime access
- public operational dashboards
- excessive infrastructure privileges

---

## Read-Only Operational Philosophy

The long-term operational direction favors:

- read-only infrastructure visibility
- operational diagnostics
- AI-assisted analysis
- human-controlled remediation

---

# AWS Security Model

Preferred operational model:

- AWS Systems Manager Session Manager
- restricted inbound networking
- minimal Bedrock permissions
- dedicated instance role
- no PowerUserAccess

---

# GCP Security Model

Preferred operational model:

- Cloud Run IAM authentication
- dedicated service accounts
- Secret Manager integration
- minimal Vertex AI permissions

---

# Backup Security

Preferred storage:

AWS:
- encrypted S3 bucket

GCP:
- encrypted Cloud Storage bucket

---

# Security Direction

The project prioritizes:

- infrastructure security
- runtime isolation
- reproducible deployments
- secure AI runtime hosting
