variable "project_name" {
  description = "Nom du projet"
  type        = string
}

variable "environment" {
  description = "Environnement (dev, staging, prod)"
  type        = string
}

variable "api_gateway_id" {
  description = "ID de l'API Gateway"
  type        = string
}

variable "api_gateway_execution_arn" {
  description = "ARN d'exécution de l'API Gateway"
  type        = string
}

variable "cognito_user_pool_id" {
  description = "ID du Cognito User Pool"
  type        = string
}

variable "tags" {
  description = "Tags à appliquer aux ressources"
  type        = map(string)
  default     = {}
}