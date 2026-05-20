provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project = "OpenClaw"
    }
  }
}

data "aws_ami" "latest_amazonlinux" {
  owners      = ["137112412989"]
  most_recent = true
  filter {
    name   = "name"
    values = ["al2023-ami-2023*-kernel-6.1-x86_64"]
  }
}

data "http" "my_ip" {
  count = var.enable_ssh && var.ssh_allowed_cidr == null ? 1 : 0
  url   = "https://checkip.amazonaws.com/"
}

resource "random_string" "token" {
  length  = 32
  special = false
}

resource "aws_instance" "openclaw" {
  ami                         = data.aws_ami.latest_amazonlinux.id
  instance_type               = var.instance_type
  iam_instance_profile        = aws_iam_instance_profile.this.name
  vpc_security_group_ids      = [aws_security_group.openclaw.id]
  key_name                    = var.enable_ssh ? var.ssh_key_name : null
  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/../user_data/install_openclaw.sh", {
    aws_region       = var.aws_region
    openclaw_port    = var.openclaw_port
    openclaw_model   = var.openclaw_model
    openclaw_version = var.openclaw_version
    openclaw_token   = random_string.token.result
  })

  root_block_device {
    volume_size = var.instance_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  tags = { Name = "OpenClaw" }
}

resource "aws_security_group" "openclaw" {
  name        = "OpenClaw-SG"
  description = "Security Group for OpenClaw"
  tags        = { Name = "OpenClaw SG" }
}

resource "aws_vpc_security_group_egress_rule" "openclaw" {
  security_group_id = aws_security_group.openclaw.id
  description       = "Allow ALL"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = -1
}

resource "aws_vpc_security_group_ingress_rule" "openclaw" {
  count             = var.enable_ssh ? 1 : 0
  security_group_id = aws_security_group.openclaw.id
  description       = "Allow SSH"
  cidr_ipv4         = coalesce(var.ssh_allowed_cidr, "${chomp(data.http.my_ip[0].response_body)}/32")
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

# IAM Role
resource "aws_iam_role" "this" {
  name = "OpenClaw-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "bedrock_minimal" {
  name        = "OpenClaw-Bedrock-Minimal"
  description = "Minimal Bedrock runtime access for OpenClaw model invocation."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "BedrockRuntimeInvoke"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = "*"
      },
      {
        Sid    = "BedrockModelDiscovery"
        Effect = "Allow"
        Action = [
          "bedrock:GetFoundationModel",
          "bedrock:ListFoundationModels"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "bedrock_minimal" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.bedrock_minimal.arn
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "poweruser" {
  count      = var.enable_poweruser ? 1 : 0
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

resource "aws_iam_instance_profile" "this" {
  name = "OpenClaw-Profile"
  role = aws_iam_role.this.name
}
