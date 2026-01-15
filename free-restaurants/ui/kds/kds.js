/**
 * Kitchen Display System (KDS) JavaScript
 * Handles order display, interactions, and real-time updates
 */

(function() {
    'use strict';

    // KDS State
    const state = {
        orders: [],
        visible: false,
        location: '',
        job: '',
        settings: {
            urgentThreshold: 300, // 5 minutes
            soundEnabled: true,
        }
    };

    // DOM Elements
    const elements = {
        container: null,
        ordersGrid: null,
        noOrders: null,
        pendingCount: null,
        progressCount: null,
        readyCount: null,
        time: null,
        location: null,
        closeBtn: null,
    };

    // Initialize DOM elements
    function initElements() {
        elements.container = document.getElementById('kds-container');
        elements.ordersGrid = document.getElementById('kds-orders');
        elements.noOrders = document.getElementById('no-orders');
        elements.pendingCount = document.getElementById('pending-count');
        elements.progressCount = document.getElementById('progress-count');
        elements.readyCount = document.getElementById('ready-count');
        elements.time = document.getElementById('kds-time');
        elements.location = document.getElementById('kds-location');
        elements.closeBtn = document.getElementById('kds-close-btn');

        // Event listeners
        if (elements.closeBtn) {
            elements.closeBtn.addEventListener('click', () => {
                hide();
                window.postNUI('kds:close', {});
            });
        }
    }

    // Format time display
    function formatTime(date) {
        return date.toLocaleTimeString('en-US', {
            hour: '2-digit',
            minute: '2-digit',
            hour12: true
        });
    }

    // Format elapsed time
    function formatElapsedTime(seconds) {
        if (seconds < 60) {
            return `${seconds}s`;
        } else if (seconds < 3600) {
            const mins = Math.floor(seconds / 60);
            return `${mins}m`;
        } else {
            const hours = Math.floor(seconds / 3600);
            const mins = Math.floor((seconds % 3600) / 60);
            return `${hours}h ${mins}m`;
        }
    }

    // Calculate elapsed seconds from order creation
    function getElapsedSeconds(createdAt) {
        const now = Date.now();
        const created = typeof createdAt === 'number' ? createdAt * 1000 : new Date(createdAt).getTime();
        return Math.floor((now - created) / 1000);
    }

    // Update clock
    function updateClock() {
        if (elements.time) {
            elements.time.textContent = formatTime(new Date());
        }
    }

    // Update stats counters
    function updateStats() {
        let pending = 0, inProgress = 0, ready = 0;

        state.orders.forEach(order => {
            switch (order.status) {
                case 'pending': pending++; break;
                case 'in_progress': inProgress++; break;
                case 'ready': ready++; break;
            }
        });

        if (elements.pendingCount) elements.pendingCount.textContent = pending;
        if (elements.progressCount) elements.progressCount.textContent = inProgress;
        if (elements.readyCount) elements.readyCount.textContent = ready;
    }

    // Create order card HTML
    function createOrderCard(order) {
        const elapsed = getElapsedSeconds(order.createdAt);
        const isUrgent = elapsed > state.settings.urgentThreshold && order.status === 'pending';

        const card = document.createElement('div');
        card.className = `order-card ${order.status}${isUrgent ? ' urgent' : ''} new`;
        card.dataset.orderId = order.id;

        // Build items list
        let itemsHtml = '';
        if (order.items && order.items.length > 0) {
            order.items.forEach(item => {
                let modsHtml = '';
                if (item.customizations && item.customizations.length > 0) {
                    modsHtml = `<div class="item-mods">${item.customizations.join(', ')}</div>`;
                }
                itemsHtml += `
                    <li class="order-item">
                        <div>
                            <div class="item-name">${item.label || item.name}</div>
                            ${modsHtml}
                        </div>
                        <span class="item-qty">x${item.amount || item.quantity || 1}</span>
                    </li>
                `;
            });
        }

        // Notes section
        let notesHtml = '';
        if (order.notes) {
            notesHtml = `<div class="order-notes">${order.notes}</div>`;
        }

        // Action buttons based on status
        let buttonsHtml = '';
        switch (order.status) {
            case 'pending':
                buttonsHtml = `
                    <button class="order-btn start" data-action="start">Start</button>
                    <button class="order-btn cancel" data-action="cancel">X</button>
                `;
                break;
            case 'in_progress':
                buttonsHtml = `
                    <button class="order-btn ready" data-action="ready">Ready</button>
                    <button class="order-btn cancel" data-action="cancel">X</button>
                `;
                break;
            case 'ready':
                buttonsHtml = `
                    <button class="order-btn complete" data-action="complete">Complete</button>
                `;
                break;
        }

        card.innerHTML = `
            <div class="order-card-header">
                <span class="order-number">#${order.id}</span>
                <span class="order-time ${isUrgent ? 'urgent' : ''}" data-created="${order.createdAt}">
                    ${formatElapsedTime(elapsed)}
                </span>
            </div>
            <div class="order-card-body">
                <div class="order-customer">
                    <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
                        <path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/>
                    </svg>
                    ${order.customerName || 'Customer'}
                </div>
                <ul class="order-items">
                    ${itemsHtml}
                </ul>
                ${notesHtml}
            </div>
            <div class="order-card-footer">
                ${buttonsHtml}
            </div>
        `;

        // Add event listeners for buttons
        card.querySelectorAll('.order-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                e.stopPropagation();
                const action = btn.dataset.action;
                handleOrderAction(order.id, action);
            });
        });

        // Remove 'new' class after animation
        setTimeout(() => card.classList.remove('new'), 300);

        return card;
    }

    // Handle order action button clicks
    function handleOrderAction(orderId, action) {
        window.postNUI('kds:action', { orderId, action });

        // Optimistic update
        const order = state.orders.find(o => o.id === orderId);
        if (order) {
            switch (action) {
                case 'start':
                    order.status = 'in_progress';
                    break;
                case 'ready':
                    order.status = 'ready';
                    break;
                case 'complete':
                case 'cancel':
                    state.orders = state.orders.filter(o => o.id !== orderId);
                    break;
            }
            render();
        }
    }

    // Render all orders
    function render() {
        if (!elements.ordersGrid) return;

        // Clear existing cards (except no-orders)
        const existingCards = elements.ordersGrid.querySelectorAll('.order-card');
        existingCards.forEach(card => card.remove());

        // Show/hide no orders message
        if (state.orders.length === 0) {
            if (elements.noOrders) elements.noOrders.style.display = 'flex';
        } else {
            if (elements.noOrders) elements.noOrders.style.display = 'none';

            // Sort orders: ready first, then by urgency, then by time
            const sortedOrders = [...state.orders].sort((a, b) => {
                // Ready orders first
                if (a.status === 'ready' && b.status !== 'ready') return -1;
                if (b.status === 'ready' && a.status !== 'ready') return 1;

                // Then pending (urgent ones first)
                const aElapsed = getElapsedSeconds(a.createdAt);
                const bElapsed = getElapsedSeconds(b.createdAt);
                const aUrgent = aElapsed > state.settings.urgentThreshold;
                const bUrgent = bElapsed > state.settings.urgentThreshold;

                if (aUrgent && !bUrgent) return -1;
                if (bUrgent && !aUrgent) return 1;

                // Then by age (oldest first)
                return bElapsed - aElapsed;
            });

            // Create cards
            sortedOrders.forEach(order => {
                const card = createOrderCard(order);
                elements.ordersGrid.appendChild(card);
            });
        }

        updateStats();
    }

    // Update elapsed times on all cards
    function updateElapsedTimes() {
        const timeElements = elements.ordersGrid.querySelectorAll('.order-time');
        timeElements.forEach(el => {
            const createdAt = el.dataset.created;
            if (createdAt) {
                const elapsed = getElapsedSeconds(parseInt(createdAt));
                const isUrgent = elapsed > state.settings.urgentThreshold;

                el.textContent = formatElapsedTime(elapsed);
                el.classList.toggle('urgent', isUrgent);

                // Also update card urgency
                const card = el.closest('.order-card');
                if (card && card.classList.contains('pending')) {
                    card.classList.toggle('urgent', isUrgent);
                }
            }
        });
    }

    // Play notification sound
    function playNewOrderSound() {
        if (state.settings.soundEnabled) {
            // NUI doesn't have direct sound access, send to Lua
            window.postNUI('kds:playSound', { sound: 'new_order' });
        }
    }

    // Public API
    window.KDS = {
        show: function(data) {
            initElements();

            state.visible = true;
            state.location = data.location || '';
            state.job = data.job || '';
            state.orders = data.orders || [];

            if (data.settings) {
                Object.assign(state.settings, data.settings);
            }

            if (elements.location) {
                elements.location.textContent = state.location;
            }

            if (elements.container) {
                elements.container.classList.remove('hidden');
            }

            render();
            updateClock();
        },

        hide: function() {
            state.visible = false;
            if (elements.container) {
                elements.container.classList.add('hidden');
            }
        },

        updateOrders: function(orders) {
            state.orders = orders || [];
            if (state.visible) {
                render();
            }
        },

        addOrder: function(order) {
            // Check if order already exists
            const existingIndex = state.orders.findIndex(o => o.id === order.id);
            if (existingIndex === -1) {
                state.orders.push(order);
                playNewOrderSound();
            } else {
                state.orders[existingIndex] = order;
            }

            if (state.visible) {
                render();
            }
        },

        updateOrder: function(orderId, status, data) {
            const order = state.orders.find(o => o.id === orderId);
            if (order) {
                order.status = status;
                if (data) {
                    Object.assign(order, data);
                }
                if (state.visible) {
                    render();
                }
            }
        },

        removeOrder: function(orderId) {
            state.orders = state.orders.filter(o => o.id !== orderId);
            if (state.visible) {
                render();
            }
        },

        getState: function() {
            return { ...state };
        }
    };

    // Initialize on DOM ready
    document.addEventListener('DOMContentLoaded', function() {
        initElements();

        // Update clock every second
        setInterval(updateClock, 1000);

        // Update elapsed times every 10 seconds
        setInterval(updateElapsedTimes, 10000);
    });

    // Keyboard handler for closing
    document.addEventListener('keydown', function(e) {
        if (state.visible && e.key === 'Escape') {
            window.KDS.hide();
            window.postNUI('kds:close', {});
        }
    });

})();
