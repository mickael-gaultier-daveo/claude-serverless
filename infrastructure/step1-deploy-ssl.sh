#!/bin/bash

echo "🔐 ÉTAPE 1 : Création du certificat SSL pour CloudFront"
echo "=================================================="

cd "$(dirname "$0")"

# Variables
PROJECT_NAME="claude-serverless"
ENVIRONMENT="prod"
DOMAIN="claude-serverless.daveo-dev.fr"

echo "🏗️  Configuration :"
echo "   - Projet : $PROJECT_NAME"
echo "   - Environnement : $ENVIRONMENT" 
echo "   - Domaine : $DOMAIN"
echo ""

# Initialisation Terraform
echo "📦 Initialisation Terraform..."
terraform init

# Déploiement du certificat SSL uniquement avec target
echo "🚀 Création du certificat SSL..."
echo ""
echo "⚠️  ATTENTION : Le certificat sera créé en attente de validation DNS"
echo ""

# Utilisation de terraform apply avec target pour déployer seulement le SSL
terraform apply -target=module.ssl_certificate -auto-approve

# Vérification du succès
if [ $? -ne 0 ]; then
    echo "❌ Erreur lors de la création du certificat SSL"
    exit 1
fi

# Récupération des outputs Terraform
echo ""
echo "✅ Certificat SSL créé avec succès !"
echo ""

# Récupération de l'ARN du certificat
CERT_ARN=$(terraform output -raw ssl_certificate_arn_step1)

# Récupération des informations DNS
echo "🎯 PROCHAINE ÉTAPE : VALIDATION DNS"
echo "=================================="
echo ""
echo "Affichage des enregistrements DNS à créer :"
terraform output dns_validation_records_step1
echo ""
echo "📋 ARN du certificat (à conserver) :"
echo "   $CERT_ARN"
echo ""
echo "⏳ Une fois l'enregistrement DNS créé :"
echo "   1. Attendre la validation (5-30 minutes)"
echo "   2. Exécuter : ./step2-deploy-infrastructure.sh \"$CERT_ARN\""
echo ""

# Sauvegarde de l'ARN pour l'étape 2
echo "$CERT_ARN" > .ssl-certificate-arn
echo "💾 ARN sauvegardé dans .ssl-certificate-arn"

echo ""
echo "🔚 Étape 1 terminée. Configurez le DNS et passez à l'étape 2."