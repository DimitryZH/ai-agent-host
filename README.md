# AI Agent Host

Multi-cloud Terraform deployment patterns for self-hosted AI agent runtimes on AWS and GCP.

This project demonstrates secure, infrastructure-focused deployment patterns for hosting AI agents using:

- AWS EC2 + Amazon Bedrock
- Google Cloud Run + Gemini API
- Terraform Infrastructure as Code
- Cloud-native security practices
- Immutable deployment workflows
- AI runtime operational hardening

The repository is designed as a bridge between traditional VM-hosted AI runtimes and modern cloud-native AI operations platforms.

---

# Goals

The project focuses on:

- Self-hosted AI agent runtime deployment
- Multi-cloud infrastructure patterns
- Secure AI runtime hosting
- Terraform-first infrastructure provisioning
- Cloud-native operational practices
- Platform evolution toward AI Operations Platforms

---

# Architecture Overview

## AWS Deployment Model

```text
Terraform
    ↓
EC2 Instance
    ↓
user_data bootstrap
    ↓
Dockerized OpenClaw Runtime
    ↓
Amazon Bedrock
```

Key AWS capabilities:

- EC2 AI runtime hosting
- IAM role-based Bedrock access
- SSM Session Manager access
- Hardened security groups
- Persistent runtime storage
- Encrypted backup support

---

## GCP Deployment Model

```text
GitHub Actions
        ↓
Build Container
        ↓
Artifact Registry
        ↓
Cloud Run Deployment
        ↓
AI Agent Runtime
        ↓
Gemini API / Vertex AI
```

Key GCP capabilities:

- Cloud Run serverless runtime
- Container-first architecture
- Secret Manager integration
- Cloud-native IAM
- Cloud Logging & Monitoring
- Stateless runtime deployment

---

# Repository Structure

```text
ai-agent-host/
├── README.md
├── docs/
│   ├── architecture.md
│   ├── security-model.md
│   ├── deployment-model.md
│   ├── backup-restore.md
│   └── troubleshooting.md
│
├── aws/
│   ├── terraform/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars.example
│   ├── user_data/
│   │   └── install_openclaw.sh
│   ├── iam/
│   └── examples/
│
├── gcp/
│   ├── terraform/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars.example
│   ├── cloud_run/
│   │   ├── Dockerfile
│   │   ├── app/
│   │   └── deploy.sh
│   ├── startup_scripts/
│   └── examples/
│
├── shared/
│   ├── hardening/
│   ├── templates/
│   └── configs/
│
├── .github/
│   └── workflows/
│
└── images/
```

---

# Security Model

The project follows a least-privilege security approach.

Core principles:

- No public AI dashboards by default
- Dedicated service accounts and IAM roles
- Secret isolation through cloud secret managers
- Read-only operational defaults
- SSH avoidance where possible
- Immutable infrastructure deployment patterns

---

# AWS Security Practices

Recommended AWS operational model:

- AWS Systems Manager Session Manager instead of SSH
- Minimal IAM policies for Bedrock access
- Restricted network exposure
- Encrypted EBS storage
- Non-root runtime user
- Hardened systemd runtime configuration

---

# GCP Security Practices

Recommended GCP operational model:

- Cloud Run IAM authentication
- Secret Manager for sensitive values
- Artifact Registry image signing
- Cloud Logging audit visibility
- Dedicated service accounts
- Minimal Vertex AI permissions

---

# Backup Strategy

The project supports:

- Encrypted cloud storage backups
- Runtime configuration versioning
- GitHub private repository backups
- Operational configuration recovery
- Runtime state restoration procedures

AWS:

- S3 encrypted backup bucket

GCP:

- Cloud Storage encrypted backup bucket

---

# Long-Term Evolution

This repository is intentionally designed as a foundational AI runtime hosting project that evolves toward larger operational AI systems.

Project evolution path:

```text
ai-agent-host
        ↓
ai-operations-platform
```

---

# Project Scope

This project is intentionally infrastructure-focused.

It is not:

- an LLM training project
- an ML research project
- a chatbot demo
- a GPU inference platform

Instead, it focuses on:

- AI runtime hosting
- operational infrastructure
- cloud-native deployment patterns
- AI platform engineering foundations

---


