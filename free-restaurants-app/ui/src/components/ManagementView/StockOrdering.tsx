import { useState, useEffect, useCallback } from 'react';
import { fetchNui } from '../../utils/nui';
import { StockItem, StockOrder, EmployeeAccess } from '../../types';
import {
  Package,
  ShoppingCart,
  Truck,
  RefreshCw,
  Plus,
  Minus,
  MapPin,
  Clock,
  CheckCircle,
  AlertCircle,
} from 'lucide-react';

interface StockOrderingProps {
  access: EmployeeAccess | null;
}

export default function StockOrdering({ access: _access }: StockOrderingProps) {
  const [stockItems, setStockItems] = useState<StockItem[]>([]);
  const [activeOrders, setActiveOrders] = useState<StockOrder[]>([]);
  const [loading, setLoading] = useState(true);
  const [cart, setCart] = useState<Record<string, number>>({});
  const [showCartModal, setShowCartModal] = useState(false);
  const [ordering, setOrdering] = useState(false);

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    setLoading(true);
    const [itemsResult, ordersResult] = await Promise.all([
      fetchNui<StockItem[]>('getStockItems'),
      fetchNui<StockOrder[]>('getActiveStockOrders'),
    ]);
    setStockItems(itemsResult || []);
    setActiveOrders(ordersResult || []);
    setLoading(false);
  };

  const updateCart = (itemName: string, quantity: number) => {
    setCart(prev => {
      const newCart = { ...prev };
      if (quantity <= 0) {
        delete newCart[itemName];
      } else {
        newCart[itemName] = quantity;
      }
      return newCart;
    });
  };

  const getItemQuantity = (itemName: string) => cart[itemName] || 0;

  const getCartTotal = () => {
    return Object.entries(cart).reduce((total, [itemName, qty]) => {
      const item = stockItems.find(i => i.name === itemName);
      return total + (item?.price || 0) * qty;
    }, 0);
  };

  const getCartItemCount = () => {
    return Object.values(cart).reduce((a, b) => a + b, 0);
  };

  const placeOrder = useCallback(async () => {
    if (Object.keys(cart).length === 0) return;

    setOrdering(true);

    // Place orders for each item
    const promises = Object.entries(cart).map(([itemName, quantity]) =>
      fetchNui<{ success: boolean; orderId?: string }>('orderStock', {
        itemName,
        quantity,
      })
    );

    const results = await Promise.all(promises);
    const allSuccess = results.every(r => r?.success);

    if (allSuccess) {
      setCart({});
      setShowCartModal(false);
      loadData();
    }

    setOrdering(false);
  }, [cart]);

  const formatCurrency = (value: number) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 0,
    }).format(value);
  };

  const getOrderStatusIcon = (status: string) => {
    switch (status) {
      case 'ready':
        return <Truck size={18} className="status-icon ready" />;
      case 'completed':
        return <CheckCircle size={18} className="status-icon completed" />;
      case 'expired':
        return <AlertCircle size={18} className="status-icon expired" />;
      default:
        return <Clock size={18} className="status-icon pending" />;
    }
  };

  if (loading) {
    return (
      <div className="loading-container">
        <div className="loading-spinner"></div>
        <p>Loading stock items...</p>
      </div>
    );
  }

  return (
    <div className="stock-view">
      {/* Header with Cart */}
      <div className="stock-header">
        <h3 className="section-title">Order Supplies</h3>
        <div className="stock-actions">
          <button className="btn btn-icon" onClick={loadData} title="Refresh">
            <RefreshCw size={18} />
          </button>
          {getCartItemCount() > 0 && (
            <button
              className="btn btn-primary cart-btn"
              onClick={() => setShowCartModal(true)}
            >
              <ShoppingCart size={16} />
              Cart ({getCartItemCount()})
            </button>
          )}
        </div>
      </div>

      {/* Active Orders */}
      {activeOrders.length > 0 && (
        <div className="active-orders-section">
          <h4 className="subsection-title">
            <Truck size={16} />
            Pending Pickups
          </h4>
          <div className="active-orders">
            {activeOrders.map(order => (
              <div key={order.orderId} className={`order-card ${order.status}`}>
                {getOrderStatusIcon(order.status)}
                <div className="order-info">
                  <span className="order-id">Order #{order.orderId}</span>
                  <span className="order-items">
                    {order.items.map(i => `${i.quantity}x ${i.label}`).join(', ')}
                  </span>
                </div>
                <div className="order-location">
                  <MapPin size={14} />
                  <span>{order.location.label}</span>
                </div>
                <span className="crates-badge">
                  {order.cratesRemaining} crate{order.cratesRemaining !== 1 ? 's' : ''}
                </span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Stock Items Grid */}
      <div className="stock-grid">
        {stockItems.map(item => {
          const qty = getItemQuantity(item.name);

          return (
            <div key={item.name} className={`stock-card ${qty > 0 ? 'in-cart' : ''}`}>
              <div className="stock-icon">
                <Package size={24} />
              </div>
              <div className="stock-info">
                <span className="stock-name">{item.label}</span>
                <span className="stock-price">
                  {formatCurrency(item.price)} each
                </span>
              </div>
              <div className="stock-quantity">
                <button
                  className="btn btn-icon btn-sm"
                  onClick={() => updateCart(item.name, qty - 10)}
                  disabled={qty <= 0}
                >
                  <Minus size={14} />
                </button>
                <span className="qty-display">{qty}</span>
                <button
                  className="btn btn-icon btn-sm"
                  onClick={() => updateCart(item.name, qty + 10)}
                >
                  <Plus size={14} />
                </button>
              </div>
              {qty > 0 && (
                <div className="stock-subtotal">
                  {formatCurrency(item.price * qty)}
                </div>
              )}
            </div>
          );
        })}
      </div>

      {/* Cart Modal */}
      {showCartModal && (
        <div className="modal-overlay" onClick={() => setShowCartModal(false)}>
          <div className="modal" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h3>
                <ShoppingCart size={20} />
                Order Summary
              </h3>
              <button
                className="modal-close"
                onClick={() => setShowCartModal(false)}
              >
                &times;
              </button>
            </div>
            <div className="modal-body">
              <div className="cart-items">
                {Object.entries(cart).map(([itemName, qty]) => {
                  const item = stockItems.find(i => i.name === itemName);
                  if (!item) return null;

                  return (
                    <div key={itemName} className="cart-item">
                      <div className="cart-item-info">
                        <span className="cart-item-name">{item.label}</span>
                        <span className="cart-item-qty">{qty} units</span>
                      </div>
                      <span className="cart-item-price">
                        {formatCurrency(item.price * qty)}
                      </span>
                    </div>
                  );
                })}
              </div>
              <div className="cart-total">
                <span>Total</span>
                <span className="total-amount">{formatCurrency(getCartTotal())}</span>
              </div>
              <p className="cart-note">
                Orders will be deducted from business balance and available for
                pickup at a warehouse location.
              </p>
            </div>
            <div className="modal-actions">
              <button
                className="btn btn-secondary"
                onClick={() => setShowCartModal(false)}
              >
                Cancel
              </button>
              <button
                className="btn btn-primary"
                onClick={placeOrder}
                disabled={ordering}
              >
                {ordering ? 'Ordering...' : 'Place Order'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
