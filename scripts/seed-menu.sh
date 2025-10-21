#!/bin/bash

# Script to seed the DynamoDB menu table with sample data
# Usage: ./seed-menu.sh <table-name>

set -e

# Check if required parameters are provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <table-name>"
    echo "Example: $0 restaurant-ordering-menu-items"
    echo "Note: Uses AWS CLI default region"
    exit 1
fi

TABLE_NAME=$1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_FILE="$SCRIPT_DIR/seed-data.json"

# Check if data file exists
if [ ! -f "$DATA_FILE" ]; then
    echo "Error: Data file $DATA_FILE not found"
    exit 1
fi

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed or not in PATH"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install jq to run this script"
    exit 1
fi

echo "Seeding menu data into DynamoDB table: $TABLE_NAME"
echo "Region: $(aws configure get region 2>/dev/null || echo 'default')"
echo "Data file: $DATA_FILE"
echo ""

# Verify table exists
echo "Verifying table exists..."
if ! aws dynamodb describe-table --table-name "$TABLE_NAME" > /dev/null 2>&1; then
    echo "Error: Table $TABLE_NAME does not exist in the current AWS region"
    exit 1
fi

echo "Table found. Starting to seed data..."
echo ""

# Read and process each menu item
item_count=0
success_count=0
error_count=0

# Process each item in the JSON array
while read -r item; do
    item_count=$((item_count + 1))

    # Extract item details
    item_id=$(echo "$item" | jq -r '.item_id')
    name=$(echo "$item" | jq -r '.name')

    echo "Processing item $item_count: $name (ID: $item_id)"

    # Convert the item to DynamoDB format
    # Convert all string fields to DynamoDB S type and price to N type
    dynamodb_item=$(echo "$item" | jq '{
        item_id: {"S": .item_id},
        name: {"S": .name},
        description: {"S": .description},
        price: {"N": (.price | tostring)},
        category: {"S": .category}
    }')

    # Put item into DynamoDB
    if aws dynamodb put-item \
        --table-name "$TABLE_NAME" \
        --item "$dynamodb_item" \
        --return-consumed-capacity TOTAL; then
        echo "  ✓ Successfully added $name"
        success_count=$((success_count + 1))
    else
        echo "  ✗ Failed to add $name"
        error_count=$((error_count + 1))
    fi

    echo ""
done < <(jq -c '.[]' "$DATA_FILE")

echo "Seeding completed!"
echo "Total items processed: $item_count"
echo "Successfully added: $success_count"
echo "Errors: $error_count"

if [ $error_count -eq 0 ]; then
    echo ""
    echo "✓ All menu items have been successfully seeded!"
    echo "You can now test the restaurant ordering application."
else
    echo ""
    echo "⚠ Some items failed to be added. Please check the errors above."
    exit 1
fi
