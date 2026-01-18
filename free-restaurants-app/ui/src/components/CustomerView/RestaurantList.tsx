import { Restaurant, AppConfig } from '../../types';
import { MapPin, Clock, Star, ChevronRight } from 'lucide-react';

interface RestaurantListProps {
  restaurants: Restaurant[];
  onSelect: (restaurant: Restaurant) => void;
  loading: boolean;
  config: AppConfig | null;
}

export default function RestaurantList({
  restaurants,
  onSelect,
  loading,
  config,
}: RestaurantListProps) {
  const getTypeStyle = (type: string) => {
    const typeConfig = config?.restaurantTypes?.[type] || config?.restaurantTypes?.default;
    return {
      color: typeConfig?.color || '#6B7280',
      label: typeConfig?.label || 'Restaurant',
    };
  };

  if (loading) {
    return (
      <div className="main-content">
        <div className="section-title">Nearby Restaurants</div>
        <div className="loading-container">
          <div className="loading-spinner"></div>
          <p>Finding restaurants near you...</p>
        </div>
      </div>
    );
  }

  if (restaurants.length === 0) {
    return (
      <div className="main-content">
        <div className="section-title">Nearby Restaurants</div>
        <div className="empty-state">
          <MapPin size={48} className="empty-icon" />
          <h3>No Restaurants Available</h3>
          <p>There are no restaurants open near you right now. Check back later!</p>
        </div>
      </div>
    );
  }

  const openRestaurants = restaurants.filter(r => r.isOpen);
  const closedRestaurants = restaurants.filter(r => !r.isOpen);

  return (
    <div className="main-content">
      {/* Hero Section */}
      <div className="hero-section">
        <h1 className="hero-title">
          What are you <span className="gradient-text">craving</span>?
        </h1>
        <p className="hero-subtitle">
          Order from the best local restaurants
        </p>
      </div>

      {/* Open Restaurants */}
      {openRestaurants.length > 0 && (
        <>
          <div className="section-title">
            Open Now
            <span className="section-badge">{openRestaurants.length}</span>
          </div>
          <div className="restaurant-grid">
            {openRestaurants.map(restaurant => {
              const typeStyle = getTypeStyle(restaurant.type);
              return (
                <div
                  key={restaurant.id}
                  className="restaurant-card"
                  onClick={() => onSelect(restaurant)}
                >
                  <div
                    className="restaurant-banner"
                    style={{
                      background: `linear-gradient(135deg, ${typeStyle.color}40, ${typeStyle.color}20)`,
                    }}
                  >
                    <div
                      className="restaurant-type-badge"
                      style={{ backgroundColor: typeStyle.color }}
                    >
                      {typeStyle.label}
                    </div>
                    {restaurant.rating && (
                      <div className="restaurant-rating">
                        <Star size={12} fill="currentColor" />
                        <span>{restaurant.rating.toFixed(1)}</span>
                      </div>
                    )}
                  </div>
                  <div className="restaurant-content">
                    <h3 className="restaurant-name">{restaurant.name}</h3>
                    <div className="restaurant-meta">
                      <span className="restaurant-distance">
                        <MapPin size={12} />
                        {formatDistance(restaurant.distance)}
                      </span>
                      <span className="restaurant-time">
                        <Clock size={12} />
                        {restaurant.estimatedTime || '15-25'} min
                      </span>
                    </div>
                    {restaurant.description && (
                      <p className="restaurant-description">
                        {restaurant.description}
                      </p>
                    )}
                  </div>
                  <div className="restaurant-action">
                    <ChevronRight size={20} />
                  </div>
                </div>
              );
            })}
          </div>
        </>
      )}

      {/* Closed Restaurants */}
      {closedRestaurants.length > 0 && (
        <>
          <div className="section-title section-title-muted">
            Currently Closed
          </div>
          <div className="restaurant-grid">
            {closedRestaurants.map(restaurant => {
              const typeStyle = getTypeStyle(restaurant.type);
              return (
                <div
                  key={restaurant.id}
                  className="restaurant-card restaurant-closed"
                >
                  <div
                    className="restaurant-banner"
                    style={{
                      background: `linear-gradient(135deg, #37415140, #37415120)`,
                    }}
                  >
                    <div className="restaurant-type-badge restaurant-type-badge-closed">
                      {typeStyle.label}
                    </div>
                    <div className="closed-overlay">
                      <Clock size={16} />
                      <span>Closed</span>
                    </div>
                  </div>
                  <div className="restaurant-content">
                    <h3 className="restaurant-name">{restaurant.name}</h3>
                    <div className="restaurant-meta">
                      <span className="restaurant-distance">
                        <MapPin size={12} />
                        {formatDistance(restaurant.distance)}
                      </span>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </>
      )}
    </div>
  );
}

function formatDistance(meters: number): string {
  if (meters < 1000) {
    return `${Math.round(meters)}m`;
  }
  return `${(meters / 1000).toFixed(1)}km`;
}
