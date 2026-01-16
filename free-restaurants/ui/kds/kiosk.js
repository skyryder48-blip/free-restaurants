/**
 * Self-Service Kiosk JavaScript
 * Handles menu display, cart management, and order placement
 */

(function() {
    'use strict';

    // Kiosk State
    const state = {
        visible: false,
        restaurantName: '',
        locationKey: '',
        menu: [],
        categories: [],
        selectedCategory: null,
        cart: [],
        taxRate: 0,
        selectedItem: null,
        selectedQty: 1,
        selectedMods: [],
    };

    // DOM Elements
    let elements = {};

    // Forward declaration of hide function (used before window.Kiosk is defined)
    function hide() {
        state.visible = false;
        if (elements.container) {
            elements.container.classList.add('hidden');
        }
        closeItemModal();
        closePaymentModal();
    }

    // Forward declarations for modal close functions
    function closeItemModal() {
        const modal = document.getElementById('item-detail-modal');
        if (modal) modal.remove();
        state.selectedItem = null;
    }

    function closePaymentModal() {
        const modal = document.getElementById('payment-modal');
        if (modal) modal.remove();
    }

    // Category Icons
    const categoryIcons = {
        'Burgers': '\uD83C\uDF54',
        'Sides': '\uD83C\uDF5F',
        'Drinks': '\uD83E\uDD64',
        'Desserts': '\uD83C\uDF66',
        'Pizza': '\uD83C\uDF55',
        'Pasta': '\uD83C\uDF5D',
        'Salads': '\uD83E\uDD57',
        'Coffee': '\u2615',
        'Tea': '\uD83C\uDF75',
        'Pastries': '\uD83E\uDDC1',
        'Breakfast': '\uD83E\uDD53',
        'Cocktails': '\uD83C\uDF78',
        'Beer': '\uD83C\uDF7A',
        'Wine': '\uD83C\uDF77',
        'Appetizers': '\uD83C\uDF71',
        'Sushi': '\uD83C\uDF63',
        'Rice': '\uD83C\uDF5A',
        'Soup': '\uD83C\uDF5C',
        'Tacos': '\uD83C\uDF2E',
        'default': '\uD83C\uDF7D\uFE0F'
    };

    // Initialize DOM elements
    function initElements() {
        elements = {
            container: document.getElementById('kiosk-container'),
            restaurantName: document.getElementById('kiosk-restaurant-name'),
            cartBtn: document.getElementById('kiosk-cart-btn'),
            cartCount: document.getElementById('kiosk-cart-count'),
            categories: document.getElementById('kiosk-categories'),
            items: document.getElementById('kiosk-items'),
            cartSidebar: document.getElementById('kiosk-cart-sidebar'),
            cartItems: document.getElementById('cart-items'),
            cartSubtotal: document.getElementById('cart-subtotal'),
            cartTax: document.getElementById('cart-tax'),
            cartTotal: document.getElementById('cart-total'),
            closeCartBtn: document.getElementById('close-cart-btn'),
            clearCartBtn: document.getElementById('clear-cart-btn'),
            checkoutBtn: document.getElementById('checkout-btn'),
            cancelBtn: document.getElementById('kiosk-cancel-btn'),
        };

        // Event listeners
        if (elements.cartBtn) {
            elements.cartBtn.addEventListener('click', toggleCart);
        }
        if (elements.closeCartBtn) {
            elements.closeCartBtn.addEventListener('click', closeCart);
        }
        if (elements.clearCartBtn) {
            elements.clearCartBtn.addEventListener('click', clearCart);
        }
        if (elements.checkoutBtn) {
            elements.checkoutBtn.addEventListener('click', showPaymentModal);
        }
        if (elements.cancelBtn) {
            elements.cancelBtn.addEventListener('click', () => {
                hide();
                window.postNUI('kiosk:cancel', {});
            });
        }
    }

    // Format currency
    function formatMoney(amount) {
        return '$' + (amount || 0).toFixed(2);
    }

    // Get category icon
    function getCategoryIcon(category) {
        return categoryIcons[category] || categoryIcons['default'];
    }

    // Render categories
    function renderCategories() {
        if (!elements.categories) return;

        elements.categories.innerHTML = '';

        state.categories.forEach((category, index) => {
            const btn = document.createElement('button');
            btn.className = 'category-btn' + (state.selectedCategory === category ? ' active' : '');
            btn.innerHTML = `
                <span class="category-icon">${getCategoryIcon(category)}</span>
                <span>${category}</span>
            `;
            btn.addEventListener('click', () => selectCategory(category));
            elements.categories.appendChild(btn);
        });
    }

    // Select category
    function selectCategory(category) {
        state.selectedCategory = category;
        renderCategories();
        renderItems();
    }

    // Render menu items
    function renderItems() {
        if (!elements.items) return;

        elements.items.innerHTML = '';

        const filteredItems = state.selectedCategory
            ? state.menu.filter(item => item.category === state.selectedCategory)
            : state.menu;

        if (filteredItems.length === 0) {
            elements.items.innerHTML = '<div class="no-items">No items in this category</div>';
            return;
        }

        filteredItems.forEach(item => {
            const card = document.createElement('div');
            card.className = 'item-card';
            card.innerHTML = `
                <div class="item-image">${getCategoryIcon(item.category)}</div>
                <div class="item-info">
                    <div class="item-name">${item.label}</div>
                    <div class="item-description">${item.description || ''}</div>
                    <div class="item-price">${formatMoney(item.price)}</div>
                    <button class="item-add-btn">+</button>
                </div>
            `;

            card.addEventListener('click', () => showItemModal(item));

            elements.items.appendChild(card);
        });
    }

    // Show item detail modal
    function showItemModal(item) {
        state.selectedItem = item;
        state.selectedQty = 1;
        state.selectedMods = [];

        let customizationsHtml = '';
        if (item.customizations && item.customizations.length > 0) {
            customizationsHtml = `
                <div class="customizations">
                    <div class="customizations-title">Customize:</div>
                    ${item.customizations.map((mod, i) => `
                        <div class="customization-option">
                            <input type="checkbox" id="mod-${i}" data-mod="${mod.label}">
                            <label for="mod-${i}">${mod.label}</label>
                        </div>
                    `).join('')}
                </div>
            `;
        }

        const modal = document.createElement('div');
        modal.className = 'item-modal';
        modal.id = 'item-detail-modal';
        modal.innerHTML = `
            <div class="item-modal-content">
                <div class="item-modal-image">${getCategoryIcon(item.category)}</div>
                <div class="item-modal-body">
                    <div class="item-modal-name">${item.label}</div>
                    <div class="item-modal-description">${item.description || ''}</div>
                    <div class="item-modal-price">${formatMoney(item.price)}</div>

                    ${customizationsHtml}

                    <div class="qty-selector">
                        <span>Quantity:</span>
                        <button class="qty-btn" id="qty-minus">-</button>
                        <span class="qty-value" id="qty-value">1</span>
                        <button class="qty-btn" id="qty-plus">+</button>
                    </div>

                    <div class="item-modal-actions">
                        <button class="item-modal-cancel" id="modal-cancel">Cancel</button>
                        <button class="item-modal-add" id="modal-add">Add to Order</button>
                    </div>
                </div>
            </div>
        `;

        document.body.appendChild(modal);

        // Event listeners
        document.getElementById('qty-minus').addEventListener('click', () => {
            if (state.selectedQty > 1) {
                state.selectedQty--;
                document.getElementById('qty-value').textContent = state.selectedQty;
            }
        });

        document.getElementById('qty-plus').addEventListener('click', () => {
            if (state.selectedQty < 10) {
                state.selectedQty++;
                document.getElementById('qty-value').textContent = state.selectedQty;
            }
        });

        document.getElementById('modal-cancel').addEventListener('click', closeItemModal);

        document.getElementById('modal-add').addEventListener('click', () => {
            // Collect modifications
            const mods = [];
            modal.querySelectorAll('.customization-option input:checked').forEach(cb => {
                mods.push(cb.dataset.mod);
            });

            addToCart(state.selectedItem, state.selectedQty, mods);
            closeItemModal();
        });

        modal.addEventListener('click', (e) => {
            if (e.target === modal) closeItemModal();
        });
    }

    // Add to cart
    function addToCart(item, qty, mods) {
        // Check if same item (without mods) exists
        const existingIndex = state.cart.findIndex(ci =>
            ci.id === item.id && JSON.stringify(ci.mods || []) === JSON.stringify(mods || [])
        );

        if (existingIndex !== -1) {
            state.cart[existingIndex].qty += qty;
        } else {
            state.cart.push({
                id: item.id,
                label: item.label,
                price: item.price,
                qty: qty,
                mods: mods,
            });
        }

        updateCartCount();
        renderCart();
    }

    // Update cart item quantity
    function updateCartQty(index, delta) {
        if (state.cart[index]) {
            state.cart[index].qty += delta;
            if (state.cart[index].qty <= 0) {
                state.cart.splice(index, 1);
            }
            updateCartCount();
            renderCart();
        }
    }

    // Remove from cart
    function removeFromCart(index) {
        state.cart.splice(index, 1);
        updateCartCount();
        renderCart();
    }

    // Clear cart
    function clearCart() {
        state.cart = [];
        updateCartCount();
        renderCart();
    }

    // Update cart count badge
    function updateCartCount() {
        if (elements.cartCount) {
            const total = state.cart.reduce((sum, item) => sum + item.qty, 0);
            elements.cartCount.textContent = total;
        }
    }

    // Calculate totals
    function calculateTotals() {
        const subtotal = state.cart.reduce((sum, item) => sum + (item.price * item.qty), 0);
        const tax = subtotal * state.taxRate;
        const total = subtotal + tax;

        return { subtotal, tax, total };
    }

    // Render cart
    function renderCart() {
        if (!elements.cartItems) return;

        if (state.cart.length === 0) {
            elements.cartItems.innerHTML = `
                <div class="cart-empty">
                    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor">
                        <path d="M7 18c-1.1 0-1.99.9-1.99 2S5.9 22 7 22s2-.9 2-2-.9-2-2-2zM1 2v2h2l3.6 7.59-1.35 2.45c-.16.28-.25.61-.25.96 0 1.1.9 2 2 2h12v-2H7.42c-.14 0-.25-.11-.25-.25l.03-.12.9-1.63h7.45c.75 0 1.41-.41 1.75-1.03l3.58-6.49c.08-.14.12-.31.12-.48 0-.55-.45-1-1-1H5.21l-.94-2H1zm16 16c-1.1 0-1.99.9-1.99 2s.89 2 1.99 2 2-.9 2-2-.9-2-2-2z"/>
                    </svg>
                    <span>Your cart is empty</span>
                </div>
            `;
        } else {
            elements.cartItems.innerHTML = state.cart.map((item, index) => `
                <div class="cart-item">
                    <div class="cart-item-info">
                        <div class="cart-item-name">${item.label}</div>
                        ${item.mods && item.mods.length > 0 ? `<div class="cart-item-mods">${item.mods.join(', ')}</div>` : ''}
                        <div class="cart-item-price">${formatMoney(item.price * item.qty)}</div>
                    </div>
                    <div class="cart-item-qty">
                        <button class="qty-btn${item.qty === 1 ? ' remove' : ''}" data-index="${index}" data-action="decrease">
                            ${item.qty === 1 ? '\u00D7' : '-'}
                        </button>
                        <span>${item.qty}</span>
                        <button class="qty-btn" data-index="${index}" data-action="increase">+</button>
                    </div>
                </div>
            `).join('');

            // Add event listeners
            elements.cartItems.querySelectorAll('.qty-btn').forEach(btn => {
                btn.addEventListener('click', (e) => {
                    const index = parseInt(btn.dataset.index);
                    const action = btn.dataset.action;
                    if (action === 'increase') {
                        updateCartQty(index, 1);
                    } else {
                        updateCartQty(index, -1);
                    }
                });
            });
        }

        // Update totals
        const { subtotal, tax, total } = calculateTotals();
        if (elements.cartSubtotal) elements.cartSubtotal.textContent = formatMoney(subtotal);
        if (elements.cartTax) elements.cartTax.textContent = formatMoney(tax);
        if (elements.cartTotal) elements.cartTotal.textContent = formatMoney(total);

        // Disable checkout if cart is empty
        if (elements.checkoutBtn) {
            elements.checkoutBtn.disabled = state.cart.length === 0;
        }
    }

    // Toggle cart sidebar
    function toggleCart() {
        if (elements.cartSidebar) {
            elements.cartSidebar.classList.toggle('hidden');
        }
    }

    // Open cart
    function openCart() {
        if (elements.cartSidebar) {
            elements.cartSidebar.classList.remove('hidden');
        }
    }

    // Close cart
    function closeCart() {
        if (elements.cartSidebar) {
            elements.cartSidebar.classList.add('hidden');
        }
    }

    // Show payment modal
    function showPaymentModal() {
        if (state.cart.length === 0) return;

        const { total } = calculateTotals();

        const modal = document.createElement('div');
        modal.className = 'payment-modal';
        modal.id = 'payment-modal';
        modal.innerHTML = `
            <div class="payment-content">
                <div class="payment-title">Payment Method</div>
                <div class="payment-total">${formatMoney(total)}</div>
                <div class="payment-methods">
                    <button class="payment-btn cash" data-method="cash">
                        \uD83D\uDCB5 Pay with Cash
                    </button>
                    <button class="payment-btn card" data-method="card">
                        \uD83D\uDCB3 Pay with Card
                    </button>
                </div>
                <button class="payment-cancel" id="payment-cancel">Cancel</button>
            </div>
        `;

        document.body.appendChild(modal);

        // Event listeners
        modal.querySelectorAll('.payment-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                const method = btn.dataset.method;
                placeOrder(method);
                closePaymentModal();
            });
        });

        document.getElementById('payment-cancel').addEventListener('click', closePaymentModal);

        modal.addEventListener('click', (e) => {
            if (e.target === modal) closePaymentModal();
        });
    }

    // Place order
    function placeOrder(paymentMethod) {
        const { subtotal, tax, total } = calculateTotals();

        const orderData = {
            locationKey: state.locationKey,
            items: state.cart.map(item => ({
                id: item.id,
                label: item.label,
                amount: item.qty,
                price: item.price,
                customizations: item.mods,
            })),
            subtotal: subtotal,
            tax: tax,
            total: total,
            paymentMethod: paymentMethod,
        };

        window.postNUI('kiosk:placeOrder', orderData);

        // Clear cart and close
        state.cart = [];
        updateCartCount();
        renderCart();
        closeCart();
    }

    // Public API
    window.Kiosk = {
        show: function(data) {
            initElements();

            state.visible = true;
            state.restaurantName = data.restaurantName || 'Restaurant';
            state.locationKey = data.locationKey || '';
            state.taxRate = data.taxRate || 0;

            if (data.menu) {
                state.menu = data.menu;
            }

            if (data.categories) {
                state.categories = data.categories;
                state.selectedCategory = data.categories[0] || null;
            }

            if (elements.restaurantName) {
                elements.restaurantName.textContent = state.restaurantName;
            }

            if (elements.container) {
                elements.container.classList.remove('hidden');
            }

            renderCategories();
            renderItems();
            renderCart();
        },

        hide: hide,

        setMenu: function(menu, categories) {
            state.menu = menu || [];
            state.categories = categories || [];
            state.selectedCategory = categories ? categories[0] : null;

            if (state.visible) {
                renderCategories();
                renderItems();
            }
        },

        getCart: function() {
            return [...state.cart];
        },

        clearCart: clearCart,

        getState: function() {
            return { ...state };
        }
    };

    // Receipt display
    window.Receipt = {
        show: function(data) {
            const modal = document.getElementById('receipt-modal');
            if (!modal) return;

            const restaurantEl = document.getElementById('receipt-restaurant');
            const orderNumEl = document.getElementById('receipt-order-num');
            const dateEl = document.getElementById('receipt-date');
            const itemsEl = document.getElementById('receipt-items');
            const totalsEl = document.getElementById('receipt-totals');
            const waitEl = document.getElementById('receipt-wait');
            const closeBtn = document.getElementById('close-receipt-btn');

            if (restaurantEl) restaurantEl.textContent = data.restaurantName || 'Restaurant';
            if (orderNumEl) orderNumEl.textContent = `Order #${data.orderId || '0000'}`;
            if (dateEl) dateEl.textContent = new Date().toLocaleString();

            // Render items
            if (itemsEl && data.items) {
                itemsEl.innerHTML = data.items.map(item => `
                    <div class="receipt-item">
                        <span class="receipt-item-name">${item.amount || item.qty}x ${item.label}</span>
                        <span class="receipt-item-price">${formatMoney((item.price || 0) * (item.amount || item.qty || 1))}</span>
                    </div>
                `).join('');
            }

            // Render totals
            if (totalsEl) {
                totalsEl.innerHTML = `
                    <div class="receipt-total-row">
                        <span>Subtotal</span>
                        <span>${formatMoney(data.subtotal || 0)}</span>
                    </div>
                    <div class="receipt-total-row">
                        <span>Tax</span>
                        <span>${formatMoney(data.tax || 0)}</span>
                    </div>
                    <div class="receipt-total-row total">
                        <span>Total</span>
                        <span>${formatMoney(data.total || 0)}</span>
                    </div>
                `;
            }

            if (waitEl) waitEl.textContent = data.estimatedWait || 'Estimated wait: 5-10 mins';

            modal.classList.remove('hidden');

            // Close button
            if (closeBtn) {
                closeBtn.onclick = () => {
                    modal.classList.add('hidden');
                    window.postNUI('receipt:close', {});
                };
            }
        },

        hide: function() {
            const modal = document.getElementById('receipt-modal');
            if (modal) modal.classList.add('hidden');
        }
    };

    // Initialize on DOM ready
    document.addEventListener('DOMContentLoaded', initElements);

    // Keyboard handler
    document.addEventListener('keydown', function(e) {
        if (state.visible && e.key === 'Escape') {
            // Close modals first
            const itemModal = document.getElementById('item-detail-modal');
            const paymentModal = document.getElementById('payment-modal');

            if (itemModal) {
                closeItemModal();
            } else if (paymentModal) {
                closePaymentModal();
            } else if (!elements.cartSidebar.classList.contains('hidden')) {
                closeCart();
            } else {
                window.Kiosk.hide();
                window.postNUI('kiosk:cancel', {});
            }
        }
    });

})();
