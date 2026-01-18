# Free Restaurants - Tablet/Phone App Development Plan

## Overview

This document outlines the development plan for creating an LB Phone/LB Tablet compatible restaurant application that integrates with the free-restaurants system.

## Research Summary

### LB Phone/Tablet Custom App API

Based on [LB Phone Documentation](https://docs.lbscripts.com/phone/custom-apps/) and [GitHub Templates](https://github.com/lbphone/lb-tablet-app-templates):

**Key Exports:**
```lua
-- Add custom app
exports["lb-phone"]:AddCustomApp({
    identifier = "free-restaurants",
    name = "Food Hub",
    description = "Order food for pickup or delivery",
    ui = "ui/index.html",
    onOpen = function() end,
    onClose = function() end
})

-- Send message to UI
exports["lb-phone"]:SendCustomAppMessage(identifier, data)

-- Remove app
exports["lb-phone"]:RemoveCustomApp(identifier)
```

**Template Options:**
- Vanilla JS (`lb-tablet-vanillajs`)
- React JS (`lb-tablet-reactjs`)
- React TS (`lb-tablet-reactts`) - Recommended

---

## App Architecture

### Single App with Role-Based Views

**App Name:** "Food Hub" (or configurable)

```
free-restaurants-app/
├── fxmanifest.lua
├── client/
│   └── main.lua              # App registration & NUI callbacks
├── server/
│   └── main.lua              # Order processing & business logic
├── ui/
│   ├── index.html
│   ├── src/
│   │   ├── App.tsx
│   │   ├── components/
│   │   │   ├── CustomerView/
│   │   │   │   ├── RestaurantList.tsx
│   │   │   │   ├── MenuView.tsx
│   │   │   │   ├── Cart.tsx
│   │   │   │   ├── OrderTracking.tsx
│   │   │   │   └── OrderHistory.tsx
│   │   │   ├── EmployeeView/
│   │   │   │   ├── Dashboard.tsx
│   │   │   │   ├── ManagementMenu.tsx
│   │   │   │   ├── DeliveryList.tsx
│   │   │   │   ├── CateringOrders.tsx
│   │   │   │   ├── OnDutyStaff.tsx
│   │   │   │   ├── OrderManager.tsx
│   │   │   │   └── RestaurantStatus.tsx
│   │   │   └── Shared/
│   │   │       ├── Header.tsx
│   │   │       ├── OrderCard.tsx
│   │   │       └── StatusBadge.tsx
│   │   ├── hooks/
│   │   │   ├── useNuiEvent.ts
│   │   │   └── useRestaurantData.ts
│   │   ├── types/
│   │   │   └── index.ts
│   │   └── utils/
│   │       └── nui.ts
│   └── package.json
└── config.lua
```

---

## Feature Specifications

### 1. App Entry & Authentication

**Flow:**
```
App Opens
    ↓
Check Player Job
    ↓
├─ Restaurant Employee (on-duty + in zone) → Employee View
├─ Restaurant Employee (off-duty or out of zone) → Customer View
└─ Non-Employee → Customer View
```

**Employee Detection:**
```lua
-- Check if player is restaurant employee
local function isRestaurantEmployee()
    local PlayerData = exports.qbx_core:GetPlayerData()
    return Config.Jobs[PlayerData.job.name] ~= nil
end

-- Check if in restaurant zone
local function isInRestaurantZone()
    local location = FreeRestaurants.Client.GetCurrentLocation()
    return location ~= nil
end

-- Get employee access level
local function getEmployeeAccess()
    local PlayerData = exports.qbx_core:GetPlayerData()
    local job = PlayerData.job.name
    local grade = PlayerData.job.grade.level
    local onduty = PlayerData.job.onduty
    local inZone = isInRestaurantZone()

    return {
        job = job,
        grade = grade,
        onduty = onduty,
        inZone = inZone,
        canAccessEmployee = onduty and inZone and Config.Jobs[job] ~= nil
    }
end
```

---

### 2. Customer Features

#### 2.1 Restaurant Listing
```typescript
interface Restaurant {
    id: string;           // Job name
    name: string;         // Display name
    type: string;         // fastfood, pizzeria, etc.
    isOpen: boolean;      // Toggled by employees
    acceptsPickup: boolean;
    acceptsDelivery: boolean;
    rating?: number;
    logo?: string;
    description?: string;
}
```

**Server Callback:**
```lua
lib.callback.register('free-restaurants:app:getOpenRestaurants', function(source)
    local restaurants = {}

    for jobName, jobConfig in pairs(Config.Jobs) do
        local status = restaurantStatus[jobName] or { open = false }

        if status.open then
            table.insert(restaurants, {
                id = jobName,
                name = jobConfig.label,
                type = jobConfig.type,
                isOpen = true,
                acceptsPickup = status.acceptsPickup or false,
                acceptsDelivery = status.acceptsDelivery or false,
            })
        end
    end

    return restaurants
end)
```

#### 2.2 Menu & Ordering
```typescript
interface MenuItem {
    id: string;
    name: string;
    description: string;
    price: number;
    category: string;
    image?: string;
    customizations?: Customization[];
}

interface Order {
    orderId: string;
    restaurantId: string;
    items: OrderItem[];
    type: 'pickup' | 'delivery';
    status: OrderStatus;
    total: number;
    customerPhone: string;
    deliveryLocation?: vector3;
    estimatedTime?: number;
}

type OrderStatus =
    | 'pending'      // Just placed
    | 'accepted'     // Restaurant accepted
    | 'preparing'    // In KDS, being made
    | 'ready'        // Ready for pickup/delivery
    | 'on_the_way'   // Driver en route (delivery only)
    | 'delivered'    // Completed
    | 'cancelled';
```

**Place Order Flow:**
```
Customer places order
    ↓
Server validates & creates order
    ↓
├─ Pickup: Send to KDS, notify staff
└─ Delivery: Send to KDS, add to delivery queue
    ↓
Order status updates sync to customer app
    ↓
On completion, notify customer
```

#### 2.3 Order Tracking
```typescript
interface TrackingInfo {
    status: OrderStatus;
    statusText: string;
    updatedAt: number;
    estimatedTime?: number;
    distance?: number;        // For delivery: distance from driver
    driverLocation?: vector3; // Live driver location
}
```

**Real-time Updates:**
- WebSocket-style updates via `SendCustomAppMessage`
- Status changes trigger notifications
- Distance calculation when "on_the_way"

---

### 3. Employee Features

#### 3.1 Dashboard
```typescript
interface EmployeeDashboard {
    restaurantName: string;
    isOpen: boolean;
    acceptsPickup: boolean;
    acceptsDelivery: boolean;
    pendingOrders: number;
    activeDeliveries: number;
    cateringOrders: number;
    onDutyStaff: StaffMember[];
}
```

#### 3.2 Management Menu Integration

**Permission Mapping:**
```lua
local managementPermissions = {
    canHire = 3,           -- Grade 3+
    canFire = 3,
    canSetWages = 3,
    canEditMenu = 3,
    canOrderStock = 2,     -- Grade 2+
    canAccessFinances = 3,
}
```

**Features via Tablet:**
- Employee Management (hire/fire/promote)
- Payroll Settings
- Menu Pricing
- Stock Ordering (triggers pickup mission)
- Financial Reports
- View/Clear Violations

#### 3.3 Delivery & Catering Orders

**View Available Orders:**
```lua
lib.callback.register('free-restaurants:app:getAvailableDeliveries', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    local job = player.PlayerData.job.name

    -- Only return if on duty and in zone
    if not player.PlayerData.job.onduty then return {} end

    local deliveries = {}
    for orderId, delivery in pairs(activeDeliveries) do
        if delivery.job == job and delivery.status == 'ready' then
            table.insert(deliveries, delivery)
        end
    end

    return deliveries
end)
```

**Accept Delivery from Tablet:**
```lua
lib.callback.register('free-restaurants:app:acceptDelivery', function(source, orderId)
    -- Verify player is in zone and on duty
    -- Trigger same flow as delivery station acceptance
    return acceptDeliveryOrder(source, orderId)
end)
```

#### 3.4 Restaurant Status Toggle

```lua
-- Server-side status storage
local restaurantStatus = {}

lib.callback.register('free-restaurants:app:setRestaurantStatus', function(source, status)
    local player = exports.qbx_core:GetPlayer(source)
    local job = player.PlayerData.job.name

    -- Require manager+ to toggle
    if player.PlayerData.job.grade.level < 3 then
        return false, 'Insufficient permissions'
    end

    restaurantStatus[job] = {
        open = status.open,
        acceptsPickup = status.acceptsPickup,
        acceptsDelivery = status.acceptsDelivery,
        updatedAt = GetGameTimer(),
        updatedBy = player.PlayerData.citizenid,
    }

    -- Notify all staff
    notifyJobEmployees(job, 'free-restaurants:client:statusChanged', restaurantStatus[job])

    return true
end)
```

#### 3.5 Customer Order Management

**Incoming Orders from App:**
```lua
RegisterNetEvent('free-restaurants:server:appOrderReceived', function(orderData)
    -- Validate order
    -- Create order in system
    -- Send to KDS
    -- Notify staff tablets
end)
```

**Order Status Updates:**
```lua
-- When KDS status changes, update customer app
local function updateOrderStatus(orderId, newStatus)
    local order = activeOrders[orderId]
    if not order then return end

    order.status = newStatus
    order.updatedAt = GetGameTimer()

    -- If customer ordered via app, notify them
    if order.source == 'app' and order.customerSource then
        exports['lb-phone']:SendCustomAppMessage('free-restaurants', {
            type = 'orderUpdate',
            orderId = orderId,
            status = newStatus,
        })
    end
end
```

#### 3.6 Communication with Customers

```lua
-- Call customer (uses lb-phone call system)
lib.callback.register('free-restaurants:app:callCustomer', function(source, orderId)
    local order = activeOrders[orderId]
    if not order or not order.customerPhone then return false end

    -- Trigger lb-phone call
    exports['lb-phone']:StartCall(source, order.customerPhone)
    return true
end)

-- Message customer
lib.callback.register('free-restaurants:app:messageCustomer', function(source, orderId, message)
    local order = activeOrders[orderId]
    if not order or not order.customerPhone then return false end

    -- Send via lb-phone SMS
    exports['lb-phone']:SendMessage(source, order.customerPhone, message)
    return true
end)
```

---

### 4. Database Schema Additions

```sql
-- App orders (customer orders via tablet)
CREATE TABLE IF NOT EXISTS `restaurant_app_orders` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `order_id` VARCHAR(20) NOT NULL UNIQUE,
    `job` VARCHAR(50) NOT NULL,
    `customer_citizenid` VARCHAR(50) NOT NULL,
    `customer_phone` VARCHAR(20),
    `order_type` ENUM('pickup', 'delivery') NOT NULL,
    `items` JSON NOT NULL,
    `total` INT NOT NULL,
    `status` VARCHAR(20) NOT NULL DEFAULT 'pending',
    `delivery_coords` VARCHAR(100),
    `assigned_to` VARCHAR(50),
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `completed_at` TIMESTAMP NULL,
    INDEX `idx_job_status` (`job`, `status`),
    INDEX `idx_customer` (`customer_citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Restaurant open/close status
CREATE TABLE IF NOT EXISTS `restaurant_status` (
    `job` VARCHAR(50) PRIMARY KEY,
    `is_open` BOOLEAN DEFAULT FALSE,
    `accepts_pickup` BOOLEAN DEFAULT FALSE,
    `accepts_delivery` BOOLEAN DEFAULT FALSE,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    `updated_by` VARCHAR(50)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

---

## Implementation Phases

### Phase 1: Core Infrastructure (Foundation)
1. Create app resource structure
2. Set up LB Phone/Tablet registration
3. Create React TypeScript UI boilerplate
4. Implement NUI communication layer
5. Add role detection (employee vs customer)

### Phase 2: Customer Features
1. Restaurant listing with status
2. Menu display with custom pricing
3. Cart and checkout flow
4. Order placement (pickup/delivery)
5. Order tracking with status updates
6. Order history

### Phase 3: Employee Basic Features
1. Dashboard with stats
2. Restaurant status toggle (open/closed)
3. View on-duty staff
4. Accept deliveries from tablet
5. View catering orders

### Phase 4: Employee Management Integration
1. Employee management (hire/fire)
2. Payroll settings
3. Menu pricing
4. Stock ordering
5. Financial reports

### Phase 5: Order Flow Integration
1. App orders → KDS integration
2. Real-time status sync
3. Delivery tracking with GPS
4. Customer notifications
5. Call/message customer

### Phase 6: Polish & Testing
1. UI/UX refinement
2. Performance optimization
3. Error handling
4. Testing across all scenarios
5. Documentation

---

## Technical Considerations

### NUI Communication Pattern
```typescript
// UI → Lua
const fetchNui = async <T>(event: string, data?: unknown): Promise<T> => {
    const response = await fetch(`https://${GetParentResourceName()}/${event}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    });
    return response.json();
};

// Lua → UI (via lb-phone)
// Use SendCustomAppMessage instead of SendNUIMessage
exports['lb-phone']:SendCustomAppMessage('free-restaurants', {
    type = 'orderUpdate',
    data = orderData
})
```

### State Management
- Use React Context or Zustand for global state
- Separate stores for customer/employee data
- Real-time updates via message listener

### Styling
- Use em/rem units (required by LB Phone)
- Match LB Phone's design language
- Dark/light theme support
- Mobile-optimized UI

---

## Config Options

```lua
Config.App = {
    -- App identity
    identifier = 'free-restaurants',
    name = 'Food Hub',
    description = 'Order food for pickup or delivery',

    -- Features
    enableCustomerOrdering = true,
    enableDeliveryTracking = true,
    enableEmployeeManagement = true,

    -- Restrictions
    requireOnDutyForEmployee = true,
    requireZoneForEmployee = true,
    minGradeForStatusToggle = 3,

    -- Delivery
    maxDeliveryDistance = 5000, -- meters
    deliveryFee = 50,           -- base fee
    deliveryFeePerKm = 10,      -- additional per km

    -- Notifications
    notifyOnNewOrder = true,
    notifyOnStatusChange = true,
    soundOnNewOrder = true,
}
```

---

## Integration Points

| Feature | Integrates With |
|---------|-----------------|
| Menu Display | `Config.Recipes.Items`, `getPricing` callback |
| Order Processing | `server/customers.lua` order system |
| KDS Integration | Existing KDS system via events |
| Delivery System | `server/delivery.lua` delivery flow |
| Management | `server/management.lua` callbacks |
| Catering | `server/npc-customers.lua` catering system |
| Status Toggle | New system, syncs with ordering |
| Staff List | `server/duty.lua` on-duty tracking |

---

## Next Steps

1. **Confirm scope** - Review this plan and adjust features as needed
2. **Set up development environment** - Create app resource structure
3. **Build UI framework** - React TypeScript with LB Phone styling
4. **Implement core features** - Start with Phase 1

---

## Sources

- [LB Phone Custom Apps Documentation](https://docs.lbscripts.com/phone/custom-apps/)
- [LB Phone Client Exports](https://docs.lbscripts.com/phone/exports/client-exports/)
- [LB Tablet App Templates](https://github.com/lbphone/lb-tablet-app-templates)
- [FiveM React Boilerplate](https://github.com/project-error/fivem-react-boilerplate-lua)
