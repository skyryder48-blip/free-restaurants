import { useState } from 'react';
import { CartItem, Restaurant, AppConfig } from '../../types';
import {
  ShoppingBag,
  Plus,
  Minus,
  Trash2,
  MapPin,
  Car,
  Store,
  Loader2,
} from 'lucide-react';

interface CartProps {
  items: CartItem[];
  restaurant: Restaurant | null;
  onUpdateQuantity: (itemId: string, quantity: number) => void;
  onPlaceOrder: (orderType: 'pickup' | 'delivery') => Promise<{
    success: boolean;
    orderId?: string;
    error?: string;
    total?: number;
  } | undefined>;
  loading: boolean;
  config: AppConfig | null;
}

export default function Cart({
  items,
  restaurant,
  onUpdateQuantity,
  onPlaceOrder,
  loading,
  config,
}: CartProps) {
  const [orderType, setOrderType] = useState<'pickup' | 'delivery'>('pickup');
  const [isOrdering, setIsOrdering] = useState(false);
  const [orderError, setOrderError] = useState<string | null>(null);

  const subtotal = items.reduce((sum, item) => sum + item.price * item.quantity, 0);
  const deliveryFee =
    orderType === 'delivery' ? config?.delivery?.baseFee || 50 : 0;
  const total = subtotal + deliveryFee;

  const handlePlaceOrder = async () => {
    setOrderError(null);
    setIsOrdering(true);

    const result = await onPlaceOrder(orderType);

    setIsOrdering(false);

    if (result && !result.success) {
      setOrderError(result.error || 'Failed to place order');
    }
  };

  if (items.length === 0) {
    return (
      <div className="main-content">
        <div className="section-title">Your Cart</div>
        <div className="empty-state">
          <ShoppingBag size={64} className="empty-icon" />
          <h3>Your cart is empty</h3>
          <p>Browse restaurants and add items to your cart</p>
        </div>
      </div>
    );
  }

  return (
    <div className="cart-view">
      <div className="section-title">Your Cart</div>

      {/* Restaurant Info */}
      {restaurant && (
        <div className="cart-restaurant-info">
          <Store size={20} />
          <div>
            <span className="cart-restaurant-name">{restaurant.name}</span>
            <span className="cart-restaurant-distance">
              <MapPin size={12} />
              {formatDistance(restaurant.distance)}
            </span>
          </div>
        </div>
      )}

      {/* Order Type Selection */}
      <div className="order-type-selector">
        <button
          className={`order-type-btn ${orderType === 'pickup' ? 'active' : ''}`}
          onClick={() => setOrderType('pickup')}
          disabled={!config?.features?.pickupOrders}
        >
          <Store size={20} />
          <div className="order-type-content">
            <span className="order-type-label">Pickup</span>
            <span className="order-type-desc">Pick up at restaurant</span>
          </div>
        </button>
        <button
          className={`order-type-btn ${orderType === 'delivery' ? 'active' : ''}`}
          onClick={() => setOrderType('delivery')}
          disabled={!config?.features?.deliveryOrders}
        >
          <Car size={20} />
          <div className="order-type-content">
            <span className="order-type-label">Delivery</span>
            <span className="order-type-desc">
              +${config?.delivery?.baseFee || 50} fee
            </span>
          </div>
        </button>
      </div>

      {/* Cart Items */}
      <div className="cart-items">
        {items.map(item => (
          <div key={item.id} className="cart-item">
            <div className="cart-item-info">
              <span className="cart-item-name">{item.name}</span>
              <span className="cart-item-price">
                ${(item.price * item.quantity).toFixed(2)}
              </span>
            </div>
            <div className="cart-item-controls">
              <button
                className="cart-quantity-btn"
                onClick={() => onUpdateQuantity(item.id, item.quantity - 1)}
              >
                {item.quantity === 1 ? <Trash2 size={14} /> : <Minus size={14} />}
              </button>
              <span className="cart-quantity">{item.quantity}</span>
              <button
                className="cart-quantity-btn cart-quantity-btn-add"
                onClick={() => onUpdateQuantity(item.id, item.quantity + 1)}
              >
                <Plus size={14} />
              </button>
            </div>
          </div>
        ))}
      </div>

      {/* Order Summary */}
      <div className="cart-summary-section">
        <div className="cart-summary-row">
          <span>Subtotal</span>
          <span>${subtotal.toFixed(2)}</span>
        </div>
        {orderType === 'delivery' && (
          <div className="cart-summary-row">
            <span>Delivery Fee</span>
            <span>${deliveryFee.toFixed(2)}</span>
          </div>
        )}
        <div className="cart-summary-row cart-summary-total">
          <span>Total</span>
          <span>${total.toFixed(2)}</span>
        </div>
      </div>

      {/* Error Message */}
      {orderError && (
        <div className="cart-error">
          {orderError}
        </div>
      )}

      {/* Place Order Button */}
      <button
        className="place-order-btn"
        onClick={handlePlaceOrder}
        disabled={loading || isOrdering}
      >
        {isOrdering ? (
          <>
            <Loader2 size={20} className="spinning" />
            <span>Placing Order...</span>
          </>
        ) : (
          <>
            <span>Place Order</span>
            <span className="place-order-total">${total.toFixed(2)}</span>
          </>
        )}
      </button>
    </div>
  );
}

function formatDistance(meters: number): string {
  if (meters < 1000) {
    return `${Math.round(meters)}m`;
  }
  return `${(meters / 1000).toFixed(1)}km`;
}
