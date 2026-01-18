import { useState, useEffect, useCallback } from 'react';
import { useNuiEvent } from './hooks/useNuiEvent';
import { fetchNui } from './utils/nui';
import CustomerView from './components/CustomerView';
import EmployeeView from './components/EmployeeView';
import {
  ViewType,
  EmployeeAccess,
  PlayerInfo,
  AppConfig,
} from './types';

// Icons
import { Utensils, Briefcase } from 'lucide-react';

interface AppState {
  view: ViewType;
  access: EmployeeAccess | null;
  player: PlayerInfo | null;
  config: AppConfig | null;
  isReady: boolean;
}

function App() {
  const [state, setState] = useState<AppState>({
    view: 'customer',
    access: null,
    player: null,
    config: null,
    isReady: false,
  });

  // Handle app opened message from Lua
  useNuiEvent('appOpened', (data: {
    view: ViewType;
    access: EmployeeAccess;
    player: PlayerInfo;
    config: AppConfig;
  }) => {
    setState({
      view: data.view,
      access: data.access,
      player: data.player,
      config: data.config,
      isReady: true,
    });
  });

  // Handle app closed
  useNuiEvent('appClosed', () => {
    setState(prev => ({ ...prev, isReady: false }));
  });

  // Initialize for browser development
  useEffect(() => {
    const isEnvBrowser = !(window as any).invokeNative;
    if (isEnvBrowser) {
      // Mock data for development
      setState({
        view: 'customer',
        access: {
          isEmployee: true,
          job: 'burgershot',
          jobLabel: 'Burger Shot',
          grade: 3,
          gradeLabel: 'Manager',
          onduty: true,
          inZone: true,
          canAccessEmployee: true,
          canManage: true,
          canToggleStatus: true,
        },
        player: {
          name: 'John Smith',
          phone: '555-1234',
          citizenid: 'ABC123',
        },
        config: {
          statuses: {
            pending: { label: 'Pending', color: '#FFA500', icon: 'clock' },
            accepted: { label: 'Accepted', color: '#3B82F6', icon: 'check' },
            preparing: { label: 'Preparing', color: '#8B5CF6', icon: 'fire' },
            ready: { label: 'Ready', color: '#10B981', icon: 'bell' },
            on_the_way: { label: 'On The Way', color: '#06B6D4', icon: 'car' },
            delivered: { label: 'Delivered', color: '#22C55E', icon: 'check-circle' },
            picked_up: { label: 'Picked Up', color: '#22C55E', icon: 'bag-shopping' },
            cancelled: { label: 'Cancelled', color: '#EF4444', icon: 'times-circle' },
          },
          restaurantTypes: {
            fastfood: { icon: 'burger', color: '#F59E0B', label: 'Fast Food' },
            pizzeria: { icon: 'pizza-slice', color: '#EF4444', label: 'Pizza' },
            coffee: { icon: 'mug-hot', color: '#92400E', label: 'Coffee' },
            default: { icon: 'utensils', color: '#6B7280', label: 'Restaurant' },
          },
          features: {
            customerOrdering: true,
            deliveryTracking: true,
            employeeManagement: true,
            pickupOrders: true,
            deliveryOrders: true,
          },
          delivery: {
            maxDistance: 5000,
            baseFee: 50,
            feePerKm: 10,
          },
        },
        isReady: true,
      });
    }
  }, []);

  // Switch view handler
  const handleViewSwitch = useCallback(async (newView: ViewType) => {
    if (newView === 'employee' && !state.access?.canAccessEmployee) {
      return;
    }

    const result = await fetchNui<{ success: boolean; view?: ViewType }>(
      'switchView',
      { view: newView }
    );

    if (result.success) {
      setState(prev => ({ ...prev, view: newView }));
    }
  }, [state.access]);


  if (!state.isReady) {
    return null;
  }

  const showViewToggle = state.access?.isEmployee && state.access?.canAccessEmployee;

  return (
    <div className="app">
      {/* Header */}
      <header className="header">
        <div>
          <h1 className="header-title">Food Hub</h1>
          <p className="header-subtitle">
            {state.view === 'employee'
              ? state.access?.jobLabel || 'Employee Portal'
              : 'Order delicious food'}
          </p>
        </div>

        {/* View Toggle */}
        {showViewToggle && (
          <div className="view-toggle">
            <button
              className={`view-toggle-btn ${state.view === 'customer' ? 'active' : ''}`}
              onClick={() => handleViewSwitch('customer')}
            >
              <Utensils size={14} style={{ marginRight: '0.25rem' }} />
              Order
            </button>
            <button
              className={`view-toggle-btn ${state.view === 'employee' ? 'active' : ''}`}
              onClick={() => handleViewSwitch('employee')}
            >
              <Briefcase size={14} style={{ marginRight: '0.25rem' }} />
              Work
            </button>
          </div>
        )}
      </header>

      {/* Main Content */}
      {state.view === 'customer' ? (
        <CustomerView
          player={state.player}
          config={state.config}
        />
      ) : (
        <EmployeeView
          access={state.access}
          player={state.player}
          config={state.config}
          onSwitchToCustomer={() => handleViewSwitch('customer')}
        />
      )}
    </div>
  );
}

export default App;
