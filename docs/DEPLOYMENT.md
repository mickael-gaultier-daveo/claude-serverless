# Guide de Déploiement - Claude Serverless Chat

## Prérequis

### Outils Requis
- **Node.js 18+** - [Télécharger](https://nodejs.org/)
- **AWS CLI** - [Guide d'installation](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
- **Terraform** - [Télécharger](https://www.terraform.io/downloads.html)

### Configuration AWS
1. **Configurer AWS CLI** :
   ```bash
   aws configure
   ```
   Renseigner :
   - Access Key ID
   - Secret Access Key  
   - Default region (ex: eu-west-1)

2. **Permissions IAM requises** :
   - CognitoIdentityProvider (Full)
   - S3 (Full)
   - CloudFront (Full)
   - API Gateway (Full)
   - Lambda (Full)
   - DynamoDB (Full)
   - Bedrock (InvokeModel)

## Déploiement Automatique

### Option 1: Script de déploiement complet

**Linux/macOS :**
```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

**Windows :**
```cmd
scripts\deploy.bat
```

## Déploiement Manuel

### 1. Installation des dépendances
```bash
npm run install:all
```

### 2. Compilation du backend
```bash
cd backend
npm run build
cd ..
```

### 3. Déploiement de l'infrastructure
```bash
cd infrastructure
terraform init
terraform plan
terraform apply
```

**Récupérer les outputs :**
```bash
terraform output
```

### 4. Configuration du frontend
Modifier `frontend/src/config/aws.ts` avec les valeurs Terraform :
```typescript
export const AWS_CONFIG = {
  region: 'eu-west-1',
  userPoolId: 'eu-west-1_XXXXXXXXX',
  clientId: 'XXXXXXXXXXXXXXXXXXXXXXXXXX',
  apiUrl: 'https://xxxxxxxxxx.execute-api.eu-west-1.amazonaws.com/dev',
};
```

### 5. Déploiement du frontend
```bash
cd frontend
npm run build

# Upload vers S3
aws s3 sync dist/ s3://YOUR_BUCKET_NAME --delete

# Invalidation CloudFront
aws cloudfront create-invalidation --distribution-id YOUR_DISTRIBUTION_ID --paths "/*"
```

## Configuration Post-Déploiement

### 1. Création d'utilisateurs Cognito

**Via AWS Console :**
1. Aller dans Cognito → User Pools
2. Sélectionner votre User Pool
3. Aller dans "Users" → "Create user"
4. Renseigner email et mot de passe temporaire

**Via CLI :**
```bash
aws cognito-idp admin-create-user \
  --user-pool-id eu-west-1_XXXXXXXXX \
  --username user@example.com \
  --temporary-password TempPass123! \
  --message-action SUPPRESS
```

### 2. Activation des modèles Bedrock

1. Aller dans AWS Console → Bedrock
2. Sélectionner la région (eu-west-1)
3. Aller dans "Model access"
4. Demander l'accès à "Anthropic Claude 3.5 Sonnet"

### 3. Mise à jour des URL de callback

Si vous utilisez un domaine personnalisé, mettre à jour :
```bash
aws cognito-idp update-user-pool-client \
  --user-pool-id eu-west-1_XXXXXXXXX \
  --client-id XXXXXXXXXXXXXXXXXXXXXXXXXX \
  --callback-urls https://votre-domaine.com \
  --logout-urls https://votre-domaine.com
```

## Intégrations API Gateway - Lambda

Les intégrations Lambda sont créées automatiquement par Terraform, mais voici les étapes manuelles si nécessaire :

### Chat Handler
```bash
cd infrastructure
CHAT_FUNCTION_ARN=$(terraform output -raw chat_handler_arn)
API_GATEWAY_ID=$(terraform output -raw api_gateway_id)

# Création de l'intégration
aws apigateway put-integration \
  --rest-api-id $API_GATEWAY_ID \
  --resource-id YOUR_CHAT_RESOURCE_ID \
  --http-method POST \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri arn:aws:apigateway:eu-west-1:lambda:path/2015-03-31/functions/$CHAT_FUNCTION_ARN/invocations
```

## Test de l'Application

### 1. Vérification du déploiement
```bash
curl -I https://YOUR_CLOUDFRONT_URL
```

### 2. Test de l'API
```bash
# Test de l'endpoint de santé (si ajouté)
curl https://YOUR_API_GATEWAY_URL/health
```

### 3. Test de connexion
1. Ouvrir l'application dans le navigateur
2. Se connecter avec les identifiants Cognito
3. Envoyer un message test

## Dépannage

### Problèmes courants

**1. Erreur Terraform "bucket already exists"**
```bash
# Changer le nom du bucket dans variables.tf ou supprimer le bucket existant
aws s3 rb s3://bucket-name --force
```

**2. Erreur d'authentification Cognito**
- Vérifier les URLs de callback
- S'assurer que l'utilisateur est confirmé
- Vérifier la configuration des flow d'auth

**3. Erreur Bedrock "AccessDenied"**
- Vérifier que le modèle Claude est activé
- Contrôler les permissions IAM du rôle Lambda

**4. Erreur CORS**
- Vérifier la configuration CORS dans API Gateway
- S'assurer que les headers sont correctement configurés

### Logs et monitoring

**CloudWatch Logs :**
```bash
aws logs describe-log-groups --log-group-name-prefix /aws/lambda/claude-serverless
```

**Logs Lambda en temps réel :**
```bash
aws logs tail /aws/lambda/claude-serverless-dev-chat-handler --follow
```

## Nettoyage

Pour supprimer toutes les ressources :
```bash
cd infrastructure
terraform destroy
```

**⚠️ Attention :** Cela supprimera définitivement toutes les données et ressources.