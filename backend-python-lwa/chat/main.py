"""
Lambda handler FastAPI avec Lambda Web Adapter pour streaming Bedrock
Compatible avec Python 3.13 + vrai streaming progressif
"""
import boto3
import json
import os
import time
import base64
from typing import Optional
from uuid import uuid4

from fastapi import FastAPI, HTTPException, Header
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
import uvicorn
import io
from docx import Document
from openpyxl import load_workbook
from pptx import Presentation
from PyPDF2 import PdfReader

# Clients AWS
bedrock_client = boto3.client('bedrock-runtime', region_name='eu-west-3')
dynamodb = boto3.resource('dynamodb', region_name='eu-west-3')

# Configuration
MODEL_ID = 'eu.anthropic.claude-sonnet-4-5-20250929-v1:0'
DYNAMODB_TABLE = os.environ.get('DYNAMODB_TABLE', 'claude-serverless-prod-chat-history')

# FastAPI app
app = FastAPI(title="Claude Chat API with Streaming")


class FileData(BaseModel):
    fileName: str
    fileType: str
    fileContent: str  # base64


class ChatRequest(BaseModel):
    message: str
    conversationId: Optional[str] = None
    files: Optional[list[FileData]] = None
    # Rétro-compatibilité
    fileContents: Optional[list[str]] = None


def extract_user_id(authorization: Optional[str]) -> Optional[str]:
    """Extraire le user ID depuis le JWT"""
    if not authorization or not authorization.startswith('Bearer '):
        return None
    
    try:
        token = authorization.split(' ')[1]
        parts = token.split('.')
        if len(parts) != 3:
            return None
        
        # Décoder le payload JWT
        payload = parts[1]
        padding = 4 - (len(payload) % 4)
        if padding != 4:
            payload += '=' * padding
        
        decoded = base64.urlsafe_b64decode(payload)
        claims = json.loads(decoded)
        return claims.get('sub')
    except Exception as e:
        print(f"Error extracting user ID: {e}")
        return None


def extract_text_from_file(file_content_b64: str, file_type: str, file_name: str) -> str:
    """Extraire le texte d'un fichier selon son type"""
    try:
        # Décoder le base64
        file_bytes = base64.b64decode(file_content_b64)
        file_io = io.BytesIO(file_bytes)
        
        print(f"Extracting {file_name} ({file_type}), size: {len(file_bytes)} bytes")
        
        # PDF
        if file_type == 'application/pdf' or file_name.lower().endswith('.pdf'):
            reader = PdfReader(file_io)
            text = '\n'.join([page.extract_text() for page in reader.pages])
            print(f"PDF extracted: {len(text)} chars")
            return text
        
        # DOCX
        elif file_type == 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' or file_name.lower().endswith('.docx'):
            doc = Document(file_io)
            text = '\n'.join([para.text for para in doc.paragraphs])
            print(f"DOCX extracted: {len(text)} chars, {len(doc.paragraphs)} paragraphs")
            return text
        
        # XLSX
        elif file_type == 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' or file_name.lower().endswith('.xlsx'):
            wb = load_workbook(file_io, data_only=True)
            text_parts = []
            for sheet_name in wb.sheetnames:
                sheet = wb[sheet_name]
                text_parts.append(f"\n=== Feuille: {sheet_name} ===\n")
                for row in sheet.iter_rows(values_only=True):
                    row_text = '\t'.join([str(cell) if cell is not None else '' for cell in row])
                    if row_text.strip():
                        text_parts.append(row_text)
            return '\n'.join(text_parts)
        
        # PPTX
        elif file_type == 'application/vnd.openxmlformats-officedocument.presentationml.presentation' or file_name.lower().endswith('.pptx'):
            prs = Presentation(file_io)
            text_parts = []
            for i, slide in enumerate(prs.slides, 1):
                text_parts.append(f"\n=== Slide {i} ===\n")
                for shape in slide.shapes:
                    if hasattr(shape, "text"):
                        text_parts.append(shape.text)
            return '\n'.join(text_parts)
        
        # TXT, CSV, JSON, etc.
        elif file_type.startswith('text/') or file_name.lower().endswith(('.txt', '.csv', '.json', '.md')):
            return file_bytes.decode('utf-8', errors='ignore')
        
        else:
            return f"[Fichier {file_name}: type non supporté pour extraction de texte]"
    
    except Exception as e:
        print(f"Error extracting text from file: {e}")
        return f"[Erreur lors de la lecture du fichier {file_name}: {str(e)}]"


