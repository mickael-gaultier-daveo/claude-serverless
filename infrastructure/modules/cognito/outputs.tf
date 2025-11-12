output "user_pool_id" {
  description = "ID du Cognito User Pool"
  value       = aws_cognito_user_pool.main.id
}

output "user_pool_arn" {
  description = "ARN du Cognito User Pool"
  value       = aws_cognito_user_pool.main.arn
}

output "user_pool_client_id" {
  description = "ID du client Cognito User Pool"
  value       = aws_cognito_user_pool_client.main.id
}

output "identity_pool_id" {
  description = "ID du Cognito Identity Pool"
  value       = aws_cognito_identity_pool.main.id
}

output "authenticated_role_arn" {
  description = "ARN du rôle IAM pour les utilisateurs authentifiés"
  value       = aws_iam_role.authenticated.arn
}