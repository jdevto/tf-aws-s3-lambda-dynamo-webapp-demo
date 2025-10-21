# AWS Serverless Demo - Restaurant Ordering Web Application

A complete serverless restaurant ordering web application built with AWS services, demonstrating a scalable, highly available architecture with minimal server maintenance requirements. Features an enhanced shopping cart experience with real-time order management.

## Architecture Overview

This application implements the AWS serverless architecture pattern using:

- **Amazon S3**: Hosts static website files (HTML, CSS, JavaScript) with automatic deployment
- **Amazon CloudFront**: Content delivery network for global content distribution with logging
- **Amazon API Gateway**: REST API endpoints for order management with execution logging
- **AWS Lambda**: Serverless functions for business logic with CloudWatch logging
- **Amazon DynamoDB**: On-demand NoSQL database for menu items and orders
- **AWS X-Ray**: Distributed tracing for performance monitoring

```plaintext
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   CloudFront    │    │   Amazon S3      │    │  Static Website │
│   (CDN)         │◄───┤   (Website Host) │◄───┤  (Frontend)     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │
         │
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  API Gateway    │    │   AWS Lambda     │    │   DynamoDB      │
│  (REST API)     │◄───┤  (Business Logic)│◄───┤  (Data Store)   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Features

- **Enhanced Shopping Cart**: Add, remove, and modify items before placing orders
- **Menu Display**: Browse restaurant menu with categories and pricing
- **Order Management**: Real-time cart updates with quantity controls
- **Order Placement**: Submit orders with customer details and item selection
- **Order Tracking**: View order status and details by order ID
- **Responsive Design**: Mobile-friendly interface
- **Real-time Updates**: Live order status and pricing calculations
- **No Authentication**: Public access for demonstration purposes

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- Python 3.9+ (for Lambda functions)
- jq (for data seeding script)

## Deployment Instructions

### 1. Clone and Initialize

```bash
git clone <repository-url>
cd tf-aws-s3-lambda-dynamo-webapp-demo
```

### 2. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review the deployment plan
terraform plan

# Deploy the infrastructure (includes website upload and API URL injection)
terraform apply

# Note: Due to Terraform's dependency management, you may need to run apply twice
# to ensure all resources are properly created and dependencies are resolved
terraform apply
```

### 3. Seed Menu Data

Populate the DynamoDB table with sample menu items:

```bash
# Get table name from Terraform output
TABLE_NAME=$(terraform output -raw menu_table_name)

# Run the seeding script (uses AWS CLI default region)
./scripts/seed-menu.sh $TABLE_NAME
```

**Note:** Website files are automatically uploaded to S3 and the API Gateway URL is automatically injected into the frontend files during Terraform deployment. The application features an enhanced shopping cart with add/remove/modify functionality.

### 4. Access the Application

Get the CloudFront URL and open it in your browser:

```bash
# Get the website URL
terraform output website_url
```

## API Endpoints

### Menu Endpoints

- `GET /menu` - Retrieve all menu items
  - Response: List of menu items with categories, prices, and descriptions

### Order Endpoints

- `POST /orders` - Create a new order
  - Request Body:

    ```json
    {
      "customer_name": "John Doe",
      "items": [
        {
          "item_id": "pizza-001",
          "quantity": 2
        }
      ]
    }
    ```

  - Response: Order details with order ID and total amount

- `GET /orders` - List all orders
  - Query Parameters:
    - `status` (optional): Filter by order status
  - Response: List of orders with details

- `GET /orders/{order_id}` - Get specific order details
  - Response: Complete order information

## Project Structure

```plaintext
├── main.tf                 # Main Terraform configuration
├── variables.tf            # Terraform variables
├── outputs.tf              # Terraform outputs
├── versions.tf             # Terraform provider versions
├── locals.tf               # Terraform local values
├── lambda/                 # Lambda function code
│   ├── get-menu/          # Menu retrieval function
│   ├── create-order/      # Order creation function
│   ├── get-order/         # Order lookup function
│   └── list-orders/       # Order listing function
├── website/               # Frontend application
│   ├── index.html         # Main ordering page
│   ├── orders.html.tpl    # Order tracking page template
│   ├── app.js.tpl         # Frontend JavaScript template
│   ├── styles.css         # Application styles
│   ├── app.js             # Generated JavaScript (auto-created)
│   └── orders.html        # Generated HTML (auto-created)
├── scripts/               # Utility scripts
│   ├── seed-data.json     # Sample menu data
│   └── seed-menu.sh       # Data seeding script
└── README.md              # This file
```

## Configuration

### Variables

- `project_name`: Name of the project (default: "aws-serverless-demo")
- `environment`: Environment name (default: "dev")

### Customization

To customize the application:

1. **Menu Items**: Edit `scripts/seed-data.json` to modify menu items
2. **Styling**: Update `website/styles.css` for visual changes
3. **Functionality**: Modify Lambda functions in the `lambda/` directory
4. **Frontend**: Update HTML/JavaScript files in the `website/` directory

## Monitoring and Logs

- **CloudWatch Logs**: Lambda function logs are automatically sent to CloudWatch with 1-day retention
- **API Gateway Execution Logs**: Detailed request/response logging with INFO level
- **CloudFront Logs**: Access logs stored in S3 for CDN performance analysis
- **X-Ray Tracing**: Distributed tracing for end-to-end request monitoring
- **DynamoDB Metrics**: Monitor table performance in the DynamoDB console

## Cleanup

To remove all resources:

```bash
# Destroy the infrastructure
terraform destroy

# Confirm destruction when prompted
```

## Security Considerations

This demo application is designed for demonstration purposes and includes:

- Public S3 bucket access for static website hosting
- No authentication or authorization
- No input validation beyond basic requirements
- No payment processing

For production use, consider implementing:

- User authentication (Amazon Cognito)
- Input validation and sanitization
- HTTPS enforcement
- WAF (Web Application Firewall)
- VPC endpoints for private communication
- Encryption at rest and in transit

## Troubleshooting

### Common Issues

1. **CORS Errors**: Ensure API Gateway has proper CORS configuration
2. **Lambda Timeout**: Check CloudWatch logs for function errors
3. **DynamoDB Access**: Verify IAM permissions for Lambda functions
4. **CloudFront Cache**: Clear CloudFront cache after updating website files
5. **Terraform Apply Twice**: Some resources may require two apply runs due to dependencies
6. **API Gateway Logging**: Ensure CloudWatch role is properly configured for execution logs

### Debugging Steps

1. Check Terraform outputs for correct resource names
2. Verify Lambda function logs in CloudWatch
3. Check API Gateway execution logs in CloudWatch
4. Test API endpoints directly using curl or Postman
5. Check S3 bucket permissions and CloudFront distribution status
6. View X-Ray traces for performance analysis
7. Check CloudFront access logs in S3 for CDN issues

## License

This project is licensed under the MIT License - see the LICENSE file for details.