def get_conversation_history(user_id: str, conversation_id: str) -> list:
    """Récupérer l'historique de conversation"""
    try:
        table = dynamodb.Table(DYNAMODB_TABLE)
        response = table.get_item(
            Key={
                'user_id': user_id,
                'conversation_id': conversation_id
            }
        )
        return response.get('Item', {}).get('messages', [])
    except Exception as e:
        print(f"Error getting conversation: {e}")
        return []


def save_conversation(user_id: str, conversation_id: str, messages: list):
    """Sauvegarder la conversation"""
    try:
        table = dynamodb.Table(DYNAMODB_TABLE)
        
        # Le TTL suffit pour limiter le nombre de conversations (90 jours)
        # Pas de limite artificielle sur le nombre de messages
        # (DynamoDB limite à 400KB par item, mais ça permet ~1000+ messages)
        
        ttl = int(time.time()) + (90 * 24 * 60 * 60)  # 90 jours
        
        table.put_item(
            Item={
                'user_id': user_id,
                'conversation_id': conversation_id,
                'messages': messages,
                'timestamp': int(time.time() * 1000),
                'ttl': ttl
            }
        )
    except Exception as e:
        print(f"Error saving conversation: {e}")


async def stream_bedrock_response(
    messages: list,
    conversation_id: str,
    user_id: str,
    conversation_history: list,
    user_message: dict
):
    """Générateur asynchrone pour streamer depuis Bedrock"""
    
    # Envoyer métadonnées de début
    yield json.dumps({
        'type': 'start',
        'conversationId': conversation_id,
        'timestamp': int(time.time() * 1000)
    }) + '\n'
    
    # Formater les messages pour Bedrock
    formatted_messages = [
        {'role': msg['role'], 'content': msg['content']}
        for msg in messages
    ]
    
    request_body = {
        'anthropic_version': 'bedrock-2023-05-31',
        'max_tokens': 4000,
        'messages': formatted_messages,
        'system': 'Tu es un assistant IA utile et bienveillant. Tu peux analyser des documents et répondre aux questions à leur sujet. Réponds de manière claire et structurée.'
    }
    
    full_response = ''
    
    try:
        # Appel streaming à Bedrock
        response = bedrock_client.invoke_model_with_response_stream(
            modelId=MODEL_ID,
            contentType='application/json',
            body=json.dumps(request_body)
        )
        
        # Traiter le stream
        stream = response.get('body')
        if stream:
            for event in stream:
                chunk = event.get('chunk')
                if chunk:
                    chunk_data = json.loads(chunk.get('bytes').decode())
                    
                    if chunk_data['type'] == 'content_block_delta':
                        if 'delta' in chunk_data and 'text' in chunk_data['delta']:
                            text_chunk = chunk_data['delta']['text']
                            full_response += text_chunk
                            
                            # Envoyer le chunk au client
                            yield json.dumps({
                                'type': 'chunk',
                                'content': text_chunk
                            }) + '\n'
        
        # Envoyer métadonnées de fin
        yield json.dumps({
            'type': 'end',
            'timestamp': int(time.time() * 1000)
        }) + '\n'
        
        # Sauvegarder la conversation après streaming
        if full_response:
            assistant_message = {
                'role': 'assistant',
                'content': full_response,
                'timestamp': int(time.time() * 1000)
            }
            updated_messages = conversation_history + [user_message, assistant_message]
            save_conversation(user_id, conversation_id, updated_messages)
        
    except Exception as e:
        print(f"Error in Bedrock streaming: {e}")
        yield json.dumps({
            'type': 'error',
            'content': f'Error calling Claude: {str(e)}'
        }) + '\n'


