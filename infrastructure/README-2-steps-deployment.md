# Déploiement en 2 Étapes - Certificat SSL Manual

Ce guide explique comment déployer l'infrastructure Claude Serverless Chat en 2 étapes pour gérer manuellement la validation du certificat SSL.

## 🎯 Pourquoi 2 étapes ?

Le certificat SSL pour CloudFront doit être validé par DNS avant de pouvoir être utilisé. Cette validation nécessite une intervention manuelle pour créer l'enregistrement DNS.

## 📋 Prérequis

- [x] Terraform >= 1.0 installé
- [x] AWS CLI configuré avec les bonnes permissions
- [x] Python 3.9+ installé
- [x] Node.js pour le build du frontend
- [x] Accès aux DNS de `daveo-dev.fr`

## 🚀 Processus de Déploiement

### Étape 1 : Création du Certificat SSL

#### Linux/macOS
```bash
cd infrastructure
./step1-deploy-ssl.sh
```

#### Windows
```cmd
cd infrastructure
step1-deploy-ssl.bat
```

**Cette étape va :**
1. Créer un certificat SSL dans AWS ACM (région `us-east-1`)
2. Afficher l'enregistrement DNS à créer
3. Sauvegarder l'ARN du certificat

**Résultat attendu :**
```
🎯 PROCHAINE ÉTAPE : VALIDATION DNS
==================================

Créer l'enregistrement DNS suivant dans votre zone daveo-dev.fr :

   Type  : CNAME
   Nom   : _abcdef123456789.claude-serverless.daveo-dev.fr
   Valeur: _xyz987654321.acm-validations.aws.
   TTL   : 300

📋 ARN du certificat (à conserver) :
   arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012
```

### Étape 2 : Configuration DNS Manuelle

**Créer l'enregistrement DNS** dans votre console daveo-dev.fr :

1. **Type** : `CNAME`
2. **Nom** : `_abcdef123456789.claude-serverless.daveo-dev.fr` (valeur fournie à l'étape 1)
3. **Valeur** : `_xyz987654321.acm-validations.aws.` (valeur fournie à l'étape 1)
4. **TTL** : `300`

**Attendre la validation** (5-30 minutes) :
- Le certificat passe de `PENDING_VALIDATION` à `ISSUED`
- Vérifiable dans la console AWS ACM (région us-east-1)

### Étape 3 : Déploiement de l'Infrastructure Complète

#### Linux/macOS
```bash
./step2-deploy-infrastructure.sh
# Ou avec l'ARN spécifique :
./step2-deploy-infrastructure.sh "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
```

#### Windows
```cmd
step2-deploy-infrastructure.bat
REM Ou avec l'ARN spécifique :
step2-deploy-infrastructure.bat "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
```

**Cette étape va :**
1. Construire le backend Python
2. Déployer toute l'infrastructure Terraform
3. Configurer CloudFront avec le certificat validé
4. Builder et déployer le frontend
5. Configurer les domaines autorisés

## 🌐 Configuration DNS Finale

Après le déploiement complet, créer l'enregistrement principal :

```
Type  : CNAME
Nom   : claude-serverless.daveo-dev.fr
Valeur: d1234567890abc.cloudfront.net (fourni par l'output Terraform)
TTL   : 300
```

## ✅ Vérification

1. **Certificat validé** : Console AWS ACM → us-east-1 → Certificats
2. **DNS résolu** : `nslookup claude-serverless.daveo-dev.fr`
3. **HTTPS fonctionnel** : `curl -I https://claude-serverless.daveo-dev.fr`
4. **Application accessible** : Ouvrir https://claude-serverless.daveo-dev.fr

## 📁 Structure des Fichiers

```
infrastructure/
├── step1-deploy-ssl.sh         # Script Linux/macOS étape 1
├── step1-deploy-ssl.bat        # Script Windows étape 1
├── step2-deploy-infrastructure.sh  # Script Linux/macOS étape 2
├── step2-deploy-infrastructure.bat # Script Windows étape 2
├── modules/ssl-certificate/     # Module Terraform certificat SSL
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
├── .ssl-certificate-arn        # Fichier généré (ARN sauvegardé)
└── main.tf                     # Configuration principale
```

## 🔧 Troubleshooting

### Certificat non validé
- Vérifier que l'enregistrement DNS CNAME est correct
- Attendre jusqu'à 30 minutes maximum
- Vérifier dans la console AWS ACM (us-east-1)

### Erreur Terraform étape 2
```bash
# Vérifier l'ARN du certificat
cat .ssl-certificate-arn

# Relancer avec l'ARN spécifique
./step2-deploy-infrastructure.sh "arn:aws:acm:..."
```

### Domain non accessible
- Vérifier l'enregistrement CNAME principal
- Attendre la propagation DNS (quelques minutes)
- Tester avec `dig claude-serverless.daveo-dev.fr`

## 🎉 Résultat Final

Application accessible sur :
- ✅ `https://claude-serverless.daveo-dev.fr` (domaine principal)
- ✅ `https://xxxxx.cloudfront.net` (domaine CloudFront)
- ✅ `http://localhost:3000` (développement local)

Avec certificat SSL valide et performances optimisées par CloudFront !