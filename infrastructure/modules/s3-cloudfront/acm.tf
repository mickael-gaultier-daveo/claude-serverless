# Certificat SSL pour le domaine personnalisé (uniquement si ssl_certificate_arn n'est pas fourni)
# Note: Le certificat pour CloudFront DOIT être dans us-east-1
resource "aws_acm_certificate" "main" {
  count = var.domain_name != "" && var.ssl_certificate_arn == "" ? 1 : 0
  
  provider          = aws.us_east_1
  domain_name       = var.domain_name
  validation_method = "DNS"

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# Validation du certificat (nécessite la configuration DNS)
resource "aws_acm_certificate_validation" "main" {
  count = var.domain_name != "" && var.ssl_certificate_arn == "" ? 1 : 0
  
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.main[0].arn
  
  timeouts {
    create = "10m"
  }
}