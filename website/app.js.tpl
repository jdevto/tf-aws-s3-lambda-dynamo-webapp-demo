// Configuration - API Gateway URL injected by Terraform
const API_BASE_URL = "API_GATEWAY_URL_PLACEHOLDER";
let menuItems = [];
let selectedItems = {};

// Initialize the application
document.addEventListener('DOMContentLoaded', function() {
    console.log('DOM loaded, initializing app...');
    loadMenu();
    setupEventListeners();
});

// Load menu items from API
async function loadMenu() {
    try {
        console.log('Loading menu from:', `${API_BASE_URL}/menu`);
        const response = await fetch(`${API_BASE_URL}/menu`);
        console.log('Menu response status:', response.status);
        const data = await response.json();
        console.log('Menu data received:', data);

        if (data.success) {
            menuItems = data.data;
            console.log('Menu items loaded:', menuItems.length, 'items');
            displayMenu(menuItems);
            populateMenuSelection(menuItems);
        } else {
            showError('Failed to load menu: ' + data.error);
        }
    } catch (error) {
        console.error('Error loading menu:', error);
        showError('Failed to load menu. Please check your connection.');
    }
}

// Display menu items
function displayMenu(items) {
    const menuGrid = document.getElementById('menu-grid');
    const menuLoading = document.getElementById('menu-loading');

    menuLoading.style.display = 'none';

    if (items.length === 0) {
        menuGrid.innerHTML = '<p>No menu items available.</p>';
        return;
    }

    menuGrid.innerHTML = items.map(item => `
        <div class="menu-item">
            <div class="category">${item.category}</div>
            <h3>${item.name}</h3>
            <p class="description">${item.description || 'Delicious menu item'}</p>
            <div class="price">$${item.price.toFixed(2)}</div>
        </div>
    `).join('');
}

// Populate menu selection for ordering
function populateMenuSelection(items) {
    const container = document.getElementById('menu-items-selection');

    if (items.length === 0) {
        container.innerHTML = '<p>No menu items available for selection.</p>';
        return;
    }

    container.innerHTML = items.map(item => `
        <div class="menu-item-selection" data-item-id="${item.item_id}">
            <div class="item-info">
                <h4>${item.name}</h4>
                <div class="price">$${item.price.toFixed(2)}</div>
            </div>
            <div class="quantity-controls">
                <button type="button" class="qty-btn" onclick="decreaseQuantity('${item.item_id}')" title="Remove from cart">-</button>
                <span class="quantity" id="qty-${item.item_id}">0</span>
                <button type="button" class="qty-btn" onclick="increaseQuantity('${item.item_id}')" title="Add to cart">+</button>
            </div>
        </div>
    `).join('');
}

// Quantity control functions
function increaseQuantity(itemId) {
    if (!selectedItems[itemId]) {
        selectedItems[itemId] = 0;
    }
    selectedItems[itemId]++;
    updateQuantityDisplay(itemId);
    updateOrderSummary();
}

function decreaseQuantity(itemId) {
    if (!selectedItems[itemId] || selectedItems[itemId] <= 0) {
        return;
    }
    selectedItems[itemId]--;
    if (selectedItems[itemId] === 0) {
        delete selectedItems[itemId];
    }
    updateQuantityDisplay(itemId);
    updateOrderSummary();
}

function updateQuantityDisplay(itemId) {
    const quantityElement = document.getElementById(`qty-${itemId}`);
    quantityElement.textContent = selectedItems[itemId] || 0;
}

// Remove item completely from cart
function removeItemFromCart(itemId) {
    delete selectedItems[itemId];
    updateQuantityDisplay(itemId);
    updateOrderSummary();
}

// Clear entire cart
function clearCart() {
    selectedItems = {};
    // Reset all quantity displays
    menuItems.forEach(item => {
        updateQuantityDisplay(item.item_id);
    });
    updateOrderSummary();
}

