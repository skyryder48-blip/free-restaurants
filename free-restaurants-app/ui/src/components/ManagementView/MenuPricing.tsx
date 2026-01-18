import { useState, useEffect, useCallback } from 'react';
import { fetchNui } from '../../utils/nui';
import { EmployeeAccess } from '../../types';
import {
  Tag,
  Search,
  RefreshCw,
  Save,
  DollarSign,
  Minus,
  Plus,
  RotateCcw,
} from 'lucide-react';

interface PricingItem {
  itemId: string;
  name: string;
  category: string;
  basePrice: number;
  currentPrice: number;
}

interface MenuPricingProps {
  access: EmployeeAccess | null;
}

export default function MenuPricing({ access: _access }: MenuPricingProps) {
  const [items, setItems] = useState<PricingItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<string>('all');
  const [pendingChanges, setPendingChanges] = useState<Record<string, number>>({});
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    loadPricing();
  }, []);

  const loadPricing = async () => {
    setLoading(true);
    const result = await fetchNui<PricingItem[]>('getPricing');
    setItems(result || []);
    setPendingChanges({});
    setLoading(false);
  };

  const handlePriceChange = (itemId: string, newPrice: number, basePrice: number) => {
    // Enforce price limits (50% - 200% of base)
    const minPrice = Math.floor(basePrice * 0.5);
    const maxPrice = Math.floor(basePrice * 2.0);
    const clampedPrice = Math.max(minPrice, Math.min(maxPrice, newPrice));

    setPendingChanges(prev => ({
      ...prev,
      [itemId]: clampedPrice,
    }));
  };

  const resetPrice = (itemId: string) => {
    setPendingChanges(prev => {
      const newChanges = { ...prev };
      delete newChanges[itemId];
      return newChanges;
    });
  };

  const saveChanges = useCallback(async () => {
    if (Object.keys(pendingChanges).length === 0) return;

    setSaving(true);
    const promises = Object.entries(pendingChanges).map(([itemId, price]) =>
      fetchNui<{ success: boolean }>('setPrice', { itemId, price })
    );

    await Promise.all(promises);
    await loadPricing();
    setSaving(false);
  }, [pendingChanges]);

  const categories = ['all', ...new Set(items.map(item => item.category))];

  const filteredItems = items.filter(item => {
    const matchesSearch = (item.name || '').toLowerCase().includes(searchTerm.toLowerCase());
    const matchesCategory = selectedCategory === 'all' || item.category === selectedCategory;
    return matchesSearch && matchesCategory;
  });

  const getPriceChange = (itemId: string, currentPrice: number) => {
    const newPrice = pendingChanges[itemId];
    if (newPrice === undefined) return null;
    const diff = newPrice - currentPrice;
    return { newPrice, diff, percentage: ((diff / currentPrice) * 100).toFixed(0) };
  };

  const formatCurrency = (value: number) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 0,
    }).format(value);
  };

  if (loading) {
    return (
      <div className="loading-container">
        <div className="loading-spinner"></div>
        <p>Loading menu prices...</p>
      </div>
    );
  }

  return (
    <div className="pricing-view">
      {/* Search and Filters */}
      <div className="pricing-header">
        <div className="search-input-wrapper">
          <Search size={16} className="search-icon" />
          <input
            type="text"
            className="search-input"
            placeholder="Search menu items..."
            value={searchTerm}
            onChange={e => setSearchTerm(e.target.value)}
          />
        </div>
        <div className="pricing-actions">
          <button className="btn btn-icon" onClick={loadPricing} title="Refresh">
            <RefreshCw size={18} />
          </button>
          {Object.keys(pendingChanges).length > 0 && (
            <button
              className="btn btn-primary"
              onClick={saveChanges}
              disabled={saving}
            >
              <Save size={16} />
              Save ({Object.keys(pendingChanges).length})
            </button>
          )}
        </div>
      </div>

      {/* Category Tabs */}
      <div className="category-tabs">
        {categories.map(cat => (
          <button
            key={cat}
            className={`category-tab ${selectedCategory === cat ? 'active' : ''}`}
            onClick={() => setSelectedCategory(cat)}
          >
            {cat === 'all' ? 'All Items' : cat}
          </button>
        ))}
      </div>

      {/* Price List */}
      {filteredItems.length === 0 ? (
        <div className="empty-state">
          <Tag size={32} />
          <h3>No Items Found</h3>
          <p>No menu items match your search criteria.</p>
        </div>
      ) : (
        <div className="pricing-list">
          {filteredItems.map(item => {
            const change = getPriceChange(item.itemId, item.currentPrice);
            const displayPrice = change?.newPrice ?? item.currentPrice;

            return (
              <div key={item.itemId} className="pricing-item">
                <div className="pricing-info">
                  <span className="pricing-name">{item.name}</span>
                  <span className="pricing-category">{item.category}</span>
                </div>

                <div className="pricing-controls">
                  {/* Base Price Reference */}
                  <span className="base-price" title="Base price">
                    Base: {formatCurrency(item.basePrice)}
                  </span>

                  {/* Price Adjuster */}
                  <div className="price-adjuster">
                    <button
                      className="btn btn-icon btn-sm"
                      onClick={() =>
                        handlePriceChange(
                          item.itemId,
                          displayPrice - 5,
                          item.basePrice
                        )
                      }
                    >
                      <Minus size={14} />
                    </button>

                    <div className="current-price">
                      <DollarSign size={14} />
                      <input
                        type="number"
                        className="price-input"
                        value={displayPrice}
                        onChange={e =>
                          handlePriceChange(
                            item.itemId,
                            parseInt(e.target.value, 10) || item.basePrice,
                            item.basePrice
                          )
                        }
                      />
                    </div>

                    <button
                      className="btn btn-icon btn-sm"
                      onClick={() =>
                        handlePriceChange(
                          item.itemId,
                          displayPrice + 5,
                          item.basePrice
                        )
                      }
                    >
                      <Plus size={14} />
                    </button>
                  </div>

                  {/* Change Indicator */}
                  {change && (
                    <div className="price-change">
                      <span
                        className={`change-badge ${change.diff > 0 ? 'increase' : 'decrease'}`}
                      >
                        {change.diff > 0 ? '+' : ''}
                        {change.percentage}%
                      </span>
                      <button
                        className="btn btn-icon btn-sm"
                        onClick={() => resetPrice(item.itemId)}
                        title="Reset"
                      >
                        <RotateCcw size={14} />
                      </button>
                    </div>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Price Range Guide */}
      <div className="pricing-guide">
        <span className="guide-label">Price Range:</span>
        <span className="guide-text">
          50% - 200% of base price allowed
        </span>
      </div>
    </div>
  );
}
