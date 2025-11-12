# Étape 1 : Déploiement du certificat SSL uniquement
# Utiliser avec : terraform apply -target=module.ssl_certificate

# Module certificat SSL (utilise les providers du main.tf)
module "ssl_certificate" {
  source = "./modules/ssl-certificate"
  
  domain_name = "claude-serverless.daveo-dev.fr"
  
  providers = {
    aws.us_east_1 = aws.us_east_1
  }
  
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Stage       = "ssl-certificate"
  }
}

# Outputs SSL spécifiques pour l'étape 1
output "ssl_certificate_arn_step1" {
  description = "ARN du certificat SSL pour l'étape 1"
  value       = module.ssl_certificate.certificate_arn
}

output "dns_validation_records_step1" {
  description = "⚠️  CRÉER CES ENREGISTREMENTS DNS POUR VALIDER LE CERTIFICAT :"
  value = {
    for dvo in module.ssl_certificate.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
      ttl    = "300"
    }
  }
}

output "validation_instructions_step1" {
  description = "Instructions de validation"
  value = <<EOF

🔐 ÉTAPE 1 : VALIDATION DU CERTIFICAT SSL
==========================================

1. Créer l'enregistrement DNS suivant dans votre zone claude-serverless.daveo-dev.fr :

   ${jsonencode(module.ssl_certificate.domain_validation_options)}

2. Attendre que la validation soit terminée (peut prendre jusqu'à 30 minutes)

3. Une fois validé, passer à l'étape 2 :
   ./step2-deploy-infrastructure.sh

📝 Note : Gardez l'ARN du certificat affiché ci-dessus pour l'étape 2.

EOF
}