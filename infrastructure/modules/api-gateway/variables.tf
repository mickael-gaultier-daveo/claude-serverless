variable "project_name" {
  description = "Nom du projet"
  type        = string
}

variable "environment" {
  description = "Environnement (dev, staging, prod)"
  type        = string
}

variable "cognito_user_pool_arn" {
  description = "ARN du Cognito User Pool"
  type        = string
}

variable "chat_lambda_arn" {
  description = "ARN de la fonction Lambda pour le chat"
  type        = string
}

variable "file_processor_lambda_arn" {
  description = "ARN de la fonction Lambda pour le traitement de fichiers"
  type        = string
}

variable "tags" {
  description = "Tags à appliquer aux ressources"
  type        = map(string)
  default     = {}
}