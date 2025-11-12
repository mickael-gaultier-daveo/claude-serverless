# Backend Python - Claude Serverless Chat

Ce répertoire contient les fonctions Lambda Python pour l'application de chat Claude serverless.

## Structure

```
backend-python/
├── shared/                 # Utilitaires partagés
│   ├── aws_clients.py     # Clients AWS (boto3)
│   └── utils.py           # Fonctions utilitaires communes
├── chat/                  # Fonction Lambda chat
│   └── lambda_function.py # Handler principal du chat
├── file_processor/        # Fonction Lambda traitement fichiers
│   └── lambda_function.py # Handler traitement/upload fichiers
├── requirements.txt       # Dépendances Python
├── build.sh              # Script build Linux/macOS
├── build.bat             # Script build Windows
└── README.md             # Ce fichier
```

## Fonctionnalités

### Chat Handler (`chat/`)
- Intégration avec AWS Bedrock (Claude 3.5 Sonnet)
- Gestion de l'historique des conversations en DynamoDB
- Support du streaming pour les réponses en temps réel
- Authentification via JWT Cognito

### File Processor (`file_processor/`)
- Upload de fichiers vers S3
- Extraction de texte des fichiers :
  - PDF (PyPDF2)
  - DOCX (python-docx)
  - CSV (pandas/csv)
  - Fichiers texte (txt, md, code, etc.)
- Sauvegarde des métadonnées en DynamoDB
- TTL automatique (3 mois)

## Dépendances

- `boto3` : SDK AWS pour Python
- `PyPDF2` : Extraction de texte PDF
- `python-docx` : Lecture de documents Word
- `pydantic` : Validation de données (optionnel)

## Build et Déploiement

### Windows
```bash
cd backend-python
build.bat
```

### Linux/macOS
```bash
cd backend-python
chmod +x build.sh
./build.sh
```

Le script de build génère :
- `layers/dependencies.zip` : Layer avec les dépendances Python
- `dist/chat-handler.zip` : Package de la fonction chat
- `dist/file-processor.zip` : Package de la fonction file processor

## Configuration

Les fonctions Lambda utilisent les variables d'environnement suivantes :

### Chat Handler
- `ENVIRONMENT` : Environnement (dev, prod)
- `COGNITO_USER_POOL_ID` : ID du User Pool Cognito
- `DYNAMODB_TABLE` : Nom de la table DynamoDB pour l'historique

### File Processor
- `ENVIRONMENT` : Environnement (dev, prod)
- `UPLOAD_BUCKET` : Nom du bucket S3 pour les uploads

## Migration depuis Node.js

Cette version Python remplace l'ancienne version Node.js avec les améliorations suivantes :
- Meilleure performance pour le traitement de fichiers
- Bibliothèques Python spécialisées pour l'extraction de texte
- Code plus maintenable avec boto3
- Gestion d'erreurs améliorée

## Permissions IAM

Les fonctions nécessitent les permissions suivantes :
- **Bedrock** : `bedrock:InvokeModel`, `bedrock:InvokeModelWithResponseStream`
- **DynamoDB** : `dynamodb:PutItem`, `dynamodb:GetItem`, `dynamodb:Query`
- **S3** : `s3:GetObject`, `s3:PutObject`
- **Logs** : `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents`

## Tests Locaux

Pour tester localement :

```bash
# Installation des dépendances
pip install -r requirements.txt

# Test de la fonction chat
python -m chat.lambda_function

# Test de la fonction file processor
python -m file_processor.lambda_function
```

## Débogage

Les logs sont envoyés vers CloudWatch. Utiliser les groupes de logs :
- `/aws/lambda/{environment}-chat-handler`
- `/aws/lambda/{environment}-file-processor`