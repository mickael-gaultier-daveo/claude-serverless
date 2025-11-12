# Estimation de Coûts AWS - Claude Serverless Chat

## 📊 Cas d'Usage : Comptes Rendus de Réunions

### 📝 Hypothèses
- **1 utilisateur** actif
- **1 réunion/jour** (22 jours ouvrés/mois)
- **Transcript de 1h** ≈ 60-80 KB par fichier
- **Conservation des données** : 3 mois (TTL DynamoDB)
- **Interaction** : 5-10 questions par transcript

---

## 💰 Coûts Mensuels Détaillés

### 1. **AWS Bedrock (Claude 3.5 Sonnet)** - Coût Principal
```
Analyse transcripts : 22 × 20,000 tokens = 440k tokens input
Questions suivi : 22 × 8 × 500 = 88k tokens input
Réponses : 22 × 9 × 800 = 158k tokens output

Total mensuel :
- Input : 528k tokens × $3.00/1M = $1.58
- Output : 158k tokens × $15.00/1M = $2.37
Total Bedrock : $3.95/mois
```

### 2. **Stockage (impact TTL 3 mois)**
```
DynamoDB Storage (3 mois de données) :
- Chat history : 50 KB × 22 × 3 = 3.3 MB
- File metadata : 2 KB × 22 × 3 = 132 KB
Total : 3.4 MB × $0.25/GB = $0.0009/mois ≈ $0.00

S3 Storage (3 mois de fichiers) :
- Fichiers : 80 KB × 22 × 3 = 5.28 MB
- Frontend : 5 MB
Total : 10.28 MB × $0.023/GB = $0.0002/mois ≈ $0.00
```

### 3. **Autres Services** (inchangés)
```
Lambda : $0.03/mois
API Gateway : $0.00/mois
CloudFront : $0.01/mois
Cognito : $0.00/mois
```

---

## 🎯 **COÛT TOTAL AVEC TTL 3 MOIS**

| Service | Coût mensuel |
|---------|--------------|
| Bedrock (Claude 3.5) | $3.95 |
| Stockage (DynamoDB + S3) | $0.00 |
| Compute (Lambda + API) | $0.03 |
| Distribution (CloudFront) | $0.01 |
| Auth (Cognito) | $0.00 |
| **TOTAL** | **≈ $4.00/mois** |

---

## 📈 Impact du TTL sur les Coûts

### Comparaison TTL
| Période TTL | Stockage DDB | Stockage S3 | Impact coût |
|-------------|--------------|-------------|-------------|
| 1 mois | 1.1 MB | 1.8 MB | Base |
| **3 mois** | **3.4 MB** | **5.3 MB** | **+$0.00** |
| 6 mois | 6.6 MB | 10.6 MB | +$0.001 |
| 1 an | 13.2 MB | 21.1 MB | +$0.003 |

**Conclusion** : Le TTL de 3 mois n'a **aucun impact significatif** sur les coûts car les volumes restent très faibles.

---

## 💡 Avantages du TTL 3 mois

### ✅ **Bénéfices Business**
- **Conformité RGPD** : Conservation raisonnable
- **Analyse historique** : Patterns sur le trimestre
- **Référence passée** : Accès aux anciens comptes-rendus
- **Audit** : Traçabilité sur 90 jours

### ✅ **Bénéfices Techniques**
- **Performance** : Index DynamoDB optimaux
- **Compliance** : Suppression automatique
- **Maintenance** : Zéro intervention manuelle
- **Sécurité** : Limitation exposition données

---

## 🎯 **Recommandations**

### **Configuration Optimale**
```hcl
# infrastructure/modules/dynamodb/main.tf
ttl {
  attribute_name = "ttl"
  enabled        = true
}

# backend/functions/*/index.ts
const ttl = Math.floor(Date.now() / 1000) + (90 * 24 * 60 * 60); // 3 mois
```

### **Surveillance**
- **CloudWatch Alarm** si stockage > 100 MB
- **Budget AWS** alertes à $10/mois
- **Monitoring TTL** via métriques DynamoDB

---

## 📊 **ROI Final**

**Coût** : ~$4/mois pour automatiser les comptes-rendus
**Économie** : 2-3h de rédaction manuelle économisées/mois
**ROI** : > 1000% (basé sur coût horaire moyen)

**Le TTL de 3 mois offre le meilleur équilibre coût/fonctionnalité !** 🚀