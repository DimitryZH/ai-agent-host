# Deployment Model

## Overview

The AI Agent Host project demonstrates two deployment patterns:

- VM-hosted runtime deployment on AWS
- Serverless container deployment on GCP

---

# AWS Deployment Model

## Architecture

```text
Terraform
    ↓
EC2 Instance
    ↓
user_data bootstrap
    ↓
Containerized OpenClaw Runtime
    ↓
Amazon Bedrock
```

---

## AWS Goals

- VM-based runtime hosting
- Infrastructure reproducibility
- Runtime persistence
- Secure operational access

---

# GCP Deployment Model

## Architecture

```text
GitHub Actions
        ↓
Build Container
        ↓
Artifact Registry
        ↓
Cloud Run Deployment
        ↓
AI Runtime
        ↓
Gemini API / Vertex AI
```

---

## GCP Goals

- Serverless runtime hosting
- Immutable deployments
- Cloud-native operational model
- Managed runtime operations

---

# Deployment Philosophy

```text
VM-hosted AI runtime
        ↓
Cloud-native serverless AI runtime
```

The repository demonstrates architectural evolution toward larger AI operational platforms.
