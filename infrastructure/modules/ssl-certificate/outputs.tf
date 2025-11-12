output "certificate_arn" {
  description = "ARN du certificat SSL"
  value       = aws_acm_certificate.main.arn
}

output "certificate_status" {
  description = "Statut du certificat SSL"
  value       = aws_acm_certificate.main.status
}

output "domain_validation_options" {
  description = "Options de validation DNS"
  value       = aws_acm_certificate.main.domain_validation_options
}