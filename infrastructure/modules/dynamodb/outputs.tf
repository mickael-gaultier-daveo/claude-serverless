output "chat_history_table_name" {
  description = "Nom de la table DynamoDB pour l'historique des chats"
  value       = aws_dynamodb_table.chat_history.name
}

output "chat_history_table_arn" {
  description = "ARN de la table DynamoDB pour l'historique des chats"
  value       = aws_dynamodb_table.chat_history.arn
}

output "kms_key_id" {
  description = "ID de la clé KMS pour le chiffrement des messages"
  value       = aws_kms_key.chat_encryption.key_id
}

output "kms_key_arn" {
  description = "ARN de la clé KMS pour le chiffrement des messages"
  value       = aws_kms_key.chat_encryption.arn
}

output "usage_tracking_table_name" {
  description = "Nom de la table DynamoDB pour le suivi de l'utilisation"
  value       = aws_dynamodb_table.usage_tracking.name
}

output "usage_tracking_table_arn" {
  description = "ARN de la table DynamoDB pour le suivi de l'utilisation"
  value       = aws_dynamodb_table.usage_tracking.arn
}

