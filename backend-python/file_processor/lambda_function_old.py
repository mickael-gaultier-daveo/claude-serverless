"""
Lambda function pour le traitement de fichiers en mémoire
"""
import json
import os
import sys
import base64
import io
from typing import Dict, Any, Optional

# Ajouter le répertoire shared au path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'shared'))

from utils import (
    create_response, extract_user_id, validate_json_body, log_error
)

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Handler principal pour le traitement de fichiers en mémoire
    """
    try:
        # Validation de la méthode HTTP
        if event.get('httpMethod') != 'POST':
            return create_response(405, {'error': 'Method not allowed'})

        # Extraction de l'utilisateur
        user_id = extract_user_id(event)
        if not user_id:
            return create_response(401, {'error': 'Unauthorized'})

        # Validation du body
        body, error = validate_json_body(event, ['fileName', 'fileType', 'fileContent'])
        if error:
            return create_response(400, {'error': error})

        # Traitement du fichier en mémoire
        response_data = process_file_content(user_id, body)
        return create_response(200, response_data)

    except Exception as e:
        log_error('file_processor', e, {'user_id': user_id if 'user_id' in locals() else None})
        return create_response(500, {
            'error': 'Internal server error',
            'message': str(e)
        })

def process_file_content(user_id: str, body: Dict[str, Any]) -> Dict[str, Any]:
    """
    Traiter le contenu d'un fichier en mémoire et extraire le texte
    """
    file_name = body['fileName']
    file_type = body['fileType'] 
    file_content_b64 = body['fileContent']
    
    # Décoder le contenu base64
    try:
        file_buffer = base64.b64decode(file_content_b64)
    except Exception as e:
        raise ValueError(f"Erreur décodage base64: {e}")
    
    # Extraction du contenu textuel directement en mémoire
    extracted_text, processing_error = extract_text_from_file(file_buffer, file_type, file_name)
    
    if processing_error:
        return {
            'success': False,
            'error': processing_error,
            'fileName': file_name,
            'fileSize': len(file_buffer)
        }
    
    return {
        'success': True,
        'fileName': file_name,
        'fileSize': len(file_buffer),
        'extractedText': extracted_text,
        'textLength': len(extracted_text)
    }

def extract_text_from_file(file_buffer: bytes, mime_type: str, file_name: str) -> tuple[str, Optional[str]]:
    """
    Extraire le texte d'un fichier selon son type
    """
    try:
        # Déterminer l'extension
        extension = file_name.split('.')[-1].lower() if '.' in file_name else ''
        
        # PDF
        if mime_type == 'application/pdf' or extension == 'pdf':
            return extract_pdf_text(file_buffer)
        
        # DOCX
        if mime_type == 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' or extension == 'docx':
            return extract_docx_text(file_buffer)
        
        # CSV
        if mime_type == 'text/csv' or extension == 'csv':
            return extract_csv_text(file_buffer)
        
        # Fichiers texte
        if (mime_type.startswith('text/') or 
            extension in ['txt', 'json', 'md', 'js', 'ts', 'py', 'java', 'cpp', 'c', 'html', 'css', 'xml', 'yaml', 'yml']):
            return extract_text_file(file_buffer)
        
        # Type non supporté
        return "", f"Type de fichier non supporté: {mime_type} (.{extension})"
        
    except Exception as e:
        error_msg = f"Erreur extraction texte: {str(e)}"
        log_error('extract_text_from_file', e, {
            'mime_type': mime_type,
            'file_name': file_name
        })
        return "", error_msg

def extract_pdf_text(file_buffer: bytes) -> Tuple[str, str]:
    """Extraire le texte d'un PDF"""
    try:
        import PyPDF2
        
        pdf_reader = PyPDF2.PdfReader(io.BytesIO(file_buffer))
        text_parts = []
        
        for page_num, page in enumerate(pdf_reader.pages):
            try:
                text = page.extract_text()
                if text.strip():
                    text_parts.append(text)
            except Exception as e:
                log_error('extract_pdf_page', e, {'page_num': page_num})
        
        full_text = '\n\n'.join(text_parts)
        return full_text, None
        
    except ImportError:
        return "", "PyPDF2 non installé"
    except Exception as e:
        return "", f"Erreur extraction PDF: {str(e)}"

def extract_docx_text(file_buffer: bytes) -> Tuple[str, str]:
    """Extraire le texte d'un DOCX"""
    try:
        import docx
        
        doc = docx.Document(io.BytesIO(file_buffer))
        text_parts = []
        
        for paragraph in doc.paragraphs:
            if paragraph.text.strip():
                text_parts.append(paragraph.text)
        
        full_text = '\n\n'.join(text_parts)
        return full_text, None
        
    except ImportError:
        return "", "python-docx non installé"
    except Exception as e:
        return "", f"Erreur extraction DOCX: {str(e)}"

def extract_csv_text(file_buffer: bytes) -> Tuple[str, str]:
    """Extraire et structurer le contenu d'un CSV"""
    try:
        import csv
        
        # Décodage avec plusieurs encodages possibles
        content = None
        for encoding in ['utf-8', 'latin-1', 'cp1252']:
            try:
                content = file_buffer.decode(encoding)
                break
            except UnicodeDecodeError:
                continue
        
        if content is None:
            return "", "Impossible de décoder le fichier CSV"
        
        # Parse CSV
        csv_reader = csv.DictReader(io.StringIO(content))
        rows = list(csv_reader)
        
        # Convertir en JSON structuré
        structured_data = json.dumps(rows, ensure_ascii=False, indent=2)
        return structured_data, None
        
    except Exception as e:
        return "", f"Erreur extraction CSV: {str(e)}"

def extract_text_file(file_buffer: bytes) -> Tuple[str, str]:
    """Extraire le contenu d'un fichier texte"""
    try:
        # Décodage avec plusieurs encodages possibles
        for encoding in ['utf-8', 'latin-1', 'cp1252']:
            try:
                content = file_buffer.decode(encoding)
                return content, None
            except UnicodeDecodeError:
                continue
        
        return "", "Impossible de décoder le fichier texte"
        
    except Exception as e:
        return "", f"Erreur extraction texte: {str(e)}"

def save_file_metadata(file_id: str, user_id: str, file_name: str, 
                      file_type: str, file_size: int, s3_key: str,
                      extracted_text: str, timestamp: int, 
                      processing_error: str):
    """
    Sauvegarder les métadonnées d'un fichier en DynamoDB
    """
    try:
        table_name = f"{os.environ.get('ENVIRONMENT', 'dev')}-file-metadata"
        table = get_dynamodb_table(table_name)
        
        table.put_item(
            Item={
                'file_id': file_id,
                'user_id': user_id,
                'file_name': file_name,
                'file_type': file_type,
                'file_size': file_size,
                's3_key': s3_key,
                'extracted_text': extracted_text,
                'upload_timestamp': timestamp,
                'processing_error': processing_error,
                'ttl': generate_ttl(90)  # 3 mois
            }
        )
        
    except Exception as e:
        log_error('save_file_metadata', e, {
            'file_id': file_id,
            'user_id': user_id
        })

# Import time au niveau du module
import time