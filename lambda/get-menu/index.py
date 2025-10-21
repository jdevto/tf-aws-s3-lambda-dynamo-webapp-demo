import json
import boto3
import os
from decimal import Decimal

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
table_name = os.environ['MENU_TABLE_NAME']
table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    """
    Retrieve all menu items from DynamoDB
    """
    try:
        # Scan the menu items table
        response = table.scan()
        items = response['Items']

        # Convert Decimal to float for JSON serialization
        for item in items:
            if 'price' in item:
                item['price'] = float(item['price'])

        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type'
            },
            'body': json.dumps({
                'success': True,
                'data': items
            })
        }

    except Exception as e:
        print(f"Error retrieving menu items: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'success': False,
                'error': 'Failed to retrieve menu items'
            })
        }
