output "chat_history_table_name" {
  description = "Nom de la table DynamoDB pour l'historique des chats"
  value       = aws_dynamodb_table.chat_history.name
}

output "chat_history_table_arn" {
  description = "ARN de la table DynamoDB pour l'historique des chats"
  value       = aws_dynamodb_table.chat_history.arn
}