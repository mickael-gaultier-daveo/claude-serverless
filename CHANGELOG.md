# Changelog

## [1.0.0] - 2025-11-07

### 🎉 Version initiale

#### ✨ Fonctionnalités ajoutées
- **Chat avec Claude 3.5 Sonnet** via AWS Bedrock
- **Authentification Cognito** côté applicatif (Option 1)
- **Interface React moderne** avec TailwindCSS
- **Support multi-formats** : PDF, DOCX, CSV, TXT, code source
- **Upload de fichiers** avec extraction de contenu automatique
- **Historique persistant** des conversations en DynamoDB
- **Distribution CloudFront** pour performance globale

#### 🏗️ Infrastructure Terraform
- **Modules** : Cognito, S3/CloudFront, API Gateway, Lambda, DynamoDB, Bedrock
- **Sécurité** : IAM roles avec permissions minimales
- **Monitoring** : CloudWatch logs intégrés
- **TTL** : Suppression automatique des données anciennes

#### 🛠️ Stack technique
- **Frontend** : React 18 + Vite + TypeScript
- **Backend** : Node.js 20 Lambda functions
- **Parsers** : pdf-parse, mammoth, csv-parse
- **Styling** : TailwindCSS avec design system
- **Build** : Scripts de déploiement automatisés

#### 📚 Documentation
- Guide de déploiement complet
- Architecture détaillée avec diagrammes
- Scripts de déploiement Linux/Windows
- README avec démarrage rapide

### 🔧 Configuration requise
- Node.js 18+
- AWS CLI configuré
- Terraform
- Accès AWS Bedrock pour Claude 3.5