#!/bin/bash

echo "🔧 Configuration post-déploiement"
echo "================================="

# Vérifier que nous sommes dans le bon répertoire
if [ ! -f "infrastructure/main.tf" ]; then
    echo "❌ Veuillez exécuter ce script depuis la racine du projet"
    exit 1
fi

# Récupérer les outputs Terraform
echo "📥 Récupération de la configuration Terraform..."
cd infrastructure

if [ ! -f "terraform.tfstate" ]; then
    echo "❌ Aucun état Terraform trouvé. Veuillez d'abord déployer l'infrastructure."
    exit 1
fi

USER_POOL_ID=$(terraform output -raw cognito_user_pool_id 2>/dev/null)
CLIENT_ID=$(terraform output -raw cognito_user_pool_client_id 2>/dev/null)
API_URL=$(terraform output -raw api_gateway_url 2>/dev/null)
REGION=$(terraform output -raw aws_region 2>/dev/null || echo "eu-west-1")

if [ -z "$USER_POOL_ID" ] || [ -z "$CLIENT_ID" ] || [ -z "$API_URL" ]; then
    echo "❌ Impossible de récupérer la configuration Terraform"
    echo "Vérifiez que l'infrastructure est correctement déployée"
    exit 1
fi

cd ..

# Mise à jour du fichier de configuration
echo "📝 Mise à jour de la configuration frontend..."
cat > frontend/src/config/aws.ts << EOF
// Configuration AWS générée automatiquement
export const AWS_CONFIG = {
  region: '${REGION}',
  userPoolId: '${USER_POOL_ID}',
  clientId: '${CLIENT_ID}',
  apiUrl: '${API_URL}',
};

export default AWS_CONFIG;
EOF

# Création du fichier .env pour le développement
echo "🔑 Création du fichier .env pour le développement..."
cat > frontend/.env << EOF
# Configuration générée le $(date)
VITE_COGNITO_USER_POOL_ID=${USER_POOL_ID}
VITE_COGNITO_CLIENT_ID=${CLIENT_ID}
VITE_API_URL=${API_URL}
VITE_AWS_REGION=${REGION}
EOF

echo "✅ Configuration mise à jour avec succès!"
echo ""
echo "📋 Configuration actuelle:"
echo "   - Région: ${REGION}"
echo "   - User Pool ID: ${USER_POOL_ID}"
echo "   - Client ID: ${CLIENT_ID}"
echo "   - API URL: ${API_URL}"
echo ""
echo "🚀 Vous pouvez maintenant:"
echo "   1. cd frontend && npm run dev  # Développement local"
echo "   2. npm run deploy:frontend     # Déploiement production"