// Update order summary
function updateOrderSummary() {
    const orderItemsContainer = document.getElementById('order-items');
    const orderTotalElement = document.getElementById('order-total');
    const submitButton = document.getElementById('submit-order');

    let total = 0;
    let orderItemsHTML = '';

    for (const [itemId, quantity] of Object.entries(selectedItems)) {
        if (quantity > 0) {
            const item = menuItems.find(i => i.item_id === itemId);
            if (item) {
                const itemTotal = item.price * quantity;
                total += itemTotal;
                orderItemsHTML += `
                    <div class="order-item">
                        <div class="item-details">
                            <span class="item-name">${item.name}</span>
                            <span class="item-quantity">x${quantity}</span>
                        </div>
                        <div class="item-actions">
                            <button type="button" class="remove-item-btn" onclick="removeItemFromCart('${itemId}')" title="Remove from cart">×</button>
                            <span class="item-total">$${itemTotal.toFixed(2)}</span>
                        </div>
                    </div>
                `;
            }
        }
    }

    orderItemsContainer.innerHTML = orderItemsHTML || '<p class="empty-cart">Your cart is empty. Add items using the + buttons above.</p>';
    orderTotalElement.textContent = total.toFixed(2);
    submitButton.disabled = total === 0;

    // Update button text based on cart state
    if (total === 0) {
        submitButton.textContent = 'Add items to place order';
    } else {
        submitButton.textContent = `Place Order ($${total.toFixed(2)})`;
    }
}

// Setup event listeners
function setupEventListeners() {
    const orderForm = document.getElementById('order-form');
    orderForm.addEventListener('submit', handleOrderSubmission);
}

// Handle order form submission
async function handleOrderSubmission(event) {
    event.preventDefault();

    const customerName = document.getElementById('customer-name').value.trim();
    if (!customerName) {
        showError('Please enter your name');
        return;
    }

    const items = [];
    for (const [itemId, quantity] of Object.entries(selectedItems)) {
        if (quantity > 0) {
            items.push({
                item_id: itemId,
                quantity: quantity
            });
        }
    }

    if (items.length === 0) {
        showError('Please select at least one item');
        return;
    }

    const orderData = {
        customer_name: customerName,
        items: items
    };

    try {
        console.log('Sending order data:', orderData);
        console.log('API URL:', API_BASE_URL);

        const response = await fetch(`${API_BASE_URL}/orders`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(orderData)
        });

        console.log('Response status:', response.status);
        const data = await response.json();
        console.log('Response data:', data);

        if (data.success) {
            showOrderConfirmation(data.data);
        } else {
            showError('Failed to place order: ' + data.error);
        }
    } catch (error) {
        console.error('Error placing order:', error);
        showError('Failed to place order. Please try again.');
    }
}

// Show order confirmation
function showOrderConfirmation(order) {
    document.getElementById('order-id').textContent = order.order_id;
    document.getElementById('customer-name-display').textContent = order.customer_name;
    document.getElementById('order-total-display').textContent = order.total_amount.toFixed(2);
    document.getElementById('order-status').textContent = order.status;

    // Hide order form and show confirmation
    document.getElementById('order-section').style.display = 'none';
    document.getElementById('confirmation-section').style.display = 'block';

    // Scroll to confirmation
    document.getElementById('confirmation-section').scrollIntoView({ behavior: 'smooth' });
}

// View order details (placeholder for future implementation)
function viewOrder() {
    const orderId = document.getElementById('order-id').textContent;
    alert(`Order details for ${orderId} would be displayed here.\n\nIn a full implementation, this would show detailed order information and tracking.`);
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

    // Insert at the top of the order section
    const orderSection = document.getElementById('order-section');
    orderSection.insertBefore(errorDiv, orderSection.firstChild);

    // Auto-remove after 5 seconds
    setTimeout(() => {
        if (errorDiv.parentNode) {
            errorDiv.remove();
        }
    }, 5000);
}
