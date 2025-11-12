variable "aws_region" {
  description = "Région AWS pour déployer les ressources"
  type        = string
  default     = "eu-west-3"  # Paris
}

variable "project_name" {
  description = "Nom du projet"
  type        = string
  default     = "claude-serverless"
}

variable "environment" {
  description = "Environnement (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "domain_name" {
  description = "Nom de domaine pour l'application (optionnel)"
  type        = string
  default     = ""
}

variable "allowed_origins" {
  description = "Origines autorisées pour CORS"
  type        = list(string)
  default     = ["*"]
}

variable "cognito_callback_urls" {
  description = "URLs de callback Cognito"
  type        = list(string)
  default     = ["http://localhost:3000", "https://localhost:3000"]
}

variable "cognito_logout_urls" {
  description = "URLs de logout Cognito"
  type        = list(string)
  default     = ["http://localhost:3000", "https://localhost:3000"]
}