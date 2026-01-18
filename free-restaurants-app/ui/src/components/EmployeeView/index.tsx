import { useState, useEffect, useCallback } from 'react';
import { fetchNui } from '../../utils/nui';
import { useNuiEvent } from '../../hooks/useNuiEvent';
import {
  Order,
  EmployeeAccess,
  PlayerInfo,
  AppConfig,
  DashboardData,
  StaffMember,
} from '../../types';
import Dashboard from './Dashboard';
import OrderQueue from './OrderQueue';
import DeliveryList from './DeliveryList';
import StaffList from './StaffList';
import {
  LayoutDashboard,
  ClipboardList,
  Car,
  Users,
  Settings,
} from 'lucide-react';

interface EmployeeViewProps {
  access: EmployeeAccess | null;
  player: PlayerInfo | null;
  config: AppConfig | null;
  onSwitchToCustomer: () => void;
}

type Tab = 'dashboard' | 'orders' | 'deliveries' | 'staff' | 'settings';

export default function EmployeeView({
  access,
  player,
  config,
  onSwitchToCustomer,
}: EmployeeViewProps) {
  const [activeTab, setActiveTab] = useState<Tab>('dashboard');
  const [dashboard, setDashboard] = useState<DashboardData | null>(null);
  const [pendingOrders, setPendingOrders] = useState<Order[]>([]);
  const [availableDeliveries, setAvailableDeliveries] = useState<Order[]>([]);
  const [staff, setStaff] = useState<StaffMember[]>([]);
  const [loading, setLoading] = useState(false);

  // Load initial data
  useEffect(() => {
    loadDashboard();
    loadPendingOrders();
    if (config?.features?.deliveryOrders) {
      loadDeliveries();
    }
    loadStaff();
  }, []);

  // Listen for new orders
  useNuiEvent('newOrderReceived', (data: Order) => {
    setPendingOrders(prev => [data, ...prev]);
    loadDashboard(); // Refresh stats
  });

  // Listen for order updates
  useNuiEvent('orderStatusUpdate', (data: { orderId: string; status: string }) => {
    setPendingOrders(prev =>
      prev.map(order =>
        order.orderId === data.orderId
          ? { ...order, status: data.status as Order['status'] }
          : order
      ).filter(order => order.status === 'pending')
    );
    loadDashboard();
  });

  const loadDashboard = async () => {
    const result = await fetchNui<DashboardData>('getEmployeeDashboard');
    if (result && !('error' in result)) {
      setDashboard(result);
    }
  };

  const loadPendingOrders = async () => {
    setLoading(true);
    const result = await fetchNui<Order[]>('getPendingOrders');
    setPendingOrders(result || []);
    setLoading(false);
  };

  const loadDeliveries = async () => {
    const result = await fetchNui<Order[]>('getAvailableDeliveries');
    setAvailableDeliveries(result || []);
  };

  const loadStaff = async () => {
    const result = await fetchNui<StaffMember[]>('getOnDutyStaff');
    setStaff(result || []);
  };

  const handleOrder = useCallback(
    async (orderId: string, action: 'accept' | 'reject') => {
      const result = await fetchNui<{ success: boolean; error?: string }>(
        'handleAppOrder',
        { orderId, action }
      );

      if (result?.success) {
        setPendingOrders(prev => prev.filter(o => o.orderId !== orderId));
        loadDashboard();
      }

      return result;
    },
    []
  );

  const acceptDelivery = useCallback(async (orderId: string) => {
    const result = await fetchNui<{ success: boolean; error?: string }>(
      'acceptDelivery',
      { orderId }
    );

    if (result?.success) {
      setAvailableDeliveries(prev => prev.filter(o => o.orderId !== orderId));
    }

    return result;
  }, []);

  const toggleRestaurantStatus = useCallback(async (isOpen: boolean) => {
    const result = await fetchNui<{ success: boolean; isOpen?: boolean }>(
      'toggleRestaurantStatus',
      { isOpen }
    );

    if (result?.success) {
      setDashboard(prev =>
        prev ? { ...prev, isOpen: result.isOpen ?? isOpen } : prev
      );
    }

    return result;
  }, []);

  const callCustomer = useCallback(async (phone: string) => {
    await fetchNui('callCustomer', { phone });
  }, []);

  const messageCustomer = useCallback(
    async (phone: string, orderId: string, message: string) => {
      return await fetchNui<{ success: boolean }>('messageCustomer', {
        phone,
        orderId,
        message,
      });
    },
    []
  );

  const pendingCount = pendingOrders.length;
  const deliveryCount = availableDeliveries.length;

  const renderContent = () => {
    switch (activeTab) {
      case 'dashboard':
        return (
          <Dashboard
            data={dashboard}
            access={access}
            onToggleStatus={toggleRestaurantStatus}
            onRefresh={loadDashboard}
            config={config}
          />
        );

      case 'orders':
        return (
          <OrderQueue
            orders={pendingOrders}
            onHandle={handleOrder}
            onRefresh={loadPendingOrders}
            onCall={callCustomer}
            onMessage={messageCustomer}
            loading={loading}
          />
        );

      case 'deliveries':
        return (
          <DeliveryList
            deliveries={availableDeliveries}
            onAccept={acceptDelivery}
            onRefresh={loadDeliveries}
            config={config}
          />
        );

      case 'staff':
        return (
          <StaffList
            staff={staff}
            access={access}
            onRefresh={loadStaff}
          />
        );

      case 'settings':
        return (
          <div className="main-content">
            <div className="section-title">Settings</div>
            <div className="card">
              <div className="card-header">
                <div className="card-title">Employee Profile</div>
              </div>
              <div className="settings-content">
                <div className="setting-row">
                  <span className="setting-label">Name</span>
                  <span className="setting-value">{player?.name}</span>
                </div>
                <div className="setting-row">
                  <span className="setting-label">Position</span>
                  <span className="setting-value">{access?.gradeLabel}</span>
                </div>
                <div className="setting-row">
                  <span className="setting-label">Restaurant</span>
                  <span className="setting-value">{access?.jobLabel}</span>
                </div>
                <div className="setting-row">
                  <span className="setting-label">On Duty</span>
                  <span className={`setting-value ${access?.onduty ? 'text-success' : 'text-muted'}`}>
                    {access?.onduty ? 'Yes' : 'No'}
                  </span>
                </div>
              </div>
            </div>

            <button
              className="switch-view-btn"
              onClick={onSwitchToCustomer}
            >
              Switch to Customer View
            </button>
          </div>
        );

      default:
        return null;
    }
  };

  return (
    <>
      {/* Employee Header */}
      <div className="employee-header">
        <div className="employee-info">
          <span className="employee-name">{player?.name}</span>
          <span className="employee-role">{access?.gradeLabel}</span>
        </div>
        <div className={`duty-status ${access?.onduty ? 'on-duty' : 'off-duty'}`}>
          {access?.onduty ? 'On Duty' : 'Off Duty'}
        </div>
      </div>

      {renderContent()}

      {/* Bottom Navigation */}
      <nav className="bottom-nav employee-nav">
        <button
          className={`nav-item ${activeTab === 'dashboard' ? 'active' : ''}`}
          onClick={() => setActiveTab('dashboard')}
        >
          <LayoutDashboard className="nav-item-icon" size={20} />
          <span>Dashboard</span>
        </button>
        <button
          className={`nav-item ${activeTab === 'orders' ? 'active' : ''}`}
          onClick={() => setActiveTab('orders')}
          style={{ position: 'relative' }}
        >
          <ClipboardList className="nav-item-icon" size={20} />
          <span>Orders</span>
          {pendingCount > 0 && (
            <span className="nav-item-badge nav-item-badge-alert">
              {pendingCount}
            </span>
          )}
        </button>
        {config?.features?.deliveryOrders && (
          <button
            className={`nav-item ${activeTab === 'deliveries' ? 'active' : ''}`}
            onClick={() => setActiveTab('deliveries')}
            style={{ position: 'relative' }}
          >
            <Car className="nav-item-icon" size={20} />
            <span>Deliveries</span>
            {deliveryCount > 0 && (
              <span className="nav-item-badge">{deliveryCount}</span>
            )}
          </button>
        )}
        <button
          className={`nav-item ${activeTab === 'staff' ? 'active' : ''}`}
          onClick={() => setActiveTab('staff')}
        >
          <Users className="nav-item-icon" size={20} />
          <span>Staff</span>
        </button>
        <button
          className={`nav-item ${activeTab === 'settings' ? 'active' : ''}`}
          onClick={() => setActiveTab('settings')}
        >
          <Settings className="nav-item-icon" size={20} />
          <span>Settings</span>
        </button>
      </nav>
    </>
  );
}
