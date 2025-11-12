#!/bin/bash

echo "🚀 Déploiement de Claude Serverless Chat"
echo "========================================"

# Vérifications des prérequis
echo "📋 Vérification des prérequis..."

if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform n'est pas installé"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI n'est pas installé"
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 n'est pas installé"
    exit 1
fi

if ! command -v pip &> /dev/null; then
    echo "❌ pip n'est pas installé"
    exit 1
fi

echo "✅ Prérequis vérifiés"

# Variables
REGION=${AWS_REGION:-eu-west-1}
ENVIRONMENT=${ENVIRONMENT:-dev}
PROJECT_NAME="claude-serverless"

echo "🏗️  Configuration:"
echo "   - Region: $REGION"
echo "   - Environment: $ENVIRONMENT"
echo "   - Project: $PROJECT_NAME"

# 1. Installation des dépendances
echo "📦 Installation des dépendances..."
npm run install:all

# 2. Build du backend Python
echo "🔨 Build du backend Python..."
cd backend-python
chmod +x build.sh
./build.sh
cd ..

# 3. Déploiement de l'infrastructure
echo "🏗️  Déploiement de l'infrastructure Terraform..."
cd infrastructure
terraform init
terraform plan
echo "⚠️  Voulez-vous continuer avec le déploiement? (y/N)"
read -r CONFIRM
if [[ $CONFIRM =~ ^[Yy]$ ]]; then
    terraform apply -auto-approve
    
    # Récupération des outputs Terraform
    USER_POOL_ID=$(terraform output -raw cognito_user_pool_id)
    CLIENT_ID=$(terraform output -raw cognito_user_pool_client_id)
    API_URL=$(terraform output -raw api_gateway_url)
    CLOUDFRONT_URL=$(terraform output -raw cloudfront_domain_name)
    FRONTEND_BUCKET=$(terraform output -raw frontend_bucket)
    
    echo "✅ Infrastructure déployée"
    echo "📝 Configuration AWS:"
    echo "   - User Pool ID: $USER_POOL_ID"
    echo "   - Client ID: $CLIENT_ID"
    echo "   - API URL: $API_URL"
    echo "   - CloudFront URL: https://$CLOUDFRONT_URL"
else
    echo "❌ Déploiement annulé"
    exit 1
fi
cd ..

# 4. Mise à jour de la configuration frontend
echo "⚙️  Mise à jour de la configuration frontend..."
cat > frontend/src/config/aws.ts << EOF
export const AWS_CONFIG = {
  region: '$REGION',
  userPoolId: '$USER_POOL_ID',
  clientId: '$CLIENT_ID',
  apiUrl: '$API_URL',
};

export default AWS_CONFIG;
EOF

# Mise à jour de la configuration des domaines
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
DISTRIBUTION_ID=$(cd ../infrastructure && terraform output -raw cloudfront_distribution_id)
echo "🔄 Invalidation CloudFront..."
aws cloudfront create-invalidation --distribution-id $DISTRIBUTION_ID --paths "/*" --region $REGION

cd ..

echo ""
echo "🎉 Déploiement terminé avec succès!"
echo "🌐 URL de l'application: https://$CLOUDFRONT_URL"
echo ""
echo "📚 Prochaines étapes:"
echo "   1. Créer des utilisateurs dans Cognito"
echo "   2. Configurer les permissions Bedrock si nécessaire"
echo "   3. Tester l'application"