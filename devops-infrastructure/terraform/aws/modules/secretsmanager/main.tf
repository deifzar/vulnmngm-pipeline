# =============================================================================
# Secrets Manager 
# =============================================================================
resource "aws_secretsmanager_secret" "devsecops-ssm" {
  for_each = nonsensitive(toset(keys(var.secrets)))

  name        = "${var.secret_prefix}/${each.key}"
  description = "Secret ${each.key}"


  tags = merge(var.tags, {
    Name = "${var.secret_prefix}/${each.key}"
  })
}

resource "aws_secretsmanager_secret_version" "secret" {
  for_each      = nonsensitive(toset(keys(var.secrets)))
  secret_id     = aws_secretsmanager_secret.devsecops-ssm[each.key].id
  secret_string = var.secrets[each.key]
}

# For SSM custom string secrets rotation, you would need a lambda function
# resource "aws_secretsmanager_secret_rotation" "rotation" {
#   for_each = nonsensitive(toset(keys(var.secrets)))

#   secret_id           = data.aws_secretsmanager_secret.devsecops-ssm-byname[each.key].id
#   rotation_lambda_arn = aws_lambda_function.rotation_lambda.arn

#   rotation_rules {
#     automatically_after_days = 30
#   }
# }
