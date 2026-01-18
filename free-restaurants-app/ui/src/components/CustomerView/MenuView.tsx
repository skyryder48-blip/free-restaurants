import { useState } from 'react';
import { Restaurant, MenuItem, CartItem, AppConfig } from '../../types';
import { ArrowLeft, Plus, Minus, ShoppingBag } from 'lucide-react';

interface MenuViewProps {
  restaurant: Restaurant;
  menu: {
    items: MenuItem[];
    categories: string[];
    restaurantName: string;
  };
  cart: CartItem[];
  onAddToCart: (item: MenuItem) => void;
  onUpdateQuantity: (itemId: string, quantity: number) => void;
  onBack: () => void;
  config: AppConfig | null;
}

export default function MenuView({
  restaurant,
  menu,
  cart,
  onAddToCart,
  onUpdateQuantity,
  onBack,
  config,
}: MenuViewProps) {
  const [activeCategory, setActiveCategory] = useState<string>(
    menu?.categories?.[0] || 'All'
  );

  const getCartQuantity = (itemId: string): number => {
    const cartItem = cart.find(i => i.id === itemId);
    return cartItem?.quantity || 0;
  };

  const filteredItems =
    activeCategory === 'All'
      ? (menu?.items || [])
      : (menu?.items || []).filter(item => item.category === activeCategory);

  const typeStyle = config?.restaurantTypes?.[restaurant.type] ||
    config?.restaurantTypes?.default || { color: '#ff6b35' };

  return (
    <div className="menu-view">
      {/* Header */}
      <div
        className="menu-header"
        style={{
          background: `linear-gradient(135deg, ${typeStyle.color}60, ${typeStyle.color}20)`,
        }}
      >
        <button className="back-button" onClick={onBack}>
          <ArrowLeft size={20} />
        </button>
        <div className="menu-header-content">
          <h1 className="menu-title">{restaurant.name}</h1>
          {restaurant.description && (
            <p className="menu-subtitle">{restaurant.description}</p>
          )}
        </div>
      </div>

      {/* Category Tabs */}
      <div className="category-tabs">
        <div className="category-scroll">
          {['All', ...(menu?.categories || [])].map(category => (
            <button
              key={category}
              className={`category-tab ${activeCategory === category ? 'active' : ''}`}
              onClick={() => setActiveCategory(category)}
              style={
                activeCategory === category
                  ? { backgroundColor: typeStyle.color }
                  : {}
              }
            >
              {category}
            </button>
          ))}
        </div>
      </div>

      {/* Menu Items */}
      <div className="menu-content">
        {filteredItems.length === 0 ? (
          <div className="empty-state">
            <ShoppingBag size={48} className="empty-icon" />
            <h3>No Items</h3>
            <p>No items available in this category</p>
          </div>
        ) : (
          <div className="menu-grid">
            {filteredItems.map(item => {
              const quantity = getCartQuantity(item.id);
              const inCart = quantity > 0;

              return (
                <div
                  key={item.id}
                  className={`menu-item-card ${inCart ? 'in-cart' : ''} ${
                    !item.available ? 'unavailable' : ''
                  }`}
                >
                  {item.image && (
                    <div
                      className="menu-item-image"
                      style={{ backgroundImage: `url(${item.image})` }}
                    />
                  )}
                  <div className="menu-item-content">
                    <div className="menu-item-header">
                      <h3 className="menu-item-name">{item.name}</h3>
                      <span className="menu-item-price">
                        ${item.price.toFixed(2)}
                      </span>
                    </div>
                    {item.description && (
                      <p className="menu-item-description">{item.description}</p>
                    )}
                    {!item.available ? (
                      <div className="menu-item-unavailable">
                        Currently Unavailable
                      </div>
                    ) : (
                      <div className="menu-item-actions">
                        {inCart ? (
                          <div className="quantity-controls">
                            <button
                              className="quantity-btn"
                              onClick={() => onUpdateQuantity(item.id, quantity - 1)}
                            >
                              <Minus size={16} />
                            </button>
                            <span className="quantity-value">{quantity}</span>
                            <button
                              className="quantity-btn quantity-btn-add"
                              onClick={() => onAddToCart(item)}
                            >
                              <Plus size={16} />
                            </button>
                          </div>
                        ) : (
                          <button
                            className="add-to-cart-btn"
                            onClick={() => onAddToCart(item)}
                            style={{ backgroundColor: typeStyle.color }}
                          >
                            <Plus size={16} />
                            <span>Add</span>
                          </button>
                        )}
                      </div>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
