import { useState } from 'react';
import { Order } from '../../types';
import {
  RefreshCw,
  Check,
  X,
  Phone,
  MessageSquare,
  Clock,
  MapPin,
  Store,
  Car,
  ChevronDown,
  ChevronUp,
  Send,
} from 'lucide-react';

interface OrderQueueProps {
  orders: Order[];
  onHandle: (orderId: string, action: 'accept' | 'reject') => Promise<{
    success: boolean;
    error?: string;
  } | undefined>;
  onRefresh: () => void;
  onCall: (phone: string) => void;
  onMessage: (phone: string, orderId: string, message: string) => Promise<{
    success: boolean;
  } | undefined>;
  loading: boolean;
}

export default function OrderQueue({
  orders,
  onHandle,
  onRefresh,
  onCall,
  onMessage,
  loading,
}: OrderQueueProps) {
  const [expandedOrder, setExpandedOrder] = useState<string | null>(null);
  const [messageOrder, setMessageOrder] = useState<string | null>(null);
  const [messageText, setMessageText] = useState('');
  const [processingOrders, setProcessingOrders] = useState<Set<string>>(new Set());

  const handleAction = async (orderId: string, action: 'accept' | 'reject') => {
    setProcessingOrders(prev => new Set(prev).add(orderId));
    await onHandle(orderId, action);
    setProcessingOrders(prev => {
      const next = new Set(prev);
      next.delete(orderId);
      return next;
    });
  };

  const handleSendMessage = async (order: Order) => {
    if (!messageText.trim() || !order.customerPhone) return;
    await onMessage(order.customerPhone, order.orderId, messageText);
    setMessageText('');
    setMessageOrder(null);
  };


  const formatTime = (timestamp: string) => {
    const date = new Date(timestamp);
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  };

  if (loading) {
    return (
      <div className="main-content">
        <div className="section-header">
          <div className="section-title">Order Queue</div>
          <button className="refresh-btn" onClick={onRefresh}>
            <RefreshCw size={18} />
          </button>
        </div>
        <div className="loading-container">
          <div className="loading-spinner"></div>
          <p>Loading orders...</p>
        </div>
      </div>
    );
  }

  if (orders.length === 0) {
    return (
      <div className="main-content">
        <div className="section-header">
          <div className="section-title">Order Queue</div>
          <button className="refresh-btn" onClick={onRefresh}>
            <RefreshCw size={18} />
          </button>
        </div>
        <div className="empty-state">
          <Clock size={64} className="empty-icon" />
          <h3>No Pending Orders</h3>
          <p>New orders will appear here</p>
        </div>
      </div>
    );
  }

  return (
    <div className="order-queue-view">
      <div className="section-header">
        <div className="section-title">
          Order Queue
          <span className="section-badge section-badge-alert">{orders.length}</span>
        </div>
        <button className="refresh-btn" onClick={onRefresh}>
          <RefreshCw size={18} />
        </button>
      </div>

      <div className="order-list">
        {orders.map(order => {
          const isExpanded = expandedOrder === order.orderId;
          const isProcessing = processingOrders.has(order.orderId);
          const isMessaging = messageOrder === order.orderId;
          const isDelivery = order.orderType === 'delivery';

          return (
            <div
              key={order.orderId}
              className={`order-queue-card ${isExpanded ? 'expanded' : ''}`}
            >
              {/* Order Header */}
              <div
                className="order-queue-header"
                onClick={() => setExpandedOrder(isExpanded ? null : order.orderId)}
              >
                <div className="order-queue-info">
                  <div className="order-queue-id">
                    <span>#{order.orderId}</span>
                    <span
                      className="order-type-tag"
                      style={{
                        backgroundColor: isDelivery ? '#06B6D4' : '#10B981',
                      }}
                    >
                      {isDelivery ? <Car size={12} /> : <Store size={12} />}
                      {isDelivery ? 'Delivery' : 'Pickup'}
                    </span>
                  </div>
                  <div className="order-queue-meta">
                    <span className="order-time">
                      <Clock size={12} />
                      {formatTime(order.timestamp)}
                    </span>
                    <span className="order-items-count">
                      {order.items.reduce((sum, i) => sum + i.quantity, 0)} items
                    </span>
                  </div>
                </div>
                <div className="order-queue-total">
                  ${order.total.toFixed(2)}
                  {isExpanded ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
                </div>
              </div>

              {/* Expanded Content */}
              {isExpanded && (
                <div className="order-queue-details">
                  {/* Customer Info */}
                  <div className="customer-info">
                    <span className="customer-name">{order.customerName}</span>
                    {order.customerPhone && (
                      <div className="customer-actions">
                        <button
                          className="customer-action-btn"
                          onClick={() => onCall(order.customerPhone!)}
                        >
                          <Phone size={14} />
                        </button>
                        <button
                          className="customer-action-btn"
                          onClick={() => setMessageOrder(isMessaging ? null : order.orderId)}
                        >
                          <MessageSquare size={14} />
                        </button>
                      </div>
                    )}
                  </div>

                  {/* Message Input */}
                  {isMessaging && (
                    <div className="message-input-container">
                      <input
                        type="text"
                        className="message-input"
                        placeholder="Type a message..."
                        value={messageText}
                        onChange={e => setMessageText(e.target.value)}
                        onKeyDown={e => {
                          if (e.key === 'Enter') handleSendMessage(order);
                        }}
                      />
                      <button
                        className="message-send-btn"
                        onClick={() => handleSendMessage(order)}
                      >
                        <Send size={16} />
                      </button>
                    </div>
                  )}

                  {/* Delivery Location */}
                  {isDelivery && order.deliveryAddress && (
                    <div className="delivery-location">
                      <MapPin size={14} />
                      <span>{order.deliveryAddress}</span>
                    </div>
                  )}

                  {/* Order Items */}
                  <div className="order-items-list">
                    {order.items.map((item, index) => (
                      <div key={index} className="order-item-row">
                        <span className="order-item-qty">{item.quantity}x</span>
                        <span className="order-item-name">{item.name}</span>
                        <span className="order-item-price">
                          ${(item.price * item.quantity).toFixed(2)}
                        </span>
                      </div>
                    ))}
                  </div>

                  {/* Action Buttons */}
                  <div className="order-action-buttons">
                    <button
                      className="order-action-btn reject"
                      onClick={() => handleAction(order.orderId, 'reject')}
                      disabled={isProcessing}
                    >
                      <X size={18} />
                      <span>Reject</span>
                    </button>
                    <button
                      className="order-action-btn accept"
                      onClick={() => handleAction(order.orderId, 'accept')}
                      disabled={isProcessing}
                    >
                      <Check size={18} />
                      <span>Accept</span>
                    </button>
                  </div>
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
