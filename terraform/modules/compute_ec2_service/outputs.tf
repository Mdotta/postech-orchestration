output "instance_id" {
  value = aws_instance.this.id
}

output "public_ip" {
  value = aws_instance.this.public_ip
}

output "eip_public_ip" {
  value = aws_eip.this.public_ip
}

