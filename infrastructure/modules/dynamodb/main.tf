# Table DynamoDB pour l'historique des chats
resource "aws_dynamodb_table" "chat_history" {
  name           = "${var.project_name}-${var.environment}-chat-history"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "user_id"
  range_key      = "conversation_id"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "conversation_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  global_secondary_index {
    name            = "timestamp-index"
    hash_key        = "user_id"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = var.tags
}

# Clé KMS pour le chiffrement des messages
resource "aws_kms_key" "chat_encryption" {
  description             = "KMS key for encrypting chat messages content"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-chat-encryption"
    }
  )
}

resource "aws_kms_alias" "chat_encryption" {
  name          = "alias/${var.project_name}-${var.environment}-chat-encryption"
  target_key_id = aws_kms_key.chat_encryption.key_id
}