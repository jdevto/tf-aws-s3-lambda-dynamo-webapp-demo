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
    Retrieve a single order by order_id
    """
    try:
        # Get order_id from path parameters
        order_id = event['pathParameters']['order_id']

        if not order_id:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'success': False,
                    'error': 'Order ID is required'
                })
            }

        # Get order from DynamoDB
        response = table.get_item(Key={'order_id': order_id})

        if 'Item' not in response:
            return {
                'statusCode': 404,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'success': False,
                    'error': 'Order not found'
                })
            }

        order = response['Item']

        # Convert Decimal to float for JSON serialization
        if 'total_amount' in order:
            order['total_amount'] = float(order['total_amount'])

        # Convert item prices to float
        if 'items' in order:
            for item in order['items']:
                if 'price' in item:
                    item['price'] = float(item['price'])
                if 'item_total' in item:
                    item['item_total'] = float(item['item_total'])

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
                'data': order
            })
        }

    except Exception as e:
        print(f"Error retrieving order: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'success': False,
                'error': 'Failed to retrieve order'
            })
        }
