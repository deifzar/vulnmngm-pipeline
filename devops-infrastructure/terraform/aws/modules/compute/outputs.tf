output "instance_id" {
  description = "The ID of the EC2 instance"
  value       = aws_instance.this.id
}

output "instance_arn" {
  description = "The ARN of the EC2 instance"
  value       = aws_instance.this.arn
}

output "private_ip" {
  description = "The private IP address of the instance"
  value       = aws_instance.this.private_ip
}

output "private_dns" {
  description = "The private DNS name of the instance"
  value       = aws_instance.this.private_dns
}

output "public_ip" {
  description = "The public IP address (Elastic IP if created)"
  value       = var.create_elastic_ip ? aws_eip.this[0].public_ip : aws_instance.this.public_ip
}

output "elastic_ip" {
  description = "The Elastic IP address (if created)"
  value       = var.create_elastic_ip ? aws_eip.this[0].public_ip : null
}

output "ami_id" {
  description = "The AMI ID used for the instance"
  value       = aws_instance.this.ami
}
