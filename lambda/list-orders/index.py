import json
import boto3
import os
from decimal import Decimal

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
table_name = os.environ['ORDERS_TABLE_NAME']
table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    """
    List orders with optional status filter
    """
    try:
        # Get query parameters
        query_params = event.get('queryStringParameters') or {}
        status_filter = query_params.get('status')

        # Build scan parameters
        scan_params = {}
        if status_filter:
            scan_params['FilterExpression'] = 'status = :status'
            scan_params['ExpressionAttributeValues'] = {':status': status_filter}

        # Scan the orders table
        response = table.scan(**scan_params)
        orders = response['Items']

        # Convert Decimal to float for JSON serialization
        for order in orders:
            if 'total_amount' in order:
                order['total_amount'] = float(order['total_amount'])

            # Convert item prices to float
            if 'items' in order:
                for item in order['items']:
                    if 'price' in item:
                        item['price'] = float(item['price'])
                    if 'item_total' in item:
                        item['item_total'] = float(item['item_total'])

        # Sort by created_at (newest first)
        orders.sort(key=lambda x: x.get('created_at', ''), reverse=True)

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
                'data': orders,
                'count': len(orders)
            })
        }

    except Exception as e:
        print(f"Error listing orders: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'success': False,
                'error': 'Failed to list orders'
            })
        }
