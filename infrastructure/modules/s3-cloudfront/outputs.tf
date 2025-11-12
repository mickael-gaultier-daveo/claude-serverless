output "cloudfront_distribution_id" {
  description = "ID de la distribution CloudFront"
  value       = aws_cloudfront_distribution.frontend.id
}

output "cloudfront_domain_name" {
  description = "Nom de domaine de la distribution CloudFront"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "frontend_bucket" {
  description = "Nom du bucket S3 pour le frontend"
  value       = aws_s3_bucket.frontend.bucket
}

output "frontend_bucket_arn" {
  description = "ARN du bucket S3 pour le frontend"
  value       = aws_s3_bucket.frontend.arn
}

output "ssl_certificate_arn" {
  description = "ARN du certificat SSL (passé depuis le module SSL)"
  value       = var.ssl_certificate_arn
}

output "cloudfront_zone_id" {
  description = "Zone ID de CloudFront pour les alias DNS"
  value       = aws_cloudfront_distribution.frontend.hosted_zone_id
}