"""
Fonctions utilitaires partagées
"""
import json
import time
import uuid
import logging
from typing import Dict, Any, List, Optional
from datetime import datetime, timedelta

# Configuration du logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def create_response(status_code: int, body: Dict[str, Any], 
                   cors_headers: Optional[Dict[str, str]] = None) -> Dict[str, Any]:
    """Créer une réponse API Gateway standardisée"""
    
    # Domaines autorisés pour CORS
    allowed_origins = [
        'https://claude-serverless.daveo-dev.fr',
        # CloudFront domains (pattern match)
        '*.cloudfront.net'
    ]
    
    default_headers = {
        'Access-Control-Allow-Origin': 'https://claude-serverless.daveo-dev.fr',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
        'Access-Control-Allow-Methods': 'GET,OPTIONS,POST,PUT',
        'Content-Type': 'application/json'
    }
    
    if cors_headers:
        default_headers.update(cors_headers)
    
    return {
        'statusCode': status_code,
        'headers': default_headers,
        'body': json.dumps(body, ensure_ascii=False, default=str)
    }

def extract_user_id(event: Dict[str, Any]) -> Optional[str]:
    """Extraire l'ID utilisateur depuis le contexte d'autorisation Cognito"""
    try:
        authorizer = event.get('requestContext', {}).get('authorizer', {})
        claims = authorizer.get('claims', {})
        return claims.get('sub')
    except Exception as e:
        logger.error(f"Erreur extraction user_id: {e}")
        return None

def generate_ttl(days: int = 90) -> int:
    """Générer un TTL DynamoDB (timestamp Unix)"""
    return int(time.time()) + (days * 24 * 60 * 60)

def generate_id() -> str:
    """Générer un UUID unique"""
    return str(uuid.uuid4())

def validate_json_body(event: Dict[str, Any], required_fields: List[str]) -> tuple[Dict[str, Any], Optional[str]]:
    """Valider le body JSON et les champs requis"""
    try:
        body = json.loads(event.get('body', '{}'))
        
        missing_fields = [field for field in required_fields if field not in body]
        if missing_fields:
            return {}, f"Champs manquants: {', '.join(missing_fields)}"
        
        return body, None
        
    except json.JSONDecodeError:
        return {}, "Body JSON invalide"

def format_conversation_messages(messages: List[Dict[str, Any]]) -> List[Dict[str, str]]:
    """Formater les messages pour l'API Bedrock"""
    formatted = []
    for msg in messages:
        formatted.append({
            'role': msg['role'],
            'content': msg['content']
        })
    return formatted

def log_error(function_name: str, error: Exception, context: Dict[str, Any] = None):
    """Logger une erreur avec contexte"""
    error_data = {
        'function': function_name,
        'error': str(error),
        'error_type': type(error).__name__,
    }
    if context:
        error_data['context'] = context
    
    logger.error(json.dumps(error_data))

def sanitize_filename(filename: str) -> str:
    """Nettoyer un nom de fichier pour S3"""
    import re
    # Supprimer les caractères non-alphanumériques (garder . - _)
    sanitized = re.sub(r'[^a-zA-Z0-9._-]', '_', filename)
    return sanitized[:100]  # Limiter la longueur