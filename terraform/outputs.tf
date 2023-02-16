output "ec2_server_public_ip" {
  value     = aws_instance.ec2_server.public_ip
  sensitive = true
}

output "ec2_server_eip_public" {
  value = aws_eip.ec2_server_eip.public_ip
}

output "ec2_server_instance_id" {
  value = aws_instance.ec2_server.id
}