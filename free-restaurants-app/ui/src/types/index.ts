// Restaurant types
export interface Restaurant {
  id: string;
  name: string;
  type: string;
  isOpen: boolean;
  acceptsPickup: boolean;
  acceptsDelivery: boolean;
  coords?: { x: number; y: number; z: number };
  rating?: number;
  image?: string;
  distance: number;
  description?: string;
  estimatedTime?: string;
}

export interface MenuItem {
  id: string;
  name: string;
  description?: string;
  price: number;
  category: string;
  image?: string;
  available: boolean;
}

export interface CartItem extends MenuItem {
  quantity: number;
}

// Order types
export type OrderStatus =
  | 'pending'
  | 'accepted'
  | 'preparing'
  | 'ready'
  | 'on_the_way'
  | 'delivered'
  | 'picked_up'
  | 'cancelled';

export type OrderType = 'pickup' | 'delivery';

export interface OrderItem {
  id: string;
  name: string;
  price: number;
  quantity: number;
}

export interface Order {
  orderId: string;
  restaurantId: string;
  restaurantName: string;
  orderType: OrderType;
  items: OrderItem[];
  total: number;
  deliveryFee?: number;
  status: OrderStatus;
  timestamp: string;
  createdAt?: string;
  customerName?: string;
  customerPhone?: string;
  deliveryCoords?: { x: number; y: number; z: number };
  deliveryAddress?: string;
  deliveryDistance?: number;
  assignedTo?: string;
}

// Employee types
export interface StaffMember {
  citizenid: string;
  name: string;
  grade: number;
  gradeLabel: string;
  onduty: boolean;
}

export interface DashboardData {
  restaurantName: string;
  isOpen: boolean;
  acceptsPickup: boolean;
  acceptsDelivery: boolean;
  todayOrders: number;
  todayRevenue: number;
  pendingOrders: number;
  preparingOrders: number;
  readyOrders: number;
  activeDeliveries: number;
  staffOnDuty: number;
  avgPrepTime: number;
}

export interface EmployeeDashboard {
  restaurantName: string;
  isOpen: boolean;
  acceptsPickup: boolean;
  acceptsDelivery: boolean;
  pendingOrders: number;
  activeDeliveries: number;
  onDutyStaff: number;
}

export interface DeliveryOrder {
  orderId: string;
  customerName?: string;
  destination?: string;
  total: number;
  itemCount?: number;
  source: 'app' | 'npc';
}

// Access types
export interface EmployeeAccess {
  isEmployee: boolean;
  job?: string;
  jobLabel?: string;
  grade?: number;
  gradeLabel?: string;
  onduty?: boolean;
  inZone?: boolean;
  locationKey?: string;
  canAccessEmployee: boolean;
  canManage?: boolean;
  canToggleStatus?: boolean;
  citizenid?: string;
}

export interface PlayerInfo {
  name: string;
  phone: string;
  citizenid: string;
}

// Config types
export interface StatusConfig {
  label: string;
  color: string;
  icon?: string;
}

export interface RestaurantTypeConfig {
  icon: string;
  color: string;
  label: string;
}

export interface AppConfig {
  statuses: Record<string, StatusConfig>;
  restaurantTypes: Record<string, RestaurantTypeConfig>;
  features: {
    customerOrdering: boolean;
    deliveryTracking: boolean;
    employeeManagement: boolean;
    pickupOrders: boolean;
    deliveryOrders: boolean;
  };
  delivery: {
    maxDistance: number;
    baseFee: number;
    feePerKm: number;
  };
}

// NUI Message types
export interface NUIMessage {
  type: string;
  data: unknown;
}

export type ViewType = 'customer' | 'employee';
