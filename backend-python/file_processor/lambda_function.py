"""
Lambda function pour le traitement de fichiers en mémoire
"""
import json
import os
import sys
import base64
import io
from typing import Optional

# Ajouter le répertoire shared au path
sys.path.append(os.path.join(os.path.dirname(__file__), 'shared'))

from utils import create_response, extract_user_id, validate_json_body, log_error

def lambda_handler(event, context):
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

def process_file_content(user_id: str, body: dict):
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
        
        # Fichiers texte
        if (mime_type.startswith('text/') or 
            extension in ['txt', 'json', 'md', 'js', 'ts', 'py', 'java', 'cpp', 'c', 'html', 'css', 'xml']):
            return extract_text_file(file_buffer)
        
        # Type non supporté
        return "", f"Type de fichier non supporté: {mime_type} (.{extension})"
        
    except Exception as e:
        return "", f"Erreur lors de l'extraction du texte: {str(e)}"

def extract_pdf_text(file_buffer: bytes) -> tuple[str, Optional[str]]:
    """
    Extraire le texte d'un fichier PDF
    """
    try:
        import PyPDF2
        
        pdf_file = io.BytesIO(file_buffer)
        pdf_reader = PyPDF2.PdfReader(pdf_file)
        
        text_content = []
        for page_num in range(len(pdf_reader.pages)):
            page = pdf_reader.pages[page_num]
            text_content.append(page.extract_text())
        
        extracted_text = '\n'.join(text_content)
        
        if not extracted_text.strip():
            return "", "Aucun texte trouvé dans le PDF"
        
        return extracted_text, None
        
    except Exception as e:
        return "", f"Erreur extraction PDF: {str(e)}"

def extract_docx_text(file_buffer: bytes) -> tuple[str, Optional[str]]:
    """
    Extraire le texte d'un fichier DOCX
    """
    try:
        import docx
        
        docx_file = io.BytesIO(file_buffer)
        doc = docx.Document(docx_file)
        
        text_content = []
        for paragraph in doc.paragraphs:
            if paragraph.text.strip():
                text_content.append(paragraph.text)
        
        extracted_text = '\n'.join(text_content)
        
        if not extracted_text.strip():
            return "", "Aucun texte trouvé dans le document Word"
        
        return extracted_text, None
        
    except Exception as e:
        return "", f"Erreur extraction DOCX: {str(e)}"

def extract_text_file(file_buffer: bytes) -> tuple[str, Optional[str]]:
    """
    Extraire le contenu d'un fichier texte
    """
    try:
        # Essayer différents encodages
        for encoding in ['utf-8', 'latin-1', 'cp1252']:
            try:
                text_content = file_buffer.decode(encoding)
                return text_content, None
            except UnicodeDecodeError:
                continue
        
        return "", "Impossible de décoder le fichier texte"
        
    except Exception as e:
        return "", f"Erreur extraction fichier texte: {str(e)}"