variable "domain_name" {
  description = "Nom de domaine pour le certificat SSL"
  type        = string
}

variable "tags" {
  description = "Tags à appliquer aux ressources"
  type        = map(string)
  default     = {}
}