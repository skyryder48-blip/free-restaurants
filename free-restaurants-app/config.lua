Config = {}

-- App Configuration
Config.App = {
    -- App identity
    identifier = 'food-hub',
    name = 'Food Hub',
    description = 'Order food for pickup or delivery from local restaurants',
    icon = 'utensils', -- FontAwesome icon

    -- LB Phone/Tablet settings
    defaultApp = true, -- Pre-installed on phone
    size = 5932, -- App size in kB (for app store display)

    -- Feature toggles
    enableCustomerOrdering = true,
    enableDeliveryTracking = true,
    enableEmployeeManagement = true,
    enablePickupOrders = true,
    enableDeliveryOrders = true,

    -- Access restrictions
    requireOnDutyForEmployee = true,
    requireZoneForEmployee = true,
    minGradeForStatusToggle = 3, -- Manager+
    minGradeForManagement = 3,

    -- Delivery settings
    maxDeliveryDistance = 5000, -- meters
    baseDeliveryFee = 50,
    deliveryFeePerKm = 10,
    estimatedPrepTime = 15, -- minutes

    -- UI settings
    refreshInterval = 5000, -- ms between data refreshes
    maxOrderHistory = 20,

    -- Notifications
    notifyOnNewOrder = true,
    notifyOnStatusChange = true,
    soundOnNewOrder = true,
}

-- Order status configurations
Config.OrderStatuses = {
    pending = { label = 'Pending', color = '#FFA500', icon = 'clock' },
    accepted = { label = 'Accepted', color = '#3B82F6', icon = 'check' },
    preparing = { label = 'Preparing', color = '#8B5CF6', icon = 'fire' },
    ready = { label = 'Ready', color = '#10B981', icon = 'bell' },
    on_the_way = { label = 'On The Way', color = '#06B6D4', icon = 'car' },
    delivered = { label = 'Delivered', color = '#22C55E', icon = 'check-circle' },
    picked_up = { label = 'Picked Up', color = '#22C55E', icon = 'bag-shopping' },
    cancelled = { label = 'Cancelled', color = '#EF4444', icon = 'times-circle' },
}

-- Restaurant type icons and colors
Config.RestaurantTypes = {
    fastfood = { icon = 'burger', color = '#F59E0B', label = 'Fast Food' },
    pizzeria = { icon = 'pizza-slice', color = '#EF4444', label = 'Pizza' },
    coffee = { icon = 'mug-hot', color = '#92400E', label = 'Coffee & Cafe' },
    bar = { icon = 'martini-glass', color = '#7C3AED', label = 'Bar & Lounge' },
    mexican = { icon = 'pepper-hot', color = '#DC2626', label = 'Mexican' },
    asian = { icon = 'bowl-rice', color = '#059669', label = 'Asian' },
    default = { icon = 'utensils', color = '#6B7280', label = 'Restaurant' },
}

-- Debug mode (set to true to see debug messages in F8 console)
Config.Debug = false

return Config
