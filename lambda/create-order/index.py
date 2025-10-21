import json
import boto3
import os
import uuid
from datetime import datetime
from decimal import Decimal

# Force update: Fixed Decimal type handling for DynamoDB

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
orders_table_name = os.environ['ORDERS_TABLE_NAME']
menu_table_name = os.environ['MENU_TABLE_NAME']
orders_table = dynamodb.Table(orders_table_name)
menu_table = dynamodb.Table(menu_table_name)

def lambda_handler(event, context):
    """
    Create a new order and save it to DynamoDB
    """
    try:
        # Parse request body
        if isinstance(event['body'], str):
            body = json.loads(event['body'])
        else:
            body = event['body']

        # Validate required fields
        required_fields = ['customer_name', 'items']
        for field in required_fields:
            if field not in body:
                return {
                    'statusCode': 400,
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*'
                    },
                    'body': json.dumps({
                        'success': False,
                        'error': f'Missing required field: {field}'
                    })
                }

        customer_name = body['customer_name']
        items = body['items']

        if not isinstance(items, list) or len(items) == 0:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'success': False,
                    'error': 'Items must be a non-empty list'
                })
            }

        # Validate and calculate total
        total_amount = 0
        validated_items = []

        for item in items:
            if 'item_id' not in item or 'quantity' not in item:
                return {
                    'statusCode': 400,
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*'
                    },
                    'body': json.dumps({
                        'success': False,
                        'error': 'Each item must have item_id and quantity'
                    })
                }

            # Get menu item details
            try:
                menu_response = menu_table.get_item(Key={'item_id': item['item_id']})
                if 'Item' not in menu_response:
                    return {
                        'statusCode': 400,
                        'headers': {
                            'Content-Type': 'application/json',
                            'Access-Control-Allow-Origin': '*'
                        },
                        'body': json.dumps({
                            'success': False,
                            'error': f'Menu item {item["item_id"]} not found'
                        })
                    }

                menu_item = menu_response['Item']
                quantity = int(item['quantity'])
                if quantity <= 0:
                    return {
                        'statusCode': 400,
                        'headers': {
                            'Content-Type': 'application/json',
                            'Access-Control-Allow-Origin': '*'
                        },
                        'body': json.dumps({
                            'success': False,
                            'error': 'Quantity must be greater than 0'
                        })
                    }

                item_total = float(menu_item['price']) * quantity
                total_amount += item_total

                validated_items.append({
                    'item_id': item['item_id'],
                    'name': menu_item['name'],
                    'price': Decimal(str(menu_item['price'])),
                    'quantity': quantity,
                    'item_total': Decimal(str(round(item_total, 2)))
                })

            except Exception as e:
                return {
                    'statusCode': 500,
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*'
                    },
                    'body': json.dumps({
                        'success': False,
                        'error': f'Error validating menu item: {str(e)}'
                    })
                }

        # Generate order ID and timestamp
        order_id = str(uuid.uuid4())
        timestamp = datetime.utcnow().isoformat()

        # Create order record
        order = {
            'order_id': order_id,
            'customer_name': customer_name,
            'items': validated_items,
            'total_amount': Decimal(str(round(total_amount, 2))),
            'status': 'pending',
            'created_at': timestamp,
            'updated_at': timestamp
        }

        # Save order to DynamoDB
        orders_table.put_item(Item=order)

        # Convert Decimal to float for JSON response
        order_response = order.copy()
        order_response['total_amount'] = float(order_response['total_amount'])

        # Convert all Decimal values in items to float for JSON serialization
        for item in order_response['items']:
            item['price'] = float(item['price'])
            item['item_total'] = float(item['item_total'])

        return {
            'statusCode': 201,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type'
            },
            'body': json.dumps({
                'success': True,
                'data': order_response
            })
        }

    except Exception as e:
        print(f"Error creating order: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'success': False,
                'error': 'Failed to create order'
            })
        }
