#!/usr/bin/env python3
"""
Script pour ajouter un TTL d'1 an à toutes les entrées existantes dans la table usage-tracking
"""
import boto3
from datetime import datetime, timedelta
import time

# Configuration
TABLE_NAME = 'claude-serverless-prod-usage-tracking'
REGION = 'eu-west-3'

def main():
    dynamodb = boto3.resource('dynamodb', region_name=REGION)
    table = dynamodb.Table(TABLE_NAME)
    
    # Calculer le TTL (1 an à partir de maintenant)
    ttl_date = datetime.now() + timedelta(days=365)
    ttl_timestamp = int(time.mktime(ttl_date.timetuple()))
    
    print(f"🔄 Scanning table {TABLE_NAME}...")
    print(f"📅 TTL will be set to: {ttl_date.strftime('%Y-%m-%d %H:%M:%S')} (timestamp: {ttl_timestamp})")
    
    # Scanner tous les éléments
    response = table.scan()
    items = response.get('Items', [])
    
    # Gérer la pagination si nécessaire
    while 'LastEvaluatedKey' in response:
        response = table.scan(ExclusiveStartKey=response['LastEvaluatedKey'])
        items.extend(response.get('Items', []))
    
    print(f"📊 Found {len(items)} items to update")
    
    updated_count = 0
    error_count = 0
    
    # Mettre à jour chaque élément
    for item in items:
        try:
            user_id = item['user_id']
            month = item['month']
            
            table.update_item(
                Key={
                    'user_id': user_id,
                    'month': month
                },
                UpdateExpression='SET #ttl = :ttl',
                ExpressionAttributeNames={
                    '#ttl': 'ttl'
                },
                ExpressionAttributeValues={
                    ':ttl': ttl_timestamp
                }
            )
            updated_count += 1
            print(f"✅ Updated {user_id} - {month}")
        except Exception as e:
            error_count += 1
            print(f"❌ Error updating {user_id} - {month}: {e}")
    
    print(f"\n📈 Summary:")
    print(f"   Total items: {len(items)}")
    print(f"   ✅ Updated: {updated_count}")
    print(f"   ❌ Errors: {error_count}")
    print(f"\n✨ Done! All items will expire on {ttl_date.strftime('%Y-%m-%d')}")

if __name__ == '__main__':
    main()
