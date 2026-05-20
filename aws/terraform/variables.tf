variable "aws_region" {
  description = "AWS Region to provison resources"
  type        = string
  default     = "us-west-2"
}

variable "instance_type" {
  description = "OpenClaw EC2 Instance Type"
  type        = string
  default     = "t3.xlarge"
}

variable "instance_volume_size" {
  description = "OpenClaw EC2 Instance Volume Size"
  type        = number
  default     = 20
}

variable "ssh_key_name" {
  description = "Optional SSH key pair name for EC2 access when SSH is enabled."
  type        = string
  default     = null
}

variable "enable_ssh" {
  description = "Enable SSH ingress on port 22. Disabled by default in favor of SSM Session Manager."
  type        = bool
  default     = false
}

variable "ssh_allowed_cidr" {
  description = "Optional CIDR allowed to reach SSH when enable_ssh is true. If null, caller public IP is auto-detected."
  type        = string
  default     = null
}

variable "openclaw_port" {
  description = "OpenClaw Port"
  type        = number
  default     = 18789
}

variable "openclaw_model" {
  description = "OpenClaw Default Model"
  type        = string
  default     = "amazon-bedrock/global.amazon.nova-2-lite-v1:0"
}

variable "openclaw_version" {
  description = "OpenClaw version to Install"
  type        = string
  default     = "2026.4.21"
}

variable "enable_poweruser" {
  description = "Optional escape hatch to attach PowerUserAccess. Keep disabled for least privilege."
  type        = bool
  default     = false
}
