"""
Lambda function pour le chat avec Claude via Bedrock avec streaming
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

def streaming_handler(event: Dict[str, Any], context: Any):
    """
    Generator pour le streaming de réponses
    """
    try:
        # Log de debug pour voir la structure de l'event
        print(f"DEBUG: Event keys: {list(event.keys())}")
        print(f"DEBUG: Event: {json.dumps(event, default=str)[:500]}")
        
        # Validation de la méthode HTTP (Lambda Function URL format 2.0)
        request_context = event.get('requestContext', {})
        http_method = (
            event.get('httpMethod') or  # API Gateway format
            request_context.get('http', {}).get('method') or  # Function URL format 2.0
            request_context.get('requestContext', {}).get('http', {}).get('method')  # Nested format
        )
        print(f"DEBUG: HTTP Method: {http_method}")
        
        if http_method == 'OPTIONS':
            yield json.dumps({'message': 'OK'}).encode('utf-8')
        elif http_method != 'POST':
            yield json.dumps({'type': 'error', 'content': f'Method not allowed: {http_method}'}).encode('utf-8')
        else:
            # Extraction de l'utilisateur
            user_id = extract_user_id(event)
            print(f"DEBUG: User ID: {user_id}")
            if not user_id:
                yield json.dumps({'type': 'error', 'content': 'Unauthorized'}).encode('utf-8')
            else:
                # Validation du body
                body, error = validate_json_body(event, ['message'])
                if error:
                    yield json.dumps({'type': 'error', 'content': error}).encode('utf-8')
                else:
                    # Traiter la requête avec streaming
                    for chunk in process_chat_request_stream_generator(user_id, body):
                        yield chunk

    except Exception as e:
        log_error('chat_handler', e)
        yield json.dumps({
            'type': 'error',
            'content': f'Internal server error: {str(e)}'
        }).encode('utf-8')

def lambda_handler(event: Dict[str, Any], context: Any):
    """
    Handler principal pour les requêtes de chat.
    Accumule tous les chunks et les retourne en une seule réponse NDJSON.
    """
    try:
        # Vérifier si c'est une requête OPTIONS pour CORS
        http_method = event.get('httpMethod', event.get('requestContext', {}).get('http', {}).get('method'))
        
        if http_method == 'OPTIONS':
            # Les headers CORS sont gérés par la Lambda Function URL
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'OK'})
            }
        
        # Accumuler tous les chunks du générateur
        chunks = []
        for chunk in streaming_handler(event, context):
            chunks.append(chunk.decode('utf-8') if isinstance(chunk, bytes) else chunk)
        
        # Retourner la réponse complète
        # Note: Les headers CORS sont gérés par la Lambda Function URL, pas besoin de les ajouter ici
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/x-ndjson',
                'Cache-Control': 'no-cache'
            },
            'body': ''.join(chunks)
        }
        
    except Exception as e:
        log_error('lambda_handler', e)
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json'
            },
            'body': json.dumps({
                'type': 'error',
                'content': f'Internal server error: {str(e)}'
            })
        }

def process_chat_request_stream_generator(user_id: str, body: Dict[str, Any]):
    """
    Générateur pour traiter une requête de chat avec streaming
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
    
    # Envoyer les métadonnées de début
    start_data = {
        'type': 'start',
        'conversationId': conversation_id,
        'timestamp': timestamp
    }
    yield (json.dumps(start_data) + '\n').encode('utf-8')
    
    # Appel à Bedrock Claude avec streaming
    assistant_response = ""
    for chunk in call_bedrock_claude_stream_generator(context_messages):
        assistant_response += chunk.decode('utf-8') if isinstance(chunk, bytes) else chunk
        yield chunk
    
    # Envoyer les métadonnées de fin
    end_data = {
        'type': 'end',
        'timestamp': int(time.time() * 1000)
    }
    yield ('\n' + json.dumps(end_data)).encode('utf-8')
    
    assistant_message = {
        'role': 'assistant',
        'content': assistant_response,
        'timestamp': int(time.time() * 1000)
    }
    
    # Sauvegarder la conversation
    updated_messages = conversation_history + [user_message, assistant_message]
    save_conversation(user_id, conversation_id, updated_messages)

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

def call_bedrock_claude_stream_generator(messages: List[Dict[str, Any]]):
    """
    Générateur pour appeler Claude via Bedrock avec streaming
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
        
        # Appel à Bedrock Claude 4.5 Sonnet avec streaming
        bedrock_response = bedrock_client.invoke_model_with_response_stream(
            modelId='eu.anthropic.claude-sonnet-4-5-20250929-v1:0',
            contentType='application/json',
            body=json.dumps(request_body)
        )
        
        # Traiter le stream de réponse
        stream = bedrock_response.get('body')
        
        if stream:
            for event in stream:
                chunk = event.get('chunk')
                if chunk:
                    chunk_data = json.loads(chunk.get('bytes').decode())
                    
                    # Bedrock renvoie différents types d'événements
                    if chunk_data['type'] == 'content_block_delta':
                        if 'delta' in chunk_data and 'text' in chunk_data['delta']:
                            text_chunk = chunk_data['delta']['text']
                            
                            # Envoyer le chunk au client
                            chunk_message = {
                                'type': 'chunk',
                                'content': text_chunk
                            }
                            yield (json.dumps(chunk_message) + '\n').encode('utf-8')
            
    except Exception as e:
        log_error('call_bedrock_claude_stream_generator', e)
        error_message = f"Erreur lors de l'appel à Claude: {str(e)}"
        
        # Envoyer l'erreur au client
        error_chunk = {
            'type': 'error',
            'content': error_message
        }
        yield (json.dumps(error_chunk) + '\n').encode('utf-8')

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
