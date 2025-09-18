output "ec2_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = module.compute.public_ip
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ec2-user@${module.compute.public_ip}"
}

output "s3_bucket_name" {
  description = "S3 bucket name for images"
  value       = module.s3.s3_bucket_name
}