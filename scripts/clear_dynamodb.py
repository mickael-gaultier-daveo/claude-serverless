#!/usr/bin/env python3
"""
Script pour vider la table DynamoDB des conversations non chiffrées
"""
import boto3
from botocore.exceptions import ClientError

# Configuration
TABLE_NAME = 'claude-serverless-prod-chat-history'
REGION = 'eu-west-3'

def delete_all_items():
    """Supprimer tous les items de la table DynamoDB"""
    dynamodb = boto3.resource('dynamodb', region_name=REGION)
    table = dynamodb.Table(TABLE_NAME)
    
    print(f"🔍 Scanning table {TABLE_NAME}...")
    
    # Scan pour récupérer tous les items
    response = table.scan()
    items = response.get('Items', [])
    
    # Gérer la pagination si nécessaire
    while 'LastEvaluatedKey' in response:
        response = table.scan(ExclusiveStartKey=response['LastEvaluatedKey'])
        items.extend(response.get('Items', []))
    
    print(f"📊 Found {len(items)} conversation(s) to delete")
    
    if len(items) == 0:
        print("✅ Table is already empty")
        return
    
    # Demander confirmation
    print(f"\n⚠️  WARNING: This will delete ALL {len(items)} conversation(s) from {TABLE_NAME}")
    print("This action is irreversible!")
    
    confirmation = input("\nType 'DELETE' to confirm: ")
    
    if confirmation != 'DELETE':
        print("❌ Deletion cancelled")
        return
    
    # Supprimer chaque item
    deleted_count = 0
    for item in items:
        try:
            table.delete_item(
                Key={
                    'user_id': item['user_id'],
                    'conversation_id': item['conversation_id']
                }
            )
            deleted_count += 1
            print(f"🗑️  Deleted conversation {item['conversation_id'][:8]}... ({deleted_count}/{len(items)})")
        except ClientError as e:
            print(f"❌ Error deleting {item['conversation_id']}: {e}")
    
    print(f"\n✅ Successfully deleted {deleted_count} conversation(s)")
    print(f"🔐 All future conversations will be encrypted with KMS")

if __name__ == '__main__':
    try:
        delete_all_items()
    except Exception as e:
        print(f"❌ Error: {e}")
        exit(1)
