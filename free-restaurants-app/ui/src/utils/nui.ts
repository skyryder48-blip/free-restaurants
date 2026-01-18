// NUI Communication utilities

const isEnvBrowser = (): boolean => !(window as any).invokeNative;

// Fetch wrapper for NUI callbacks
export async function fetchNui<T = unknown>(
  event: string,
  data?: unknown
): Promise<T> {
  if (isEnvBrowser()) {
    // Return mock data for development
    return getMockData(event) as T;
  }

  const options = {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: JSON.stringify(data),
  };

  const resourceName = (window as any).GetParentResourceName
    ? (window as any).GetParentResourceName()
    : 'free-restaurants-app';

  const resp = await fetch(`https://${resourceName}/${event}`, options);
  return resp.json();
}

// Mock data for browser development
function getMockData(event: string): unknown {
  const mockData: Record<string, unknown> = {
    getRestaurants: [
      {
        id: 'burgershot',
        name: 'Burger Shot',
        type: 'fastfood',
        isOpen: true,
        acceptsPickup: true,
        acceptsDelivery: true,
      },
      {
        id: 'pizzathis',
        name: 'Pizza This',
        type: 'pizzeria',
        isOpen: true,
        acceptsPickup: true,
        acceptsDelivery: false,
      },
      {
        id: 'beanmachine',
        name: 'Bean Machine',
        type: 'coffee',
        isOpen: false,
        acceptsPickup: false,
        acceptsDelivery: false,
      },
    ],
    getMenu: {
      items: [
        { id: 'bleeder', name: 'Bleeder Burger', description: 'Our signature burger', price: 12, category: 'Burgers' },
        { id: 'heartattack', name: 'Heart Attack', description: 'Double patty madness', price: 18, category: 'Burgers' },
        { id: 'fries', name: 'Freedom Fries', description: 'Crispy golden fries', price: 5, category: 'Sides' },
        { id: 'ecola', name: 'eCola', description: 'Refreshing soda', price: 3, category: 'Drinks' },
      ],
      categories: ['Burgers', 'Sides', 'Drinks'],
      restaurantName: 'Burger Shot',
    },
    getMyOrders: [
      {
        orderId: 'APP001',
        restaurantId: 'burgershot',
        restaurantName: 'Burger Shot',
        orderType: 'delivery',
        items: [{ id: 'bleeder', name: 'Bleeder Burger', quantity: 2, price: 12 }],
        total: 74,
        deliveryFee: 50,
        status: 'preparing',
        createdAt: new Date().toISOString(),
      },
    ],
    getEmployeeDashboard: {
      restaurantName: 'Burger Shot',
      isOpen: true,
      acceptsPickup: true,
      acceptsDelivery: true,
      pendingOrders: 3,
      activeDeliveries: 1,
      onDutyStaff: 4,
    },
    getOnDutyStaff: [
      { name: 'John Smith', grade: 'Manager', gradeLevel: 3 },
      { name: 'Jane Doe', grade: 'Chef', gradeLevel: 2 },
      { name: 'Bob Wilson', grade: 'Worker', gradeLevel: 0 },
    ],
    getAccessInfo: {
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
    },
  };

  return mockData[event] || {};
}

// NUI Event listener hook helper
type NuiEventCallback<T = unknown> = (data: T) => void;

export function onNuiEvent<T = unknown>(
  event: string,
  callback: NuiEventCallback<T>
): () => void {
  const handler = (e: MessageEvent) => {
    const { type, data } = e.data;
    if (type === event) {
      callback(data as T);
    }
  };

  window.addEventListener('message', handler);
  return () => window.removeEventListener('message', handler);
}
