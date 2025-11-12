"""
Clients AWS réutilisables pour les fonctions Lambda
"""
import boto3
import os
from botocore.config import Config

# Configuration avec retry pour la région principale
config = Config(
    region_name=os.environ.get('AWS_REGION', 'eu-west-3'),
    retries={'max_attempts': 3, 'mode': 'adaptive'}
)

# Configuration Bedrock pour Claude 4.5 Sonnet à Paris
bedrock_config = Config(
    region_name='eu-west-3',  # Paris - Claude 4.5 Sonnet
    retries={'max_attempts': 3, 'mode': 'adaptive'}
)

# Clients AWS
bedrock_runtime = boto3.client('bedrock-runtime', config=bedrock_config)
dynamodb = boto3.resource('dynamodb', config=config)
s3_client = boto3.client('s3', config=config)
cognito_client = boto3.client('cognito-idp', config=config)

def get_bedrock_client():
    """Retourne le client Bedrock Runtime"""
    return bedrock_runtime

def get_dynamodb_table(table_name: str):
    """Retourne une table DynamoDB"""
    return dynamodb.Table(table_name)

def get_s3_client():
    """Retourne le client S3"""
    return s3_client

def get_cognito_client():
    """Retourne le client Cognito"""
    return cognito_client