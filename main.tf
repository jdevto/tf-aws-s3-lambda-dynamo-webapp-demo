# Restaurant Ordering Web Application - AWS Serverless Architecture

# Data source for current AWS region
data "aws_region" "current" {}

# Data source for current AWS account ID
data "aws_caller_identity" "current" {}

# S3 bucket for static website hosting
resource "aws_s3_bucket" "website" {
  bucket        = "${var.project_name}-website-${random_string.bucket_suffix.result}"
  force_destroy = true
}

resource "random_string" "bucket_suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.website]
}

# DynamoDB table for menu items
resource "aws_dynamodb_table" "menu_items" {
  name         = "${var.project_name}-menu-items"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "item_id"

  attribute {
    name = "item_id"
    type = "S"
  }

  attribute {
    name = "category"
    type = "S"
  }

  global_secondary_index {
    name            = "category-index"
    hash_key        = "category"
    projection_type = "ALL"
  }

  tags = {
    Name        = "${var.project_name}-menu-items"
    Environment = var.environment
  }
}

# DynamoDB table for orders
resource "aws_dynamodb_table" "orders" {
  name         = "${var.project_name}-orders"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "order_id"

  attribute {
    name = "order_id"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  global_secondary_index {
    name            = "status-index"
    hash_key        = "status"
    projection_type = "ALL"
  }

  tags = {
    Name        = "${var.project_name}-orders"
    Environment = var.environment
  }
}

# IAM role for Lambda functions
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}


# IAM policy for Lambda to access DynamoDB
resource "aws_iam_role_policy" "lambda_dynamodb_policy" {
  name = "${var.project_name}-lambda-dynamodb-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DynamoDBReadAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.menu_items.arn,
          aws_dynamodb_table.orders.arn,
          "${aws_dynamodb_table.menu_items.arn}/index/*",
          "${aws_dynamodb_table.orders.arn}/index/*"
        ]
      },
      {
        Sid    = "DynamoDBWriteAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem"
        ]
        Resource = [
          aws_dynamodb_table.orders.arn
        ]
      },
      {
        Sid    = "CloudWatchLogsAccess"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project_name}-*",
          "arn:aws:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project_name}-*:*"
        ]
      }
    ]
  })
}

# Create archive files for each Lambda function
data "archive_file" "lambda_zips" {
  for_each = local.lambda_functions

  type        = "zip"
  source_dir  = each.value.source_dir
  output_path = "${each.value.source_dir}.zip"
}

# Create CloudWatch log groups for Lambda functions
resource "aws_cloudwatch_log_group" "lambda_logs" {
  for_each = local.lambda_functions

  name              = "/aws/lambda/${var.project_name}-${each.key}"
  retention_in_days = 1

  lifecycle {
    prevent_destroy = false
  }

  tags = {
    Name        = "${var.project_name}-${each.key}-logs"
    Environment = var.environment
  }
}

