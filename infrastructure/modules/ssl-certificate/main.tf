# Certificat SSL pour CloudFront
# IMPORTANT : Doit être créé dans us-east-1 pour CloudFront
resource "aws_acm_certificate" "main" {
  provider = aws.us_east_1
  
  domain_name       = var.domain_name
  validation_method = "DNS"

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}