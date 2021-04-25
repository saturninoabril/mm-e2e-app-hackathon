# Print outputs
output "server_public_dns" {
  description = "Test Server Public DNS"
  value       = aws_instance.this.*.public_dns
}
