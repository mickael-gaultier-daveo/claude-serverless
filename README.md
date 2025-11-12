# Claude Serverless Chat

Application de chat serverless avec Claude 3.5 Sonnet via AWS Bedrock, authentification Cognito et support multi-formats de fichiers.

## 🚀 Démarrage Rapide

### Prérequis
- Node.js 18+
- AWS CLI configuré
- Terraform
- Compte AWS avec accès Bedrock

### Déploiement Express
```bash
# Linux/macOS
./scripts/deploy.sh

# Windows
scripts\deploy.bat
```

### Déploiement Manuel
```bash
# 1. Installation
npm run install:all

# 2. Infrastructure
cd infrastructure
terraform init && terraform apply
cd ..

# 3. Configuration (remplacer les valeurs Terraform)
# Editer frontend/src/config/aws.ts

# 4. Frontend
cd frontend
npm run build
aws s3 sync dist/ s3://YOUR_BUCKET --delete
```

## ✨ Fonctionnalités

- 💬 **Chat avec Claude 3.5 Sonnet** via AWS Bedrock
- 🔐 **Authentification Cognito** sécurisée
- 📁 **Upload multi-formats** : PDF, DOCX, CSV, TXT, code
- 💾 **Historique persistant** en DynamoDB
- ⚡ **Interface moderne** React + TailwindCSS
- 🌍 **Distribution globale** via CloudFront

## 🏗️ Architecture

### Stack Technique
- **Frontend** : React 18 + Vite + TypeScript + TailwindCSS
- **Backend** : AWS Lambda (Node.js 20) + API Gateway
- **Auth** : AWS Cognito (côté applicatif - Option 1)
- **Stockage** : S3 + DynamoDB + CloudFront
- **IA** : AWS Bedrock (Claude 3.5 Sonnet)
- **Infrastructure** : Terraform

### Flux d'Authentification
1. **Utilisateur** → CloudFront → React App
2. **Login** → Cognito → JWT tokens
3. **API Calls** → API Gateway (validation JWT) → Lambda

## 📁 Structure du Projet

```
claude-serverless/
├── frontend/                 # React + Vite
│   ├── src/
│   │   ├── components/      # Composants UI
│   │   ├── contexts/        # AuthContext
│   │   ├── pages/           # LoginPage, ChatPage
│   │   └── config/          # Configuration AWS
│   └── package.json
├── backend/                  # Lambda Functions
│   ├── src/functions/
│   │   ├── chat/           # Handler de chat
│   │   └── file-processor/ # Traitement fichiers
│   └── package.json
├── infrastructure/           # Modules Terraform
│   ├── modules/
│   │   ├── cognito/        # User Pool + Identity Pool
│   │   ├── s3-cloudfront/  # Hébergement + CDN
│   │   ├── api-gateway/    # API REST + CORS
│   │   ├── lambda/         # Functions + IAM
│   │   ├── dynamodb/       # Tables chat + files
│   │   └── bedrock/        # Configuration modèles
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── scripts/                  # Scripts de déploiement
│   ├── deploy.sh           # Linux/macOS
│   └── deploy.bat          # Windows
└── docs/                    # Documentation
    ├── DEPLOYMENT.md       # Guide de déploiement
    └── ARCHITECTURE.md     # Architecture détaillée
```

## 🔧 Configuration

### Variables Terraform (infrastructure/variables.tf)
```hcl
aws_region = "eu-west-1"              # Région AWS
project_name = "claude-serverless"     # Nom du projet
environment = "dev"                    # Environnement
domain_name = ""                       # Domaine personnalisé (optionnel)
```

### Configuration AWS (frontend/src/config/aws.ts)
```typescript
export const AWS_CONFIG = {
  region: 'eu-west-1',
  userPoolId: 'eu-west-1_XXXXXXXXX',    # Depuis Terraform output
  clientId: 'XXXXXXXXXXXXXXXXX',        # Depuis Terraform output
  apiUrl: 'https://xxxxxxxxxx.execute-api.eu-west-1.amazonaws.com/dev',
};
```

## 📋 Commandes Utiles

### Développement
```bash
npm run dev                   # Serveur de développement
npm run lint                  # Linting TypeScript
npm run test                  # Tests (à implémenter)
```

### Production
```bash
npm run build                 # Build frontend + backend
npm run deploy:infra          # Déploiement infrastructure
npm run deploy:backend        # Déploiement fonctions Lambda
npm run deploy:frontend       # Déploiement frontend
npm run deploy:all            # Déploiement complet
```

## 🎯 Utilisation

### 1. Créer un utilisateur
```bash
aws cognito-idp admin-create-user \
  --user-pool-id eu-west-1_XXXXXXXXX \
  --username user@example.com \
  --temporary-password TempPass123! \
  --message-action SUPPRESS
```

### 2. Activer Bedrock
1. AWS Console → Bedrock → Model access
2. Request access → Anthropic Claude 3.5 Sonnet
3. Attendre l'approbation (quelques minutes)

### 3. Accéder à l'application
- URL : `https://YOUR_CLOUDFRONT_URL`
- Login avec les identifiants Cognito
- Commencer à chatter avec Claude !

## 🔍 Dépannage

### Erreurs Communes

**❌ "AccessDenied" Bedrock**
- Vérifier que Claude 3.5 est activé dans Bedrock
- Contrôler les permissions IAM du rôle Lambda

**❌ Erreur d'authentification**
- Vérifier la configuration Cognito
- S'assurer que l'utilisateur est confirmé

**❌ CORS Error**
- Vérifier la configuration API Gateway
- Contrôler les headers autorisés

### Logs
```bash
# Logs Lambda en temps réel
aws logs tail /aws/lambda/claude-serverless-dev-chat-handler --follow

# Logs API Gateway
aws logs describe-log-groups --log-group-name-prefix /aws/apigateway/
```

## 💰 Coûts Estimés

**Usage modéré (100 utilisateurs, 10 msg/jour) :**
- Lambda : ~$5-10/mois
- API Gateway : ~$3-5/mois  
- DynamoDB : ~$1-3/mois
- S3 + CloudFront : ~$2-3/mois
- Cognito : ~$0.50/mois
- **Bedrock : ~$20-50/mois** (principal coût)

**Total : $30-75/mois**

## 🔒 Sécurité

- **Authentification** : Cognito avec JWT
- **Chiffrement** : Au repos (DynamoDB, S3) et en transit (HTTPS)
- **IAM** : Permissions minimales pour les rôles Lambda
- **TTL** : Suppression automatique des données après 3 mois
- **Isolation** : Données séparées par user_id

## 📚 Documentation

- [Guide de Déploiement](docs/DEPLOYMENT.md) - Instructions détaillées
- [Architecture](docs/ARCHITECTURE.md) - Diagrammes et flux

## 🤝 Contribution

1. Fork le projet
2. Créer une branche feature (`git checkout -b feature/nouvelle-fonctionnalite`)
3. Commit (`git commit -m 'Ajout nouvelle fonctionnalité'`)
4. Push (`git push origin feature/nouvelle-fonctionnalite`)
5. Ouvrir une Pull Request

## 📜 Licence

MIT License - Voir le fichier [LICENSE](LICENSE) pour plus de détails.

## ⭐ Support

Si vous trouvez ce projet utile, n'hésitez pas à lui donner une étoile !

---

**🎉 Application prête à déployer !** Suivez le guide dans `docs/DEPLOYMENT.md` pour commencer.