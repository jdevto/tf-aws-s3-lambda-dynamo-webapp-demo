<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Order Tracking - Restaurant Ordering</title>
    <link rel="stylesheet" href="styles.css">
</head>
<body>
    <div class="container">
        <header>
            <h1>📋 Order Tracking</h1>
            <p>Track your orders and view order history</p>
        </header>

        <main>
            <!-- Order Lookup Section -->
            <section class="order-lookup-section">
                <h2>Look Up Order</h2>
                <form id="order-lookup-form">
                    <div class="form-group">
                        <label for="order-id-input">Order ID:</label>
                        <input type="text" id="order-id-input" name="order_id" placeholder="Enter your order ID" required>
                    </div>
                    <button type="submit" class="submit-btn">Look Up Order</button>
                </form>
            </section>

            <!-- Order Details Section -->
            <section id="order-details-section" class="order-details-section" style="display: none;">
                <h2>Order Details</h2>
                <div id="order-details-content"></div>
            </section>

            <!-- All Orders Section -->
            <section class="all-orders-section">
                <h2>Recent Orders</h2>
                <div id="orders-loading" class="loading">Loading orders...</div>
                <div id="orders-list" class="orders-list"></div>
            </section>
        </main>

        <footer>
            <p>&copy; 2024 Restaurant Ordering. All rights reserved.</p>
            <p><a href="index.html">← Back to Menu</a></p>
        </footer>
    </div>

    <script>
        // Configuration - API Gateway URL injected by Terraform
        const API_BASE_URL = "API_GATEWAY_URL_PLACEHOLDER";

        // Initialize the application
        document.addEventListener('DOMContentLoaded', function() {
            loadAllOrders();
            setupEventListeners();
        });

        // Setup event listeners
        function setupEventListeners() {
            const orderLookupForm = document.getElementById('order-lookup-form');
            orderLookupForm.addEventListener('submit', handleOrderLookup);
        }

        // Load all orders
        async function loadAllOrders() {
            try {
                const response = await fetch(`${API_BASE_URL}/orders`);
                const data = await response.json();

                if (data.success) {
                    displayAllOrders(data.data);
                } else {
                    showError('Failed to load orders: ' + data.error);
                }
            } catch (error) {
                console.error('Error loading orders:', error);
                showError('Failed to load orders. Please check your connection.');
            }
        }

        // Display all orders
        function displayAllOrders(orders) {
            const ordersList = document.getElementById('orders-list');
            const ordersLoading = document.getElementById('orders-loading');

            ordersLoading.style.display = 'none';

            if (orders.length === 0) {
                ordersList.innerHTML = '<p>No orders found.</p>';
                return;
            }

            ordersList.innerHTML = orders.map(order => `
                <div class="order-card" onclick="lookupOrder('${order.order_id}')">
                    <div class="order-header">
                        <h3>Order #${order.order_id.substring(0, 8)}...</h3>
                        <span class="order-status status-${order.status}">${order.status}</span>
                    </div>
                    <div class="order-info">
                        <p><strong>Customer:</strong> ${order.customer_name}</p>
                        <p><strong>Total:</strong> $${order.total_amount.toFixed(2)}</p>
                        <p><strong>Date:</strong> ${new Date(order.created_at).toLocaleDateString()}</p>
                        <p><strong>Items:</strong> ${order.items.length} item(s)</p>
                    </div>
                </div>
            `).join('');
        }

        // Handle order lookup form submission
        async function handleOrderLookup(event) {
            event.preventDefault();

            const orderId = document.getElementById('order-id-input').value.trim();
            if (!orderId) {
                showError('Please enter an order ID');
                return;
            }

            await lookupOrder(orderId);
        }

        // Look up a specific order
        async function lookupOrder(orderId) {
            try {
                const response = await fetch(`${API_BASE_URL}/orders/${orderId}`);
                const data = await response.json();

                if (data.success) {
                    displayOrderDetails(data.data);
                } else {
                    showError('Order not found: ' + data.error);
                }
            } catch (error) {
                console.error('Error looking up order:', error);
                showError('Failed to look up order. Please try again.');
            }
        }

        // Display order details
        function displayOrderDetails(order) {
            const orderDetailsSection = document.getElementById('order-details-section');
            const orderDetailsContent = document.getElementById('order-details-content');

            orderDetailsContent.innerHTML = `
                <div class="order-summary">
                    <div class="order-header">
                        <h3>Order #${order.order_id}</h3>
                        <span class="order-status status-${order.status}">${order.status}</span>
                    </div>
                    <div class="order-info">
                        <p><strong>Customer:</strong> ${order.customer_name}</p>
                        <p><strong>Order Date:</strong> ${new Date(order.created_at).toLocaleString()}</p>
                        <p><strong>Last Updated:</strong> ${new Date(order.updated_at).toLocaleString()}</p>
                    </div>

                    <div class="order-items">
                        <h4>Items Ordered:</h4>
                        ${order.items.map(item => `
                            <div class="order-item">
                                <span>${item.name} x${item.quantity}</span>
                                <span>$${item.item_total.toFixed(2)}</span>
                            </div>
                        `).join('')}
                    </div>

                    <div class="order-total">
                        <strong>Total: $${order.total_amount.toFixed(2)}</strong>
                    </div>
                </div>
            `;

            orderDetailsSection.style.display = 'block';
            orderDetailsSection.scrollIntoView({ behavior: 'smooth' });
        }

        // Utility functions
        function showError(message) {
            // Remove existing error messages
            const existingErrors = document.querySelectorAll('.error');
            existingErrors.forEach(error => error.remove());

            // Create new error message
            const errorDiv = document.createElement('div');
            errorDiv.className = 'error';
            errorDiv.textContent = message;

            // Insert at the top of the main content
            const main = document.querySelector('main');
            main.insertBefore(errorDiv, main.firstChild);

            // Auto-remove after 5 seconds
            setTimeout(() => {
                if (errorDiv.parentNode) {
                    errorDiv.remove();
                }
            }, 5000);
        }

        // Update API URL function (to be called after deployment)
        function updateApiUrl(apiUrl) {
            API_BASE_URL = apiUrl;
            // Reload orders with new URL
            loadAllOrders();
        }
    </script>

    <style>
        /* Additional styles for order tracking page */
        .order-lookup-section {
            margin-bottom: 30px;
        }

        .order-details-section {
            margin-bottom: 30px;
        }

        .orders-list {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
        }

        .order-card {
            border: 1px solid #e0e0e0;
            border-radius: 8px;
            padding: 20px;
            background: white;
            cursor: pointer;
            transition: transform 0.2s, box-shadow 0.2s;
        }

        .order-card:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 15px rgba(0, 0, 0, 0.1);
        }

        .order-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 15px;
        }

        .order-header h3 {
            margin: 0;
            color: #2c3e50;
        }

        .order-status {
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 0.8rem;
            font-weight: bold;
            text-transform: uppercase;
        }

        .status-pending {
            background: #f39c12;
            color: white;
        }

        .status-confirmed {
            background: #3498db;
            color: white;
        }

        .status-preparing {
            background: #e67e22;
            color: white;
        }

        .status-ready {
            background: #27ae60;
            color: white;
        }

        .status-delivered {
            background: #2ecc71;
            color: white;
        }

        .status-cancelled {
            background: #e74c3c;
            color: white;
        }

        .order-info p {
            margin-bottom: 8px;
            color: #666;
        }

        .order-items {
            margin: 20px 0;
        }

        .order-items h4 {
            margin-bottom: 10px;
            color: #2c3e50;
        }

        .order-total {
            margin-top: 15px;
            padding-top: 15px;
            border-top: 2px solid #3498db;
            font-size: 1.2rem;
            text-align: right;
        }

        footer a {
            color: #3498db;
            text-decoration: none;
        }

        footer a:hover {
            text-decoration: underline;
        }
    </style>
</body>
</html>
