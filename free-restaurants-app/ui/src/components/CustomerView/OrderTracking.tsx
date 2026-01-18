import { Order, AppConfig } from '../../types';
import {
  Clock,
  CheckCircle,
  XCircle,
  RefreshCw,
  MapPin,
  Store,
  Car,
  ChefHat,
  Bell,
  Package,
} from 'lucide-react';

interface OrderTrackingProps {
  orders: Order[];
  onRefresh: () => void;
  config: AppConfig | null;
}

const statusIcons: Record<string, React.ReactNode> = {
  pending: <Clock size={20} />,
  accepted: <CheckCircle size={20} />,
  preparing: <ChefHat size={20} />,
  ready: <Bell size={20} />,
  on_the_way: <Car size={20} />,
  delivered: <Package size={20} />,
  picked_up: <Store size={20} />,
  cancelled: <XCircle size={20} />,
};

const statusSteps = ['pending', 'accepted', 'preparing', 'ready'];
const deliverySteps = [...statusSteps, 'on_the_way', 'delivered'];
const pickupSteps = [...statusSteps, 'picked_up'];

export default function OrderTracking({
  orders,
  onRefresh,
  config,
}: OrderTrackingProps) {
  const activeOrders = orders.filter(
    o => !['delivered', 'picked_up', 'cancelled'].includes(o.status)
  );
  const pastOrders = orders.filter(o =>
    ['delivered', 'picked_up', 'cancelled'].includes(o.status)
  );

  const getStatusConfig = (status: string) => {
    return (
      config?.statuses?.[status] || {
        label: status,
        color: '#6B7280',
      }
    );
  };

  const getStepIndex = (status: string, isDelivery: boolean) => {
    const steps = isDelivery ? deliverySteps : pickupSteps;
    return steps.indexOf(status);
  };

  if (orders.length === 0) {
    return (
      <div className="main-content">
        <div className="section-header">
          <div className="section-title">My Orders</div>
          <button className="refresh-btn" onClick={onRefresh}>
            <RefreshCw size={18} />
          </button>
        </div>
        <div className="empty-state">
          <Package size={64} className="empty-icon" />
          <h3>No Orders Yet</h3>
          <p>Your order history will appear here</p>
        </div>
      </div>
    );
  }

  return (
    <div className="order-tracking-view">
      <div className="section-header">
        <div className="section-title">My Orders</div>
        <button className="refresh-btn" onClick={onRefresh}>
          <RefreshCw size={18} />
        </button>
      </div>

      {/* Active Orders */}
      {activeOrders.length > 0 && (
        <div className="orders-section">
          <h3 className="orders-section-title">Active Orders</h3>
          {activeOrders.map(order => {
            const statusConfig = getStatusConfig(order.status);
            const isDelivery = order.orderType === 'delivery';
            const steps = isDelivery ? deliverySteps : pickupSteps;
            const currentStep = getStepIndex(order.status, isDelivery);

            return (
              <div key={order.orderId} className="order-card order-card-active">
                <div className="order-card-header">
                  <div className="order-info">
                    <span className="order-id">Order #{order.orderId}</span>
                    <span className="order-restaurant">
                      <Store size={14} />
                      {order.restaurantName}
                    </span>
                  </div>
                  <div
                    className="order-status-badge"
                    style={{ backgroundColor: statusConfig.color }}
                  >
                    {statusIcons[order.status]}
                    <span>{statusConfig.label}</span>
                  </div>
                </div>

                {/* Progress Steps */}
                <div className="order-progress">
                  {steps.slice(0, -1).map((step, index) => {
                    const stepConfig = getStatusConfig(step);
                    const isCompleted = index < currentStep;
                    const isCurrent = index === currentStep;

                    return (
                      <div
                        key={step}
                        className={`progress-step ${isCompleted ? 'completed' : ''} ${
                          isCurrent ? 'current' : ''
                        }`}
                      >
                        <div
                          className="progress-dot"
                          style={
                            isCompleted || isCurrent
                              ? { backgroundColor: stepConfig.color }
                              : {}
                          }
                        >
                          {statusIcons[step]}
                        </div>
                        <span className="progress-label">{stepConfig.label}</span>
                        {index < steps.length - 2 && (
                          <div
                            className={`progress-line ${isCompleted ? 'completed' : ''}`}
                            style={isCompleted ? { backgroundColor: stepConfig.color } : {}}
                          />
                        )}
                      </div>
                    );
                  })}
                </div>

                {/* Order Details */}
                <div className="order-details">
                  <div className="order-items-preview">
                    {order.items.slice(0, 3).map((item, i) => (
                      <span key={i} className="order-item-tag">
                        {item.quantity}x {item.name}
                      </span>
                    ))}
                    {order.items.length > 3 && (
                      <span className="order-item-tag order-item-more">
                        +{order.items.length - 3} more
                      </span>
                    )}
                  </div>
                  <div className="order-meta">
                    <span className="order-type">
                      {isDelivery ? <Car size={14} /> : <Store size={14} />}
                      {isDelivery ? 'Delivery' : 'Pickup'}
                    </span>
                    <span className="order-total">${order.total.toFixed(2)}</span>
                  </div>
                </div>

                {/* Delivery Location */}
                {isDelivery && order.status === 'on_the_way' && (
                  <div className="delivery-info">
                    <MapPin size={16} />
                    <span>Your driver is on the way!</span>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}

      {/* Past Orders */}
      {pastOrders.length > 0 && (
        <div className="orders-section">
          <h3 className="orders-section-title">Past Orders</h3>
          {pastOrders.map(order => {
            const statusConfig = getStatusConfig(order.status);
            const isCancelled = order.status === 'cancelled';

            return (
              <div
                key={order.orderId}
                className={`order-card ${isCancelled ? 'order-card-cancelled' : ''}`}
              >
                <div className="order-card-header">
                  <div className="order-info">
                    <span className="order-id">Order #{order.orderId}</span>
                    <span className="order-restaurant">
                      <Store size={14} />
                      {order.restaurantName}
                    </span>
                  </div>
                  <div
                    className="order-status-badge order-status-badge-small"
                    style={{ backgroundColor: statusConfig.color }}
                  >
                    {statusIcons[order.status]}
                    <span>{statusConfig.label}</span>
                  </div>
                </div>
                <div className="order-meta">
                  <span className="order-date">
                    {new Date(order.timestamp).toLocaleDateString()}
                  </span>
                  <span className="order-total">${order.total.toFixed(2)}</span>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
