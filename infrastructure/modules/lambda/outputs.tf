output "chat_handler_function_name" {
  description = "Nom de la fonction Lambda chat handler"
  value       = aws_lambda_function.chat_handler.function_name
}

output "chat_lambda_arn" {
  description = "ARN de la fonction Lambda chat handler"
  value       = aws_lambda_function.chat_handler.arn
}

output "chat_handler_arn" {
  description = "ARN de la fonction Lambda chat handler"
  value       = aws_lambda_function.chat_handler.arn
}

output "lambda_role_arn" {
  description = "ARN du rôle IAM Lambda"
  value       = aws_iam_role.lambda_role.arn
}

output "chat_handler_function_url" {
  description = "URL de la fonction Lambda chat handler avec streaming"
  value       = aws_lambda_function_url.chat_handler_url.function_url
}