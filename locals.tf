# Get all Lambda function directories
locals {
  lambda_functions = {
    "get-menu" = {
      source_dir = "lambda/get-menu"
      environment_vars = {
        MENU_TABLE_NAME = aws_dynamodb_table.menu_items.name
      }
    }
    "create-order" = {
      source_dir = "lambda/create-order"
      environment_vars = {
        ORDERS_TABLE_NAME = aws_dynamodb_table.orders.name
        MENU_TABLE_NAME   = aws_dynamodb_table.menu_items.name
      }
    }
    "get-order" = {
      source_dir = "lambda/get-order"
      environment_vars = {
        ORDERS_TABLE_NAME = aws_dynamodb_table.orders.name
      }
    }
    "list-orders" = {
      source_dir = "lambda/list-orders"
      environment_vars = {
        ORDERS_TABLE_NAME = aws_dynamodb_table.orders.name
      }
    }
  }

  # API Gateway URL for frontend configuration
  api_gateway_url = "https://${aws_api_gateway_rest_api.restaurant_api.id}.execute-api.${data.aws_region.current.id}.amazonaws.com/${var.environment}"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  # File etags for S3 objects
  file_etags = {
    for file in fileset("${path.module}/website", "**/*") : file =>
    file == "app.js" ? local_file.app_js.content_md5 :
    file == "orders.html" ? local_file.orders_html.content_md5 :
    filemd5("${path.module}/website/${file}")
    if !can(regex(".*\\.tpl$", file))
  }
}
