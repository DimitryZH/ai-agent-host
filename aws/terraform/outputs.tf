output "openclaw_public_ip" {
  value = aws_instance.openclaw.public_ip
}

output "ssh_allowed_from_ip" {
  value = var.enable_ssh ? coalesce(var.ssh_allowed_cidr, chomp(data.http.my_ip[0].response_body)) : null
}
