/**
 * Kitchen Manager - lb-tablet App
 * Restaurant management interface for free-restaurants
 */

// State
let appData = null;
let currentTab = 'dashboard';
let currentOrderFilter = 'all';

// DOM Elements
const elements = {
    loading: document.getElementById('loading'),
    error: document.getElementById('error'),
    errorMessage: document.getElementById('error-message'),
    mainApp: document.getElementById('main-app'),
    restaurantName: document.getElementById('restaurant-name'),
    dutyBadge: document.getElementById('duty-badge'),
    ordersBadge: document.getElementById('orders-badge'),
};

// Utility Functions
function formatMoney(amount) {
    return '$' + (amount || 0).toLocaleString();
}

function formatTime(seconds) {
    if (seconds < 60) return `${seconds}s`;
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}m ${secs}s`;
}

function formatDate(timestamp) {
    if (!timestamp) return 'Never';
    const date = new Date(timestamp * 1000);
    return date.toLocaleDateString();
}

function getGradeClass(score) {
    if (score >= 90) return 'grade-a';
    if (score >= 80) return 'grade-b';
    if (score >= 70) return 'grade-c';
    if (score >= 60) return 'grade-d';
    return 'grade-f';
}

function getGradeLetter(score) {
    if (score >= 90) return 'A';
    if (score >= 80) return 'B';
    if (score >= 70) return 'C';
    if (score >= 60) return 'D';
    return 'F';
}

// NUI Communication
function sendMessage(action, data = {}) {
    return fetch(`https://${GetParentResourceName()}/lb-tablet:restaurant-manager`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action, ...data, requestId: Date.now() })
    });
}

// Request initial data
function requestData() {
    sendMessage('getData');
}

// Tab Navigation
function switchTab(tabName) {
    currentTab = tabName;
    
    // Update tab buttons
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.tab === tabName);
    });
    
    // Update tab panels
    document.querySelectorAll('.tab-panel').forEach(panel => {
        panel.classList.toggle('active', panel.id === `tab-${tabName}`);
    });
}

// Update UI with data
function updateUI(data) {
    if (data.error) {
        showError(data.error);
        return;
    }
    
    appData = data;
    hideLoading();
    
    // Update header
    elements.restaurantName.textContent = data.jobLabel || 'Restaurant';
    elements.dutyBadge.textContent = data.isOnDuty ? 'On Duty' : 'Off Duty';
    elements.dutyBadge.className = `badge ${data.isOnDuty ? 'badge-on' : 'badge-off'}`;
    
    // Update dashboard stats
    if (data.orderCounts) {
        document.getElementById('stat-pending').textContent = data.orderCounts.pending || 0;
        document.getElementById('stat-cooking').textContent = data.orderCounts.inProgress || 0;
        document.getElementById('stat-ready').textContent = data.orderCounts.ready || 0;
        
        // Update orders badge
        const totalOrders = (data.orderCounts.pending || 0) + (data.orderCounts.inProgress || 0);
        if (totalOrders > 0) {
            elements.ordersBadge.textContent = totalOrders;
            elements.ordersBadge.style.display = 'block';
        } else {
            elements.ordersBadge.style.display = 'none';
        }
    }
    
    if (data.finances) {
        document.getElementById('stat-today').textContent = formatMoney(data.finances.todaySales);
        document.getElementById('business-balance').textContent = formatMoney(data.finances.balance);
        document.getElementById('sales-today').textContent = formatMoney(data.finances.todaySales);
        document.getElementById('sales-week').textContent = formatMoney(data.finances.weekSales);
    }
    
    // Update duty button
    const dutyBtn = document.getElementById('btn-toggle-duty');
    dutyBtn.querySelector('span').textContent = data.isOnDuty ? 'Clock Out' : 'Clock In';
    
    // Update staff stats
    if (data.employeeCounts) {
        document.getElementById('staff-online').textContent = data.employeeCounts.online || 0;
        document.getElementById('staff-duty').textContent = data.employeeCounts.onDuty || 0;
        document.getElementById('staff-total').textContent = data.employeeCounts.total || 0;
    }
    
    // Update progression
    if (data.progression) {
        document.getElementById('player-level').textContent = data.progression.level || 1;
        const progress = data.progression.progress || 0;
        document.getElementById('xp-bar').style.width = `${progress}%`;
        document.getElementById('xp-text').textContent = 
            `${data.progression.currentLevelXp || 0} / ${data.progression.nextLevelXp || 100} XP`;
    }
    
    // Update inspection
    if (data.inspection) {
        const score = data.inspection.score || 100;
        document.getElementById('inspection-score').textContent = score;
        document.getElementById('inspection-letter').textContent = getGradeLetter(score);
        document.getElementById('inspection-letter').parentElement.className = 
            `inspection-grade ${getGradeClass(score)}`;
        document.getElementById('inspection-date').textContent = formatDate(data.inspection.lastInspection);
        document.getElementById('next-inspection').textContent = formatDate(data.inspection.nextInspection);
    }
    
    // Update orders list
    updateOrdersList(data.orders || []);
    
    // Update deliveries
    updateDeliveries(data.activeDelivery, data.deliveries || []);
    
    // Update employees
    updateEmployeesList(data.employees || []);
}

