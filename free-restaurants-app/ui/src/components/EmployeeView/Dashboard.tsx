import { DashboardData, EmployeeAccess, AppConfig } from '../../types';
import {
  RefreshCw,
  DollarSign,
  ShoppingBag,
  TrendingUp,
  Clock,
  Power,
  PowerOff,
} from 'lucide-react';

interface DashboardProps {
  data: DashboardData | null;
  access: EmployeeAccess | null;
  onToggleStatus: (isOpen: boolean) => Promise<{ success: boolean } | undefined>;
  onRefresh: () => void;
  config?: AppConfig | null;
}

export default function Dashboard({
  data,
  access,
  onToggleStatus,
  onRefresh,
}: DashboardProps) {
  const handleToggle = async () => {
    if (!access?.canToggleStatus) return;
    await onToggleStatus(!data?.isOpen);
  };

  if (!data) {
    return (
      <div className="main-content">
        <div className="loading-container">
          <div className="loading-spinner"></div>
          <p>Loading dashboard...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="dashboard-view">
      <div className="section-header">
        <div className="section-title">Dashboard</div>
        <button className="refresh-btn" onClick={onRefresh}>
          <RefreshCw size={18} />
        </button>
      </div>

      {/* Restaurant Status Card */}
      <div className={`status-card ${data.isOpen ? 'status-open' : 'status-closed'}`}>
        <div className="status-content">
          <div className="status-icon">
            {data.isOpen ? <Power size={24} /> : <PowerOff size={24} />}
          </div>
          <div className="status-text">
            <span className="status-label">Restaurant Status</span>
            <span className="status-value">
              {data.isOpen ? 'Open for Orders' : 'Currently Closed'}
            </span>
          </div>
        </div>
        {access?.canToggleStatus && (
          <button
            className={`status-toggle-btn ${data.isOpen ? 'close' : 'open'}`}
            onClick={handleToggle}
          >
            {data.isOpen ? 'Close' : 'Open'}
          </button>
        )}
      </div>

      {/* Stats Grid */}
      <div className="stats-grid">
        <div className="stat-card">
          <div className="stat-icon stat-icon-primary">
            <ShoppingBag size={20} />
          </div>
          <div className="stat-content">
            <span className="stat-value">{data.todayOrders || 0}</span>
            <span className="stat-label">Today's Orders</span>
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-icon stat-icon-success">
            <DollarSign size={20} />
          </div>
          <div className="stat-content">
            <span className="stat-value">${(data.todayRevenue || 0).toFixed(0)}</span>
            <span className="stat-label">Today's Revenue</span>
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-icon stat-icon-warning">
            <Clock size={20} />
          </div>
          <div className="stat-content">
            <span className="stat-value">{data.pendingOrders || 0}</span>
            <span className="stat-label">Pending Orders</span>
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-icon stat-icon-info">
            <TrendingUp size={20} />
          </div>
          <div className="stat-content">
            <span className="stat-value">{data.avgPrepTime || 0}m</span>
            <span className="stat-label">Avg Prep Time</span>
          </div>
        </div>
      </div>

      {/* Quick Actions */}
      <div className="section-title">Quick Actions</div>
      <div className="quick-actions">
        {data.pendingOrders > 0 && (
          <div className="action-card action-card-alert">
            <div className="action-icon">
              <ShoppingBag size={20} />
            </div>
            <div className="action-content">
              <span className="action-title">
                {data.pendingOrders} Pending Order{data.pendingOrders > 1 ? 's' : ''}
              </span>
              <span className="action-desc">Waiting for acceptance</span>
            </div>
          </div>
        )}

        {data.preparingOrders > 0 && (
          <div className="action-card">
            <div className="action-icon action-icon-preparing">
              <Clock size={20} />
            </div>
            <div className="action-content">
              <span className="action-title">
                {data.preparingOrders} Being Prepared
              </span>
              <span className="action-desc">Orders in the kitchen</span>
            </div>
          </div>
        )}

        {data.readyOrders > 0 && (
          <div className="action-card action-card-success">
            <div className="action-icon">
              <ShoppingBag size={20} />
            </div>
            <div className="action-content">
              <span className="action-title">
                {data.readyOrders} Ready for Pickup
              </span>
              <span className="action-desc">Waiting for customers</span>
            </div>
          </div>
        )}

        {data.pendingOrders === 0 && data.preparingOrders === 0 && data.readyOrders === 0 && (
          <div className="action-card action-card-empty">
            <div className="action-content">
              <span className="action-title">All Caught Up!</span>
              <span className="action-desc">No pending orders at the moment</span>
            </div>
          </div>
        )}
      </div>

      {/* Staff on Duty */}
      {data.staffOnDuty !== undefined && (
        <div className="staff-summary">
          <span className="staff-count">{data.staffOnDuty}</span>
          <span className="staff-label">Staff Members On Duty</span>
        </div>
      )}
    </div>
  );
}
