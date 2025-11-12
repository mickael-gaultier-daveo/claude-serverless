variable "project_name" {
  description = "Nom du projet"
  type        = string
}

variable "environment" {
  description = "Environnement (dev, staging, prod)"
  type        = string
}

variable "domain_name" {
  description = "Nom de domaine personnalisé (optionnel)"
  type        = string
  default     = ""
}

variable "ssl_certificate_arn" {
  description = "ARN du certificat SSL pour le domaine personnalisé (si déjà créé)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags à appliquer aux ressources"
  type        = map(string)
  default     = {}
}