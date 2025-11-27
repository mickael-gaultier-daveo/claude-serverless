# Table pour le suivi de l'utilisation et des coûts par utilisateur
resource "aws_dynamodb_table" "usage_tracking" {
  name           = "${var.project_name}-${var.environment}-usage-tracking"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "user_id"
  range_key      = "month"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "month"
    type = "S"  # Format: YYYY-MM
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-usage-tracking"
    Environment = var.environment
    Project     = var.project_name
  }
}
