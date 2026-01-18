import { useState } from 'react';
import { Order, AppConfig } from '../../types';
import {
  RefreshCw,
  Car,
  MapPin,
  Clock,
  DollarSign,
  Navigation,
  Package,
} from 'lucide-react';

interface DeliveryListProps {
  deliveries: Order[];
  onAccept: (orderId: string) => Promise<{ success: boolean; error?: string } | undefined>;
  onRefresh: () => void;
  config: AppConfig | null;
}

export default function DeliveryList({
  deliveries,
  onAccept,
  onRefresh,
  config,
}: DeliveryListProps) {
  const [acceptingId, setAcceptingId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const handleAccept = async (orderId: string) => {
    setAcceptingId(orderId);
    setError(null);

    const result = await onAccept(orderId);

    if (result && !result.success) {
      setError(result.error || 'Failed to accept delivery');
    }

    setAcceptingId(null);
  };

  const formatTime = (timestamp: string) => {
    const date = new Date(timestamp);
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  };

  const formatDistance = (meters: number): string => {
    if (meters < 1000) {
      return `${Math.round(meters)}m`;
    }
    return `${(meters / 1000).toFixed(1)}km`;
  };

  if (deliveries.length === 0) {
    return (
      <div className="main-content">
        <div className="section-header">
          <div className="section-title">Available Deliveries</div>
          <button className="refresh-btn" onClick={onRefresh}>
            <RefreshCw size={18} />
          </button>
        </div>
        <div className="empty-state">
          <Car size={64} className="empty-icon" />
          <h3>No Deliveries Available</h3>
          <p>New delivery orders will appear here</p>
        </div>
      </div>
    );
  }

  return (
    <div className="delivery-list-view">
      <div className="section-header">
        <div className="section-title">
          Available Deliveries
          <span className="section-badge">{deliveries.length}</span>
        </div>
        <button className="refresh-btn" onClick={onRefresh}>
          <RefreshCw size={18} />
        </button>
      </div>

      {error && (
        <div className="error-banner">
          {error}
        </div>
      )}

      <div className="delivery-cards">
        {deliveries.map(delivery => {
          const isAccepting = acceptingId === delivery.orderId;

          return (
            <div key={delivery.orderId} className="delivery-card">
              <div className="delivery-header">
                <div className="delivery-order-id">
                  <Package size={16} />
                  <span>Order #{delivery.orderId}</span>
                </div>
                <div className="delivery-time">
                  <Clock size={14} />
                  <span>{formatTime(delivery.timestamp)}</span>
                </div>
              </div>

              <div className="delivery-route">
                {/* Pickup Location */}
                <div className="route-point pickup">
                  <div className="route-icon">
                    <Package size={14} />
                  </div>
                  <div className="route-info">
                    <span className="route-label">Pickup</span>
                    <span className="route-address">{delivery.restaurantName}</span>
                  </div>
                </div>

                <div className="route-line"></div>

                {/* Delivery Location */}
                <div className="route-point delivery">
                  <div className="route-icon">
                    <MapPin size={14} />
                  </div>
                  <div className="route-info">
                    <span className="route-label">Deliver to</span>
                    <span className="route-address">
                      {delivery.deliveryAddress || 'Customer Location'}
                    </span>
                  </div>
                </div>
              </div>

              {/* Delivery Details */}
              <div className="delivery-details">
                <div className="delivery-stat">
                  <Navigation size={14} />
                  <span>{formatDistance(delivery.deliveryDistance || 0)}</span>
                </div>
                <div className="delivery-stat">
                  <Package size={14} />
                  <span>{delivery.items.reduce((s, i) => s + i.quantity, 0)} items</span>
                </div>
                <div className="delivery-stat delivery-payout">
                  <DollarSign size={14} />
                  <span>${(delivery.deliveryFee || config?.delivery?.baseFee || 50).toFixed(0)}</span>
                </div>
              </div>

              {/* Accept Button */}
              <button
                className="accept-delivery-btn"
                onClick={() => handleAccept(delivery.orderId)}
                disabled={isAccepting}
              >
                {isAccepting ? (
                  <span>Accepting...</span>
                ) : (
                  <>
                    <Car size={18} />
                    <span>Accept Delivery</span>
                  </>
                )}
              </button>
            </div>
          );
        })}
      </div>
    </div>
  );
}
