# Architecture

## Overview

AI Agent Host is a multi-cloud infrastructure project focused on hosting self-hosted AI agent runtimes on AWS and GCP using Terraform and cloud-native operational practices.

The project demonstrates two deployment models:

- AWS EC2-based AI runtime hosting
- GCP Cloud Run-based serverless AI runtime hosting

The repository is intentionally infrastructure-oriented and serves as an architectural bridge toward larger operational AI platforms.

---

# Core Design Principles

## Infrastructure First

The project focuses on:

- Terraform Infrastructure as Code
- Runtime hosting patterns
- Secure cloud deployment
- Operational simplicity
- Cloud-native architecture

The repository is not intended to be:

- an LLM training platform
- an ML experimentation repository
- a chatbot demo
- a GPU inference platform

---

## Multi-Cloud Design

The project supports two independent runtime approaches.

### AWS Runtime Model

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

### GCP Runtime Model

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

# Repository Structure

```text
ai-agent-host/
├── aws/
├── gcp/
├── docs/
└── shared/
```

---

# Long-Term Evolution

```text
ai-agent-host
        ↓
ai-rollout-analyzer
        ↓
ai-operations-platform
```
