# Data source pour vérifier la disponibilité de Bedrock
data "aws_bedrock_foundation_models" "anthropic" {
  by_provider = "anthropic"
}

# Pas de ressources Bedrock spécifiques à créer
# Les modèles sont disponibles via l'API directement
# Les permissions sont gérées dans le module Lambda