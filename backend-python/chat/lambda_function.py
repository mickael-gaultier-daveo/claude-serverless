"""
Lambda function pour le chat avec Claude via Bedrock
"""
import json
import os
import sys
import time
from typing import Dict, Any, List

# Ajouter le répertoire shared au path
sys.path.append(os.path.join(os.path.dirname(__file__), 'shared'))

from aws_clients import get_bedrock_client, get_dynamodb_table
from utils import (
    create_response, extract_user_id, generate_ttl, generate_id,
    validate_json_body, format_conversation_messages, log_error
)

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Handler principal pour les requêtes de chat
    """
    try:
        # Validation de la méthode HTTP
        http_method = event.get('httpMethod', event.get('requestContext', {}).get('http', {}).get('method'))
        
        if http_method == 'OPTIONS':
            return create_response(200, {'message': 'OK'})
        
        if http_method != 'POST':
            return create_response(405, {'error': 'Method not allowed'})

        # Extraction de l'utilisateur
        user_id = extract_user_id(event)
        if not user_id:
            return create_response(401, {'error': 'Unauthorized'})

        # Validation du body
        body, error = validate_json_body(event, ['message'])
        if error:
            return create_response(400, {'error': error})

        # Traiter la requête
        result = process_chat_request(user_id, body)
        return create_response(200, result)

    except Exception as e:
        log_error('chat_handler', e)
        return create_response(500, {
            'error': 'Internal server error',
            'message': str(e)
        })

def process_chat_request(user_id: str, body: Dict[str, Any]) -> Dict[str, Any]:
    """
    Traiter une requête de chat
    """
    message = body['message']
    conversation_id = body.get('conversationId', generate_id())
    file_contents = body.get('fileContents', [])
    
    timestamp = int(time.time() * 1000)
    
    # Récupérer l'historique de conversation
    conversation_history = get_conversation_history(user_id, conversation_id)
    
    # Construire le contexte des messages
    context_messages = conversation_history.copy()
    
    # Ajouter le contenu des fichiers si fourni
    if file_contents:
        files_context = "\n\n".join([
            f"<file_{i+1}>\n{content}\n</file_{i+1}>"
            for i, content in enumerate(file_contents)
        ])
        
        context_messages.append({
            'role': 'user',
            'content': f"Voici les fichiers fournis en contexte:\n\n{files_context}",
            'timestamp': timestamp - 1
        })
    
    # Ajouter le message utilisateur
    user_message = {
        'role': 'user',
        'content': message,
        'timestamp': timestamp
    }
    context_messages.append(user_message)
    
    # Appel à Bedrock Claude
    assistant_response = call_bedrock_claude(context_messages)
    
    assistant_message = {
        'role': 'assistant',
        'content': assistant_response,
        'timestamp': int(time.time() * 1000)
    }
    
    # Sauvegarder la conversation
    updated_messages = conversation_history + [user_message, assistant_message]
    save_conversation(user_id, conversation_id, updated_messages)
    
    return {
        'response': assistant_response,
        'conversationId': conversation_id,
        'timestamp': assistant_message['timestamp']
    }

def get_conversation_history(user_id: str, conversation_id: str) -> List[Dict[str, Any]]:
    """
    Récupérer l'historique d'une conversation
    """
    try:
        table_name = os.environ.get('DYNAMODB_TABLE')
        if not table_name:
            return []
        
        table = get_dynamodb_table(table_name)
        
        response = table.get_item(
            Key={
                'user_id': user_id,
                'conversation_id': conversation_id
            }
        )
        
        if 'Item' in response:
            return response['Item'].get('messages', [])
        
        return []
        
    except Exception as e:
        log_error('get_conversation_history', e, {
            'user_id': user_id, 
            'conversation_id': conversation_id
        })
        return []

def call_bedrock_claude(messages: List[Dict[str, Any]]) -> str:
    """
    Appeler Claude via Bedrock
    """
    try:
        bedrock_client = get_bedrock_client()
        
        # Formater les messages pour Bedrock
        formatted_messages = format_conversation_messages(messages)
        
        # Préparer la requête Bedrock
        request_body = {
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 4000,
            "messages": formatted_messages,
            "system": "Tu es un assistant IA utile et bienveillant. Tu peux analyser des documents et répondre aux questions à leur sujet. Réponds de manière claire et structurée."
        }
        
        # Appel à Bedrock Claude 4.5 Sonnet via profil d'inférence
        response = bedrock_client.invoke_model(
            modelId='eu.anthropic.claude-sonnet-4-5-20250929-v1:0',
            contentType='application/json',
            body=json.dumps(request_body)
        )
        
        # Traiter la réponse
        response_body = json.loads(response['body'].read())
        
        if 'content' in response_body and len(response_body['content']) > 0:
            return response_body['content'][0]['text']
        else:
            return "Désolé, je n'ai pas pu générer une réponse."
            
    except Exception as e:
        log_error('call_bedrock_claude', e)
        return f"Erreur lors de l'appel à Claude: {str(e)}"

def save_conversation(user_id: str, conversation_id: str, messages: List[Dict[str, Any]]):
    """
    Sauvegarder une conversation en DynamoDB
    """
    try:
        table_name = os.environ.get('DYNAMODB_TABLE')
        if not table_name:
            return
        
        table = get_dynamodb_table(table_name)
        
        # Garder seulement les 20 derniers messages
        recent_messages = messages[-20:] if len(messages) > 20 else messages
        
        table.put_item(
            Item={
                'user_id': user_id,
                'conversation_id': conversation_id,
                'messages': recent_messages,
                'timestamp': int(time.time() * 1000),
                'ttl': generate_ttl(90)  # 3 mois
            }
        )
        
    except Exception as e:
        log_error('save_conversation', e, {
            'user_id': user_id,
            'conversation_id': conversation_id
        })