# Create Lambda functions dynamically
resource "aws_lambda_function" "lambda_functions" {
  for_each = local.lambda_functions

  filename         = data.archive_file.lambda_zips[each.key].output_path
  function_name    = "${var.project_name}-${each.key}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.lambda_handler"
  source_code_hash = data.archive_file.lambda_zips[each.key].output_base64sha256
  runtime          = "python3.13"

  environment {
    variables = each.value.environment_vars
  }

  depends_on = [aws_cloudwatch_log_group.lambda_logs]
}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "restaurant_api" {
  name        = "${var.project_name}-api"
  description = "Restaurant Ordering API"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# API Gateway resources and methods
resource "aws_api_gateway_resource" "menu" {
  rest_api_id = aws_api_gateway_rest_api.restaurant_api.id
  parent_id   = aws_api_gateway_rest_api.restaurant_api.root_resource_id
  path_part   = "menu"
}

resource "aws_api_gateway_method" "get_menu" {
  rest_api_id   = aws_api_gateway_rest_api.restaurant_api.id
  resource_id   = aws_api_gateway_resource.menu.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_menu" {
  rest_api_id = aws_api_gateway_rest_api.restaurant_api.id
  resource_id = aws_api_gateway_resource.menu.id
  http_method = aws_api_gateway_method.get_menu.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_functions["get-menu"].invoke_arn
}

resource "aws_api_gateway_resource" "orders" {
  rest_api_id = aws_api_gateway_rest_api.restaurant_api.id
  parent_id   = aws_api_gateway_rest_api.restaurant_api.root_resource_id
  path_part   = "orders"
}

resource "aws_api_gateway_method" "create_order" {
  rest_api_id   = aws_api_gateway_rest_api.restaurant_api.id
  resource_id   = aws_api_gateway_resource.orders.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "create_order" {
  rest_api_id = aws_api_gateway_rest_api.restaurant_api.id
  resource_id = aws_api_gateway_resource.orders.id
  http_method = aws_api_gateway_method.create_order.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_functions["create-order"].invoke_arn
}

resource "aws_api_gateway_method" "list_orders" {
  rest_api_id   = aws_api_gateway_rest_api.restaurant_api.id
  resource_id   = aws_api_gateway_resource.orders.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "list_orders" {
  rest_api_id = aws_api_gateway_rest_api.restaurant_api.id
  resource_id = aws_api_gateway_resource.orders.id
  http_method = aws_api_gateway_method.list_orders.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_functions["list-orders"].invoke_arn
}

resource "aws_api_gateway_resource" "order_by_id" {
  rest_api_id = aws_api_gateway_rest_api.restaurant_api.id
  parent_id   = aws_api_gateway_resource.orders.id
  path_part   = "{order_id}"
}

resource "aws_api_gateway_method" "get_order" {
  rest_api_id   = aws_api_gateway_rest_api.restaurant_api.id
  resource_id   = aws_api_gateway_resource.order_by_id.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_order" {
  rest_api_id = aws_api_gateway_rest_api.restaurant_api.id
  resource_id = aws_api_gateway_resource.order_by_id.id
  http_method = aws_api_gateway_method.get_order.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_functions["get-order"].invoke_arn
}

# CORS configuration for API Gateway
resource "aws_api_gateway_method" "options_menu" {
  rest_api_id   = aws_api_gateway_rest_api.restaurant_api.id
  resource_id   = aws_api_gateway_resource.menu.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "options_menu" {
  rest_api_id = aws_api_gateway_rest_api.restaurant_api.id
  resource_id = aws_api_gateway_resource.menu.id
  http_method = aws_api_gateway_method.options_menu.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration" "options_menu" {
  rest_api_id = aws_api_gateway_rest_api.restaurant_api.id
  resource_id = aws_api_gateway_resource.menu.id
  http_method = aws_api_gateway_method.options_menu.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_integration_response" "options_menu" {
  rest_api_id = aws_api_gateway_rest_api.restaurant_api.id
  resource_id = aws_api_gateway_resource.menu.id
  http_method = aws_api_gateway_method.options_menu.http_method
  status_code = aws_api_gateway_method_response.options_menu.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

resource "aws_api_gateway_method" "options_orders" {
  rest_api_id   = aws_api_gateway_rest_api.restaurant_api.id
  resource_id   = aws_api_gateway_resource.orders.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "options_orders" {
  rest_api_id = aws_api_gateway_rest_api.restaurant_api.id
  resource_id = aws_api_gateway_resource.orders.id
  http_method = aws_api_gateway_method.options_orders.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration" "options_orders" {
  rest_api_id = aws_api_gateway_rest_api.restaurant_api.id
  resource_id = aws_api_gateway_resource.orders.id
  http_method = aws_api_gateway_method.options_orders.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_integration_response" "options_orders" {
  rest_api_id = aws_api_gateway_rest_api.restaurant_api.id
  resource_id = aws_api_gateway_resource.orders.id
  http_method = aws_api_gateway_method.options_orders.http_method
  status_code = aws_api_gateway_method_response.options_orders.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# Lambda permissions for API Gateway
resource "aws_lambda_permission" "lambda_permissions" {
  for_each = local.lambda_functions

  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_functions[each.key].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.restaurant_api.execution_arn}/*/*"
}

# API Gateway deployment
resource "aws_api_gateway_deployment" "restaurant_api" {
  depends_on = [
    aws_api_gateway_integration.get_menu,
    aws_api_gateway_integration.create_order,
    aws_api_gateway_integration.get_order,
    aws_api_gateway_integration.list_orders,
    aws_api_gateway_integration.options_menu,
    aws_api_gateway_integration.options_orders,
  ]

  rest_api_id = aws_api_gateway_rest_api.restaurant_api.id

  lifecycle {
    create_before_destroy = true
  }
}

# IAM role for API Gateway CloudWatch logging
resource "aws_iam_role" "api_gateway_logs_role" {
  name = "${var.project_name}-api-gateway-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-api-gateway-logs-role"
    Environment = var.environment
  }
}

# IAM policy for API Gateway CloudWatch logs
resource "aws_iam_role_policy" "api_gateway_logs_policy" {
  name = "${var.project_name}-api-gateway-logs-policy"
  role = aws_iam_role.api_gateway_logs_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogsWriteAccess"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# Set the CloudWatch role for API Gateway account
resource "aws_api_gateway_account" "restaurant_api" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_logs_role.arn
}

# CloudWatch log group for API Gateway execution logs
resource "aws_cloudwatch_log_group" "api_gateway_execution_logs" {
  name              = "API-Gateway-Execution-Logs_${aws_api_gateway_rest_api.restaurant_api.id}/${var.environment}"
  retention_in_days = 1

  lifecycle {
    prevent_destroy = false
  }

  tags = {
    Name        = "${var.project_name}-api-gateway-execution-logs"
    Environment = var.environment
  }
}

# API Gateway stage
resource "aws_api_gateway_stage" "restaurant_api" {
  deployment_id = aws_api_gateway_deployment.restaurant_api.id
  rest_api_id   = aws_api_gateway_rest_api.restaurant_api.id
  stage_name    = var.environment

  # Enable execution logging (creates log group automatically)
  xray_tracing_enabled = true

  # Ensure log group is created before stage
  depends_on = [aws_cloudwatch_log_group.api_gateway_execution_logs]

  tags = {
    Name        = "${var.project_name}-api-stage"
    Environment = var.environment
  }
}

# API Gateway method settings to enable execution logging
resource "aws_api_gateway_method_settings" "restaurant_api" {
  rest_api_id = aws_api_gateway_rest_api.restaurant_api.id
  stage_name  = aws_api_gateway_stage.restaurant_api.stage_name
  method_path = "*/*"

  settings {
    # Enable execution logging
    logging_level      = "INFO"
    data_trace_enabled = true
    metrics_enabled    = true
  }

  # Ensure log group is created before method settings
  depends_on = [aws_cloudwatch_log_group.api_gateway_execution_logs]
}

# Create app.js with dynamic API URL
resource "local_file" "app_js" {
  content  = replace(file("${path.module}/website/app.js.tpl"), "API_GATEWAY_URL_PLACEHOLDER", local.api_gateway_url)
  filename = "${path.module}/website/app.js"
}

# Create orders.html with dynamic API URL
resource "local_file" "orders_html" {
  content  = replace(file("${path.module}/website/orders.html.tpl"), "API_GATEWAY_URL_PLACEHOLDER", local.api_gateway_url)
  filename = "${path.module}/website/orders.html"
}

# Upload website files to S3 (excluding template files)
resource "aws_s3_object" "website_files" {
  for_each = {
    for file in fileset("${path.module}/website", "**/*") : file => file
    if !can(regex(".*\\.tpl$", file))
  }

  bucket = aws_s3_bucket.website.id
  key    = each.value
  source = "${path.module}/website/${each.value}"
  etag   = local.file_etags[each.value]
  content_type = lookup({
    "html" = "text/html"
    "css"  = "text/css"
    "js"   = "application/javascript"
    "json" = "application/json"
    "png"  = "image/png"
    "jpg"  = "image/jpeg"
    "jpeg" = "image/jpeg"
    "gif"  = "image/gif"
    "svg"  = "image/svg+xml"
    "ico"  = "image/x-icon"
  }, split(".", each.value)[length(split(".", each.value)) - 1], "text/plain")

  # Set cache control for better performance
  cache_control = can(regex(".*\\.(html|js)$", each.value)) ? "no-cache" : "public, max-age=31536000"

  depends_on = [
    local_file.app_js,
    local_file.orders_html
  ]
}

# S3 bucket for CloudFront logs
resource "aws_s3_bucket" "cloudfront_logs" {
  bucket = "${var.project_name}-cloudfront-logs-${random_string.bucket_suffix.result}"

  force_destroy = true

  tags = {
    Name        = "${var.project_name}-cloudfront-logs"
    Environment = var.environment
  }
}

# Enable ACL for CloudFront logs
resource "aws_s3_bucket_acl" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id
  acl    = "private"

  depends_on = [aws_s3_bucket_ownership_controls.cloudfront_logs]
}

# Enable ACL ownership controls
resource "aws_s3_bucket_ownership_controls" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "website" {
  origin {
    domain_name = aws_s3_bucket_website_configuration.website.website_endpoint
    origin_id   = "S3-${aws_s3_bucket.website.bucket}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.website.bucket}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  # CloudFront logging configuration
  logging_config {
    bucket          = aws_s3_bucket.cloudfront_logs.bucket_domain_name
    include_cookies = false
    prefix          = "cloudfront-logs/"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name        = "${var.project_name}-cloudfront"
    Environment = var.environment
  }
}
