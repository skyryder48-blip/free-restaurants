import { useState, useEffect, useCallback } from 'react';
import { fetchNui } from '../../utils/nui';
import { useNuiEvent } from '../../hooks/useNuiEvent';
import {
  Restaurant,
  MenuItem,
  CartItem,
  Order,
  PlayerInfo,
  AppConfig,
} from '../../types';
import RestaurantList from './RestaurantList';
import MenuView from './MenuView';
import Cart from './Cart';
import OrderTracking from './OrderTracking';
import {
  Home,
  ClipboardList,
  ShoppingBag,
  User,
} from 'lucide-react';

interface CustomerViewProps {
  player: PlayerInfo | null;
  config: AppConfig | null;
}

type Tab = 'home' | 'orders' | 'cart' | 'profile';

export default function CustomerView({ player, config }: CustomerViewProps) {
  const [activeTab, setActiveTab] = useState<Tab>('home');
  const [restaurants, setRestaurants] = useState<Restaurant[]>([]);
  const [selectedRestaurant, setSelectedRestaurant] = useState<Restaurant | null>(null);
  const [menuData, setMenuData] = useState<{
    items: MenuItem[];
    categories: string[];
    restaurantName: string;
  } | null>(null);
  const [cart, setCart] = useState<CartItem[]>([]);
  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(false);

  // Load restaurants on mount
  useEffect(() => {
    loadRestaurants();
    loadOrders();
  }, []);

  // Listen for order updates
  useNuiEvent('orderStatusUpdate', (data: { orderId: string; status: string }) => {
    setOrders(prev =>
      prev.map(order =>
        order.orderId === data.orderId
          ? { ...order, status: data.status as Order['status'] }
          : order
      )
    );
  });

  const loadRestaurants = async () => {
    setLoading(true);
    const result = await fetchNui<Restaurant[]>('getRestaurants');
    setRestaurants(result || []);
    setLoading(false);
  };

  const loadOrders = async () => {
    const result = await fetchNui<Order[]>('getMyOrders');
    setOrders(result || []);
  };

  const selectRestaurant = async (restaurant: Restaurant) => {
    if (!restaurant.isOpen) return;

    setSelectedRestaurant(restaurant);
    setLoading(true);

    const menu = await fetchNui<typeof menuData>('getMenu', {
      restaurantId: restaurant.id,
    });

    setMenuData(menu);
    setLoading(false);
  };

  const goBack = () => {
    if (menuData) {
      setMenuData(null);
      setSelectedRestaurant(null);
    }
  };

  const addToCart = useCallback((item: MenuItem) => {
    setCart(prev => {
      const existing = prev.find(i => i.id === item.id);
      if (existing) {
        return prev.map(i =>
          i.id === item.id ? { ...i, quantity: i.quantity + 1 } : i
        );
      }
      return [...prev, { ...item, quantity: 1 }];
    });
  }, []);

  const updateCartQuantity = useCallback((itemId: string, quantity: number) => {
    if (quantity <= 0) {
      setCart(prev => prev.filter(i => i.id !== itemId));
    } else {
      setCart(prev =>
        prev.map(i => (i.id === itemId ? { ...i, quantity } : i))
      );
    }
  }, []);

  const clearCart = useCallback(() => {
    setCart([]);
    setSelectedRestaurant(null);
    setMenuData(null);
  }, []);

  const placeOrder = async (orderType: 'pickup' | 'delivery') => {
    if (!selectedRestaurant || cart.length === 0) return;

    setLoading(true);

    const result = await fetchNui<{
      success: boolean;
      orderId?: string;
      error?: string;
      total?: number;
    }>('placeOrder', {
      restaurantId: selectedRestaurant.id,
      items: cart.map(item => ({
        id: item.id,
        name: item.name,
        price: item.price,
        quantity: item.quantity,
      })),
      orderType,
    });

    setLoading(false);

    if (result.success) {
      clearCart();
      loadOrders();
      setActiveTab('orders');
    }

    return result;
  };

  const cartTotal = cart.reduce((sum, item) => sum + item.price * item.quantity, 0);
  const cartCount = cart.reduce((sum, item) => sum + item.quantity, 0);

  const renderContent = () => {
    switch (activeTab) {
      case 'home':
        if (menuData && selectedRestaurant) {
          return (
            <MenuView
              restaurant={selectedRestaurant}
              menu={menuData}
              cart={cart}
              onAddToCart={addToCart}
              onUpdateQuantity={updateCartQuantity}
              onBack={goBack}
              config={config}
            />
          );
        }
        return (
          <RestaurantList
            restaurants={restaurants}
            onSelect={selectRestaurant}
            loading={loading}
            config={config}
          />
        );

      case 'orders':
        return (
          <OrderTracking
            orders={orders}
            onRefresh={loadOrders}
            config={config}
          />
        );

      case 'cart':
        return (
          <Cart
            items={cart}
            restaurant={selectedRestaurant}
            onUpdateQuantity={updateCartQuantity}
            onPlaceOrder={placeOrder}
            loading={loading}
            config={config}
          />
        );

      case 'profile':
        return (
          <div className="main-content">
            <div className="section-title">Profile</div>
            <div className="card">
              <div className="card-header">
                <div
                  className="staff-avatar"
                  style={{ background: 'var(--gradient-primary)' }}
                >
                  {player?.name?.charAt(0) || 'U'}
                </div>
                <div>
                  <div className="card-title">{player?.name || 'Unknown'}</div>
                  <div className="card-subtitle">{player?.phone || 'No phone'}</div>
                </div>
              </div>
            </div>
          </div>
        );

      default:
        return null;
    }
  };

  return (
    <>
      {renderContent()}

      {/* Cart Summary Floating Button */}
      {cartCount > 0 && activeTab === 'home' && (
        <div className="cart-summary" onClick={() => setActiveTab('cart')}>
          <div className="cart-info">
            <div className="cart-count">{cartCount}</div>
            <span>View Cart</span>
          </div>
          <div className="cart-total">${cartTotal.toFixed(2)}</div>
        </div>
      )}

      {/* Bottom Navigation */}
      <nav className="bottom-nav">
        <button
          className={`nav-item ${activeTab === 'home' ? 'active' : ''}`}
          onClick={() => setActiveTab('home')}
        >
          <Home className="nav-item-icon" size={20} />
          <span>Home</span>
        </button>
        <button
          className={`nav-item ${activeTab === 'orders' ? 'active' : ''}`}
          onClick={() => setActiveTab('orders')}
          style={{ position: 'relative' }}
        >
          <ClipboardList className="nav-item-icon" size={20} />
          <span>Orders</span>
          {orders.filter(o => !['delivered', 'picked_up', 'cancelled'].includes(o.status)).length > 0 && (
            <span className="nav-item-badge">
              {orders.filter(o => !['delivered', 'picked_up', 'cancelled'].includes(o.status)).length}
            </span>
          )}
        </button>
        <button
          className={`nav-item ${activeTab === 'cart' ? 'active' : ''}`}
          onClick={() => setActiveTab('cart')}
          style={{ position: 'relative' }}
        >
          <ShoppingBag className="nav-item-icon" size={20} />
          <span>Cart</span>
          {cartCount > 0 && <span className="nav-item-badge">{cartCount}</span>}
        </button>
        <button
          className={`nav-item ${activeTab === 'profile' ? 'active' : ''}`}
          onClick={() => setActiveTab('profile')}
        >
          <User className="nav-item-icon" size={20} />
          <span>Profile</span>
        </button>
      </nav>
    </>
  );
}
