# Configuration Domaine Personnalisé

## Domaines supportés

L'application Claude Serverless Chat supporte plusieurs domaines :

1. **Domaine personnalisé** : `https://claude-serverless.daveo-dev.fr`
2. **CloudFront** : `https://*.cloudfront.net` (généré automatiquement)
3. **Développement local** : `http://localhost:3000`

## Configuration DNS

Pour configurer le domaine personnalisé `claude-serverless.daveo-dev.fr`, vous devez :

1. **Créer un enregistrement CNAME** dans votre DNS :
   ```
   claude-serverless.daveo-dev.fr CNAME xxxxx.cloudfront.net
   ```

2. **Ou un enregistrement A/AAAA** si vous utilisez un alias :
   ```
   claude-serverless.daveo-dev.fr A [IP CloudFront]
   ```

## Configuration CORS

### API Gateway

Les headers CORS sont configurés pour accepter :
- `https://claude-serverless.daveo-dev.fr`
- `*.cloudfront.net`

### Lambda Functions

Les fonctions Lambda incluent automatiquement les headers CORS appropriés dans leurs réponses.

## Configuration Cognito

Les URLs autorisées dans Cognito incluent :
- **Callback URLs** :
  - `https://claude-serverless.daveo-dev.fr`
  - `https://[cloudfront-domain].cloudfront.net`
  - `http://localhost:3000` (dev)

- **Logout URLs** :
  - `https://claude-serverless.daveo-dev.fr`
  - `https://[cloudfront-domain].cloudfront.net`
  - `http://localhost:3000` (dev)

## Déploiement

Le script de déploiement met automatiquement à jour :

1. **Configuration frontend** (`frontend/src/config/domains.ts`)
2. **URLs Cognito** (via Terraform)
3. **Headers CORS** (API Gateway et Lambda)

## Vérification

Après déploiement, vérifiez que :

1. ✅ Le DNS pointe vers CloudFront
2. ✅ HTTPS fonctionne (certificat SSL automatique)
3. ✅ L'authentification Cognito fonctionne
4. ✅ Les appels API passent (pas d'erreur CORS)

## Commandes utiles

```bash
# Vérifier la résolution DNS
dig claude-serverless.daveo-dev.fr

# Tester HTTPS
curl -I https://claude-serverless.daveo-dev.fr

# Vérifier les headers CORS
curl -H "Origin: https://claude-serverless.daveo-dev.fr" \
     -H "Access-Control-Request-Method: POST" \
     -H "Access-Control-Request-Headers: Content-Type,Authorization" \
     -X OPTIONS \
     https://[api-gateway-url]/dev/chat
```

## Sécurité

- **HTTPS obligatoire** en production
- **CORS restrictif** (pas de wildcard `*`)
- **Validation des origines** côté backend
- **JWT Cognito** pour l'authentification