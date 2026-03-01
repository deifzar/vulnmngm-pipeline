output "instance_id" {
  description = "The RDS instance ID"
  value       = aws_db_instance.postgresql.id
}

output "instance_arn" {
  description = "The ARN of the RDS instance"
  value       = aws_db_instance.postgresql.arn
}

output "endpoint" {
  description = "The connection endpoint (hostname:port)"
  value       = aws_db_instance.postgresql.endpoint
}

output "address" {
  description = "The hostname of the RDS instance"
  value       = aws_db_instance.postgresql.address
}

output "port" {
  description = "The database port"
  value       = aws_db_instance.postgresql.port
}

output "database_name" {
  description = "The name of the database"
  value       = aws_db_instance.postgresql.db_name
}

output "username" {
  description = "The master username"
  value       = aws_db_instance.postgresql.username
  sensitive   = true
}

output "connection_string" {
  description = "PostgreSQL connection string (without password)"
  value       = "postgresql://${aws_db_instance.postgresql.username}@${aws_db_instance.postgresql.endpoint}/${aws_db_instance.postgresql.db_name}"
  sensitive   = true
}