// Update orders list
function updateOrdersList(orders) {
    const container = document.getElementById('orders-list');
    
    // Filter orders
    const filteredOrders = currentOrderFilter === 'all' 
        ? orders 
        : orders.filter(o => o.status === currentOrderFilter);
    
    if (filteredOrders.length === 0) {
        container.innerHTML = '<p class="empty-state">No orders at this time</p>';
        return;
    }
    
    container.innerHTML = filteredOrders.map(order => {
        const items = order.items.map(i => `${i.amount}x ${i.label}`).join(', ');
        const waitTime = Math.floor((Date.now() - order.createdAt * 1000) / 1000);
        
        let actions = '';
        if (order.status === 'pending') {
            actions = `<button class="btn-start" onclick="orderAction('start', '${order.id}')">Start</button>`;
        } else if (order.status === 'in_progress') {
            actions = `<button class="btn-ready" onclick="orderAction('ready', '${order.id}')">Ready</button>`;
        } else if (order.status === 'ready') {
            actions = `<button class="btn-complete" onclick="orderAction('complete', '${order.id}')">Complete</button>`;
        }
        actions += `<button class="btn-cancel" onclick="orderAction('cancel', '${order.id}')">✕</button>`;
        
        return `
            <div class="order-card ${order.status}">
                <div class="order-header">
                    <span class="order-id">#${order.id}</span>
                    <span class="order-status ${order.status}">${order.status.replace('_', ' ')}</span>
                </div>
                <div class="order-items">${items}</div>
                <div class="order-footer">
                    <span class="order-time">${formatTime(waitTime)} ago • ${formatMoney(order.total)}</span>
                    <div class="order-actions">${actions}</div>
                </div>
            </div>
        `;
    }).join('');
}

// Update deliveries
function updateDeliveries(activeDelivery, availableDeliveries) {
    const activeContainer = document.getElementById('active-delivery');
    const availableContainer = document.getElementById('available-deliveries');
    
    if (activeDelivery) {
        const dest = activeDelivery.destination || {};
        activeContainer.innerHTML = `
            <div class="delivery-destination">${dest.label || 'Unknown'}</div>
            <div class="delivery-items">${activeDelivery.items.map(i => `${i.amount}x ${i.label}`).join(', ')}</div>
            <div class="delivery-payout">Payout: ${formatMoney(activeDelivery.totalPayout)}</div>
            <div class="order-status ${activeDelivery.status}">${activeDelivery.status}</div>
        `;
    } else {
        activeContainer.innerHTML = '<p class="empty-state">No active delivery</p>';
    }
    
    if (availableDeliveries.length === 0) {
        availableContainer.innerHTML = '<p class="empty-state">No deliveries available</p>';
    } else {
        availableContainer.innerHTML = availableDeliveries.map(delivery => {
            const dest = delivery.destination || {};
            return `
                <div class="delivery-card">
                    <div class="delivery-destination">${dest.label || 'Unknown'}</div>
                    <div class="delivery-items">${delivery.items.map(i => `${i.amount}x ${i.label}`).join(', ')}</div>
                    <div class="delivery-payout">Payout: ${formatMoney(delivery.totalPayout)}</div>
                    <button class="btn btn-primary" onclick="acceptDelivery('${delivery.id}')">Accept</button>
                </div>
            `;
        }).join('');
    }
}

// Update employees list
function updateEmployeesList(employees) {
    const container = document.getElementById('employees-list');
    
    if (employees.length === 0) {
        container.innerHTML = '<p class="empty-state">No employees found</p>';
        return;
    }
    
    container.innerHTML = employees.map(emp => `
        <div class="employee-card">
            <div class="employee-info">
                <div class="employee-name">${emp.firstname} ${emp.lastname}</div>
                <div class="employee-grade">${emp.gradeName} (Grade ${emp.grade})</div>
            </div>
            <div class="employee-status">
                <span class="status-dot ${emp.online ? 'online' : 'offline'}"></span>
                ${emp.onDuty ? '<span class="status-dot on-duty"></span>' : ''}
            </div>
        </div>
    `).join('');
}

