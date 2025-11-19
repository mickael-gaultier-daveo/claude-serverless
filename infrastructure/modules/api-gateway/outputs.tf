output "api_gateway_id" {
  description = "ID de l'API Gateway"
  value       = aws_api_gateway_rest_api.main.id
}

output "api_gateway_execution_arn" {
  description = "ARN d'exécution de l'API Gateway"
  value       = aws_api_gateway_rest_api.main.execution_arn
}

output "api_gateway_url" {
  description = "URL de l'API Gateway"
  value       = "https://${aws_api_gateway_rest_api.main.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${var.environment}"
}

output "chat_resource_id" {
  description = "ID de la ressource /chat"
  value       = aws_api_gateway_resource.chat.id
}