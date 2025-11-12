#!/bin/bash

echo "🚀 ÉTAPE 2 : Déploiement de l'infrastructure complète"
echo "================================================="

cd "$(dirname "$0")"

# Vérification des paramètres
if [ -z "$1" ]; then
    if [ -f ".ssl-certificate-arn" ]; then
        SSL_CERT_ARN=$(cat .ssl-certificate-arn)
        echo "📋 ARN du certificat trouvé : $SSL_CERT_ARN"
    else
        echo "❌ Erreur : ARN du certificat SSL requis"
        echo "Usage : $0 <SSL_CERTIFICATE_ARN>"
        echo "Ou exécutez d'abord step1-deploy-ssl.sh"
        exit 1
    fi
else
    SSL_CERT_ARN="$1"
fi

# Variables
PROJECT_NAME="claude-serverless"
ENVIRONMENT="prod"
REGION="eu-west-3"

echo "🏗️  Configuration :"
echo "   - Projet : $PROJECT_NAME"
echo "   - Environnement : $ENVIRONMENT"
echo "   - Région : $REGION"
echo "   - Certificat SSL : $SSL_CERT_ARN"
echo ""

# Vérification des prérequis
echo "📋 Vérification des prérequis..."

if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform n'est pas installé"
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 n'est pas installé"
    exit 1
fi

echo "✅ Prérequis vérifiés"
echo ""

# 1. Installation des dépendances frontend
echo "📦 Installation des dépendances frontend..."
cd ../
npm install --prefix frontend
cd infrastructure

# 2. Build du backend Python
echo "🔨 Build du backend Python..."
cd ../backend-python
chmod +x build.sh
./build.sh
cd ../infrastructure

# 3. Déploiement de l'infrastructure
echo "🏗️  Déploiement de l'infrastructure Terraform..."

terraform init

# Planification avec l'ARN du certificat
terraform plan -var="ssl_certificate_arn=$SSL_CERT_ARN"

echo ""
echo "⚠️  Voulez-vous continuer avec le déploiement? (y/N)"
read -r CONFIRM

if [[ $CONFIRM =~ ^[Yy]$ ]]; then
    # Apply avec l'ARN du certificat
    terraform apply -var="ssl_certificate_arn=$SSL_CERT_ARN" -auto-approve
    
    # Récupération des outputs
    USER_POOL_ID=$(terraform output -raw cognito_user_pool_id)
    CLIENT_ID=$(terraform output -raw cognito_user_pool_client_id)
    API_URL=$(terraform output -raw api_gateway_url)
    CLOUDFRONT_URL=$(terraform output -raw cloudfront_domain_name)
    FRONTEND_BUCKET=$(terraform output -raw frontend_bucket)
    
    echo ""
    echo "✅ Infrastructure déployée avec succès !"
    echo ""
    echo "📝 Configuration AWS :"
    echo "   - User Pool ID: $USER_POOL_ID"
    echo "   - Client ID: $CLIENT_ID"
    echo "   - API URL: $API_URL"
    echo "   - CloudFront URL: https://$CLOUDFRONT_URL"
    echo ""
    
    # 4. Mise à jour de la configuration frontend
    echo "⚙️  Mise à jour de la configuration frontend..."
    
    cd ../
    
    cat > frontend/src/config/aws.ts << EOF
export const AWS_CONFIG = {
  region: '$REGION',
  userPoolId: '$USER_POOL_ID',
  clientId: '$CLIENT_ID',
  apiUrl: '$API_URL',
};

export default AWS_CONFIG;
EOF

    cat > frontend/src/config/domains.ts << EOF
// Configuration des domaines autorisés
export const ALLOWED_ORIGINS = [
  'https://claude-serverless.daveo-dev.fr',
  'https://$CLOUDFRONT_URL',
] as const;

// Détection automatique du domaine courant
export const getCurrentDomain = (): string => {
  if (typeof window !== 'undefined') {
    return window.location.origin;
  }
  return 'http://localhost:3000';
};

// Vérification si le domaine courant est autorisé
export const isAllowedOrigin = (origin?: string): boolean => {
  const currentOrigin = origin || getCurrentDomain();
  
  return ALLOWED_ORIGINS.some(allowedOrigin => 
    currentOrigin === allowedOrigin ||
    currentOrigin.endsWith('.cloudfront.net') ||
    currentOrigin.includes('localhost')
  );
};

export default {
  ALLOWED_ORIGINS,
  getCurrentDomain,
  isAllowedOrigin,
};
EOF

    # 5. Build et déploiement du frontend
    echo "🎨 Build et déploiement du frontend..."
    cd frontend
    npm run build
    
    # Upload vers S3
    echo "📤 Upload vers S3..."
    aws s3 sync dist/ s3://$FRONTEND_BUCKET --delete --region $REGION
    
    # Invalidation CloudFront
    cd ../infrastructure
    DISTRIBUTION_ID=$(terraform output -raw cloudfront_distribution_id)
    echo "🔄 Invalidation CloudFront..."
    aws cloudfront create-invalidation --distribution-id $DISTRIBUTION_ID --paths "/*" --region $REGION
    
    echo ""
    echo "🎉 Déploiement terminé avec succès !"
    echo ""
    echo "🌐 URLs de l'application :"
    echo "   - https://claude-serverless.daveo-dev.fr"
    echo "   - https://$CLOUDFRONT_URL"
    echo ""
    echo "📚 Prochaines étapes :"
    echo "   1. Créer des utilisateurs dans Cognito"
    echo "   2. Configurer les permissions Bedrock si nécessaire" 
    echo "   3. Tester l'application"
    echo ""
    
else
    echo "❌ Déploiement annulé"
    exit 1
fi