// Order actions
function orderAction(action, orderId) {
    const actionMap = {
        'start': 'startOrder',
        'ready': 'readyOrder',
        'complete': 'completeOrder',
        'cancel': 'cancelOrder'
    };
    
    sendMessage(actionMap[action], { orderId });
}

// Accept delivery
function acceptDelivery(deliveryId) {
    sendMessage('acceptDelivery', { deliveryId });
}

// Toggle duty
function toggleDuty() {
    if (appData && appData.isOnDuty) {
        sendMessage('clockOut');
    } else {
        sendMessage('clockIn');
    }
}

// Show modal
function showModal(title, content, actions) {
    const overlay = document.getElementById('modal-overlay');
    const container = document.getElementById('modal-container');
    
    container.innerHTML = `
        <div class="modal-header">
            <h3>${title}</h3>
            <button class="modal-close" onclick="hideModal()">×</button>
        </div>
        <div class="modal-body">${content}</div>
        ${actions ? `<div class="modal-footer">${actions}</div>` : ''}
    `;
    
    overlay.style.display = 'flex';
}

function hideModal() {
    document.getElementById('modal-overlay').style.display = 'none';
}

// Show withdraw modal
function showWithdrawModal() {
    showModal(
        'Withdraw Funds',
        `
            <div class="form-group">
                <label class="form-label">Amount</label>
                <input type="number" id="withdraw-amount" class="form-input" min="1" placeholder="Enter amount">
            </div>
        `,
        `
            <button class="btn btn-secondary" onclick="hideModal()">Cancel</button>
            <button class="btn btn-primary" onclick="doWithdraw()">Withdraw</button>
        `
    );
}

function doWithdraw() {
    const amount = parseInt(document.getElementById('withdraw-amount').value);
    if (amount > 0) {
        sendMessage('withdraw', { amount });
        hideModal();
    }
}

// Show deposit modal
function showDepositModal() {
    showModal(
        'Deposit Funds',
        `
            <div class="form-group">
                <label class="form-label">Amount</label>
                <input type="number" id="deposit-amount" class="form-input" min="1" placeholder="Enter amount">
            </div>
        `,
        `
            <button class="btn btn-secondary" onclick="hideModal()">Cancel</button>
            <button class="btn btn-primary" onclick="doDeposit()">Deposit</button>
        `
    );
}

function doDeposit() {
    const amount = parseInt(document.getElementById('deposit-amount').value);
    if (amount > 0) {
        sendMessage('deposit', { amount });
        hideModal();
    }
}

// Show/hide loading
function hideLoading() {
    elements.loading.style.display = 'none';
    elements.mainApp.style.display = 'flex';
    elements.mainApp.style.flexDirection = 'column';
}

function showError(message) {
    elements.loading.style.display = 'none';
    elements.error.style.display = 'flex';
    elements.errorMessage.textContent = message;
}

// Event Listeners
document.addEventListener('DOMContentLoaded', () => {
    // Tab navigation
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.addEventListener('click', () => switchTab(btn.dataset.tab));
    });
    
    // Order filters
    document.querySelectorAll('.filter-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            currentOrderFilter = btn.dataset.filter;
            if (appData) updateOrdersList(appData.orders || []);
        });
    });
    
    // Quick actions
    document.getElementById('btn-toggle-duty').addEventListener('click', toggleDuty);
    document.getElementById('btn-view-orders').addEventListener('click', () => switchTab('orders'));
    document.getElementById('btn-request-delivery').addEventListener('click', () => switchTab('deliveries'));
    
    // Refresh button
    document.getElementById('refresh-btn').addEventListener('click', requestData);
    
    // Finance buttons
    document.getElementById('btn-withdraw').addEventListener('click', showWithdrawModal);
    document.getElementById('btn-deposit').addEventListener('click', showDepositModal);
    
    // Modal overlay click to close
    document.getElementById('modal-overlay').addEventListener('click', (e) => {
        if (e.target.id === 'modal-overlay') hideModal();
    });
    
    // Request initial data
    requestData();
});

// Message handler from Lua
window.addEventListener('message', (event) => {
    const data = event.data;
    
    if (data.action === 'updateData') {
        updateUI(data.data);
    } else if (data.action === 'response') {
        // Handle specific responses if needed
        if (data.response && !data.response.success && data.response.error) {
            console.error('Action failed:', data.response.error);
        }
    }
});

// Fallback - use global lb-tablet functions if available
if (typeof globalThis.useNuiEvent === 'function') {
    globalThis.useNuiEvent('updateData', (data) => updateUI(data));
}
