output "cognito_user_pool_id" {
  description = "ID du Cognito User Pool"
  value       = module.cognito.user_pool_id
}

output "cognito_user_pool_client_id" {
  description = "ID du client Cognito User Pool"
  value       = module.cognito.user_pool_client_id
}

output "cognito_identity_pool_id" {
  description = "ID du Cognito Identity Pool"
  value       = module.cognito.identity_pool_id
}

output "cloudfront_distribution_id" {
  description = "ID de la distribution CloudFront"
  value       = module.s3_cloudfront.cloudfront_distribution_id
}

output "cloudfront_domain_name" {
  description = "Nom de domaine CloudFront"
  value       = module.s3_cloudfront.cloudfront_domain_name
}

output "frontend_bucket" {
  description = "Nom du bucket S3 pour le frontend"
  value       = module.s3_cloudfront.frontend_bucket
}

output "api_gateway_url" {
  description = "URL de l'API Gateway"
  value       = module.api_gateway.api_gateway_url
}

output "chat_stream_url" {
  description = "URL de streaming pour le chat (Lambda Function URL)"
  value       = module.lambda.chat_handler_function_url
}

output "chat_history_table" {
  description = "Nom de la table DynamoDB pour l'historique des chats"
  value       = module.dynamodb.chat_history_table_name
}

output "ssl_certificate_arn" {
  description = "ARN du certificat SSL pour le domaine personnalisé"
  value       = module.s3_cloudfront.ssl_certificate_arn
}

output "dns_validation_records" {
  description = "Enregistrements DNS à créer pour valider le certificat SSL"
  value       = module.ssl_certificate.domain_validation_options
}

output "custom_domain_instructions" {
  description = "Instructions pour configurer le domaine personnalisé"
  value = <<EOF

🌐 Configuration DNS requise pour claude-serverless.daveo-dev.fr :

1. Créer un enregistrement CNAME :
   Name: claude-serverless.daveo-dev.fr
   Type: CNAME
   Value: ${module.s3_cloudfront.cloudfront_domain_name}

2. Pour valider le certificat SSL, créer ces enregistrements DNS :
${jsonencode(module.ssl_certificate.domain_validation_options)}

3. Une fois les enregistrements créés, l'application sera accessible via :
   - https://claude-serverless.daveo-dev.fr
   - https://${module.s3_cloudfront.cloudfront_domain_name}

EOF
}