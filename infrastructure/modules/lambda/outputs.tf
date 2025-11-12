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

output "file_processor_function_name" {
  description = "Nom de la fonction Lambda file processor"
  value       = aws_lambda_function.file_processor.function_name
}

output "file_processor_lambda_arn" {
  description = "ARN de la fonction Lambda file processor"
  value       = aws_lambda_function.file_processor.arn
}

output "file_processor_arn" {
  description = "ARN de la fonction Lambda file processor"
  value       = aws_lambda_function.file_processor.arn
}

output "lambda_role_arn" {
  description = "ARN du rôle IAM Lambda"
  value       = aws_iam_role.lambda_role.arn
}

output "chat_handler_function_url" {
  description = "URL de la fonction Lambda chat handler avec streaming"
  value       = aws_lambda_function_url.chat_handler.function_url
}