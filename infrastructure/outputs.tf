# Output for Public IPs of Web Instances in the ASG
output "web_instances_public_ips" {
  value = data.aws_instances.web_instances.ids
}

output "db_server_private_ip" {
  value = aws_instance.db.public_ip
}
