output "available_models" {
  description = "Modèles Bedrock disponibles d'Anthropic"
  value       = data.aws_bedrock_foundation_models.anthropic.model_summaries
}