@app.post("/chat")
async def chat_endpoint(
    request: ChatRequest,
    authorization: Optional[str] = Header(None)
):
    """Endpoint de chat avec streaming"""
    
    # Vérifier l'authentification
    user_id = extract_user_id(authorization)
    if not user_id:
        raise HTTPException(status_code=401, detail="Unauthorized")
    
    # Générer ou utiliser l'ID de conversation
    conversation_id = request.conversationId or str(uuid4())
    
    # Récupérer l'historique
    conversation_history = get_conversation_history(user_id, conversation_id)
    
    # Construire le contexte
    context_messages = conversation_history.copy()
    
    # Traiter les fichiers
    files_metadata = []
    files_text = []
    
    # Support du nouveau format avec métadonnées
    if request.files:
        for file in request.files:
            text = extract_text_from_file(file.fileContent, file.fileType, file.fileName)
            files_text.append(f"<fichier nom='{file.fileName}'>\n{text}\n</fichier>")
            files_metadata.append({
                'name': file.fileName,
                'type': file.fileType
            })
    # Rétro-compatibilité avec l'ancien format
    elif request.fileContents:
        for i, content in enumerate(request.fileContents):
            file_name = f"document_{i+1}.txt"
            text = extract_text_from_file(content, 'text/plain', file_name)
            files_text.append(f"<fichier nom='{file_name}'>\n{text}\n</fichier>")
            files_metadata.append({
                'name': file_name,
                'type': 'text/plain'
            })
    
    # Ajouter les fichiers au contexte si présents
    if files_text:
        context_messages.append({
            'role': 'user',
            'content': f"Voici les fichiers fournis en contexte:\n\n{chr(10).join(files_text)}",
            'timestamp': int(time.time() * 1000) - 1
        })
    
    # Ajouter le message utilisateur
    timestamp = int(time.time() * 1000)
    user_message = {
        'role': 'user',
        'content': request.message,
        'timestamp': timestamp,
        'files': files_metadata if files_metadata else None
    }
    context_messages.append(user_message)
    
    # Retourner le streaming response
    return StreamingResponse(
        stream_bedrock_response(
            context_messages,
            conversation_id,
            user_id,
            conversation_history,
            user_message
        ),
        media_type='application/x-ndjson',
        headers={
            'Cache-Control': 'no-cache',
            'X-Accel-Buffering': 'no'  # Disable nginx buffering
        }
    )


@app.get("/conversations")
async def list_conversations_endpoint(
    authorization: Optional[str] = Header(None)
):
    """Lister toutes les conversations d'un utilisateur"""
    
    # Vérifier l'authentification
    user_id = extract_user_id(authorization)
    if not user_id:
        raise HTTPException(status_code=401, detail="Unauthorized")
    
    try:
        table = dynamodb.Table(DYNAMODB_TABLE)
        
        # Query DynamoDB pour récupérer toutes les conversations de l'utilisateur
        response = table.query(
            KeyConditionExpression='user_id = :user_id',
            ExpressionAttributeValues={
                ':user_id': user_id
            }
        )
        
        # Extraire les conversations et les trier par timestamp (plus récent en premier)
        conversations = []
        for item in response.get('Items', []):
            # Récupérer le premier et dernier message pour l'aperçu
            messages = item.get('messages', [])
            if messages:
                first_message = messages[0].get('content', '')[:100]  # Premier message tronqué
                conversations.append({
                    'conversationId': item['conversation_id'],
                    'timestamp': item.get('timestamp', 0),
                    'messageCount': len(messages),
                    'preview': first_message
                })
        
        # Trier par timestamp décroissant (plus récent en premier)
        conversations.sort(key=lambda x: x['timestamp'], reverse=True)
        
        return {
            'conversations': conversations,
            'count': len(conversations)
        }
    
    except Exception as e:
        print(f"Error listing conversations: {e}")
        raise HTTPException(status_code=500, detail=f"Error listing conversations: {str(e)}")


@app.get("/conversations/{conversation_id}")
async def get_conversation_endpoint(
    conversation_id: str,
    authorization: Optional[str] = Header(None)
):
    """Récupérer l'historique d'une conversation"""
    
    # Vérifier l'authentification
    user_id = extract_user_id(authorization)
    if not user_id:
        raise HTTPException(status_code=401, detail="Unauthorized")
    
    # Récupérer l'historique
    messages = get_conversation_history(user_id, conversation_id)
    
    return {
        'conversationId': conversation_id,
        'messages': messages
    }


@app.delete("/conversations/{conversation_id}")
async def delete_conversation_endpoint(
    conversation_id: str,
    authorization: Optional[str] = Header(None)
):
    """Supprimer une conversation"""
    
    # Vérifier l'authentification
    user_id = extract_user_id(authorization)
    if not user_id:
        raise HTTPException(status_code=401, detail="Unauthorized")
    
    try:
        table = dynamodb.Table(DYNAMODB_TABLE)
        table.delete_item(
            Key={
                'user_id': user_id,
                'conversation_id': conversation_id
            }
        )
        return {'success': True, 'conversationId': conversation_id}
    except Exception as e:
        print(f"Error deleting conversation: {e}")
        raise HTTPException(status_code=500, detail=f"Error deleting conversation: {str(e)}")


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "ok", "version": "1.0.0-lwa"}


if __name__ == "__main__":
    # Pour tests locaux
    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", "8080")))
