output "website_url" {
  description = "URL of the website"
  value       = "https://${aws_cloudfront_distribution.website.domain_name}"
}

output "api_gateway_url" {
  description = "URL of the API Gateway"
  value       = "https://${aws_api_gateway_rest_api.restaurant_api.id}.execute-api.${data.aws_region.current.id}.amazonaws.com/${var.environment}"
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.website.bucket
}

output "menu_table_name" {
  description = "Name of the menu items DynamoDB table"
  value       = aws_dynamodb_table.menu_items.name
}

output "orders_table_name" {
  description = "Name of the orders DynamoDB table"
  value       = aws_dynamodb_table.orders.name
}

output "cloudfront_logs_bucket" {
  description = "Name of the CloudFront logs S3 bucket"
  value       = aws_s3_bucket.cloudfront_logs.bucket
}

output "api_gateway_log_group" {
  description = "Name of the API Gateway CloudWatch log group"
  value       = aws_cloudwatch_log_group.api_gateway_execution_logs.name
}
