--[[
    free-restaurants Client Customers System
    
    Handles:
    - Customer ordering interface
    - Menu browsing and filtering
    - Shopping cart management
    - Order placement and payment
    - Order pickup
    
    DEPENDENCIES:
    - client/main.lua (state management)
    - ox_lib (UI components)
    - ox_inventory (payment)
]]

-- ============================================================================
-- LOCAL STATE
-- ============================================================================

local cart = {}                     -- Current shopping cart
local cartTotal = 0                 -- Cart total price
local currentMenu = nil             -- Current location's menu
local pendingOrder = nil            -- Player's pending order

-- ============================================================================
-- MENU MANAGEMENT
-- ============================================================================

--- Get menu for a location
---@param locationData table Location configuration
---@return table menu Available menu items
local function getLocationMenu(locationData)
    local menu = {}
    local restaurantType = locationData.restaurantType
    
    -- Get all recipes available at this location
    for recipeId, recipeData in pairs(Config.Recipes) do
        -- Check if recipe is for this restaurant type
        if recipeData.restaurantType == restaurantType or recipeData.restaurantType == 'all' then
            -- Check if recipe is sellable
            if recipeData.sellable ~= false then
                table.insert(menu, {
                    id = recipeId,
                    label = recipeData.label,
                    description = recipeData.description,
                    price = recipeData.price or 0,
                    category = recipeData.category,
                    icon = recipeData.icon,
                    image = recipeData.image,
                    customizations = recipeData.customizations,
                })
            end
        end
    end
    
    -- Sort by category then name
    table.sort(menu, function(a, b)
        if a.category ~= b.category then
            return a.category < b.category
        end
        return a.label < b.label
    end)
    
    return menu
end

--- Get menu categories
---@param menu table Menu items
---@return table categories
local function getMenuCategories(menu)
    local categories = {}
    local seen = {}
    
    for _, item in ipairs(menu) do
        if not seen[item.category] then
            seen[item.category] = true
            table.insert(categories, item.category)
        end
    end
    
    table.sort(categories)
    return categories
end

--- Filter menu by category
---@param menu table Full menu
---@param category string Category to filter
---@return table filtered
local function filterMenuByCategory(menu, category)
    local filtered = {}
    for _, item in ipairs(menu) do
        if item.category == category then
            table.insert(filtered, item)
        end
    end
    return filtered
end

-- ============================================================================
-- CART MANAGEMENT
-- ============================================================================

--- Add item to cart
---@param item table Menu item
---@param amount? number Quantity (default: 1)
---@param customizations? table Customizations
local function addToCart(item, amount, customizations)
    amount = amount or 1
    
    -- Check for existing item (without customizations)
    local existingIndex = nil
    if not customizations or #customizations == 0 then
        for i, cartItem in ipairs(cart) do
            if cartItem.id == item.id and not cartItem.customizations then
                existingIndex = i
                break
            end
        end
    end
    
    if existingIndex then
        -- Update quantity
        cart[existingIndex].amount = cart[existingIndex].amount + amount
    else
        -- Add new item
        table.insert(cart, {
            id = item.id,
            label = item.label,
            price = item.price,
            amount = amount,
            customizations = customizations,
        })
    end
    
    -- Update total
    cartTotal = cartTotal + (item.price * amount)
    
    lib.notify({
        title = 'Added to Cart',
        description = ('%dx %s'):format(amount, item.label),
        type = 'success',
        duration = 2000,
    })
end

--- Remove item from cart
---@param index number Cart index
local function removeFromCart(index)
    local item = cart[index]
    if not item then return end
    
    cartTotal = cartTotal - (item.price * item.amount)
    table.remove(cart, index)
    
    lib.notify({
        title = 'Removed from Cart',
        description = item.label,
        type = 'inform',
        duration = 2000,
    })
end

--- Update item quantity
---@param index number Cart index
---@param newAmount number New quantity
local function updateCartQuantity(index, newAmount)
    local item = cart[index]
    if not item then return end
    
    if newAmount <= 0 then
        removeFromCart(index)
        return
    end
    
    local diff = newAmount - item.amount
    cartTotal = cartTotal + (item.price * diff)
    item.amount = newAmount
end

--- Clear cart
local function clearCart()
    cart = {}
    cartTotal = 0
end

--- Calculate cart total with tax
---@return number subtotal
---@return number tax
---@return number total
local function calculateCartTotal()
    local subtotal = cartTotal
    local taxRate = Config.Economy.Pricing.taxRate or 0
    local tax = math.floor(subtotal * taxRate)
    local total = subtotal + tax
    
    return subtotal, tax, total
end

-- ============================================================================
-- ORDERING INTERFACE
-- ============================================================================

--- Open the ordering menu
---@param locationKey string Location identifier
---@param locationData table Location configuration
local function openOrderingMenu(locationKey, locationData)
    currentMenu = getLocationMenu(locationData)
    
    if #currentMenu == 0 then
        lib.notify({
            title = 'Menu Unavailable',
            description = 'This restaurant has no items available.',
            type = 'error',
        })
        return
    end
    
    -- Show category selection
    showCategoryMenu(locationKey, locationData)
end

--- Show category selection menu
---@param locationKey string
---@param locationData table
local function showCategoryMenu(locationKey, locationData)
    local categories = getMenuCategories(currentMenu)
    local options = {}
    
    -- Restaurant header
    table.insert(options, {
        title = locationData.label,
        description = 'Welcome! Browse our menu below.',
        icon = 'store',
        disabled = true,
    })
    
    -- Add category options
    for _, category in ipairs(categories) do
        local itemCount = #filterMenuByCategory(currentMenu, category)
        
        table.insert(options, {
            title = category,
            description = ('%d items'):format(itemCount),
            icon = getCategoryIcon(category),
            onSelect = function()
                showCategoryItems(category, locationKey, locationData)
            end,
        })
    end
    
    -- Cart summary
    if #cart > 0 then
        local subtotal, tax, total = calculateCartTotal()
        table.insert(options, {
            title = ('ðŸ›’ Cart (%d items)'):format(#cart),
            description = ('Total: %s'):format(FreeRestaurants.Utils.FormatMoney(total)),
            icon = 'shopping-cart',
            onSelect = function()
                showCartMenu(locationKey, locationData)
            end,
        })
    end
    
    table.insert(options, {
        title = 'Close Menu',
        icon = 'times',
        onSelect = function()
            -- Keep cart for later
        end,
    })
    
    lib.registerContext({
        id = 'customer_menu',
        title = 'Menu',
        options = options,
    })
    
    lib.showContext('customer_menu')
end

--- Get icon for category
---@param category string
---@return string
local function getCategoryIcon(category)
    local icons = {
        Burgers = 'hamburger',
        Sides = 'french-fries',
        Drinks = 'cup-straw',
        Desserts = 'ice-cream',
        Pizza = 'pizza-slice',
        Pasta = 'bowl-food',
        Salads = 'leaf',
        Coffee = 'mug-hot',
        Tea = 'mug-saucer',
        Pastries = 'cookie',
        Breakfast = 'bacon',
        Cocktails = 'martini-glass-citrus',
        Beer = 'beer-mug-empty',
        Wine = 'wine-glass',
        Appetizers = 'plate-wheat',
    }
    return icons[category] or 'utensils'
end

--- Show items in a category
---@param category string
---@param locationKey string
---@param locationData table
local function showCategoryItems(category, locationKey, locationData)
    local items = filterMenuByCategory(currentMenu, category)
    local options = {}
    
    for _, item in ipairs(items) do
        table.insert(options, {
            title = item.label,
            description = item.description or FreeRestaurants.Utils.FormatMoney(item.price),
            icon = item.icon or 'utensils',
            metadata = {
                { label = 'Price', value = FreeRestaurants.Utils.FormatMoney(item.price) },
            },
            onSelect = function()
                showItemDetails(item, locationKey, locationData)
            end,
        })
    end
    
    lib.registerContext({
        id = 'category_items',
        title = category,
        menu = 'customer_menu',
        options = options,
    })
    
    lib.showContext('category_items')
end

--- Show item details and add to cart
---@param item table Menu item
---@param locationKey string
---@param locationData table
local function showItemDetails(item, locationKey, locationData)
    local options = {}
    
    -- Item info
    table.insert(options, {
        title = item.label,
        description = item.description or '',
        icon = item.icon or 'utensils',
        disabled = true,
    })
    
    table.insert(options, {
        title = ('Price: %s'):format(FreeRestaurants.Utils.FormatMoney(item.price)),
        disabled = true,
    })
    
    -- Add to cart options
    table.insert(options, {
        title = 'Add 1 to Cart',
        icon = 'plus',
        onSelect = function()
            addToCart(item, 1)
            showCategoryMenu(locationKey, locationData)
        end,
    })
    
    table.insert(options, {
        title = 'Add Multiple',
        icon = 'layer-group',
        onSelect = function()
            local input = lib.inputDialog('Add to Cart', {
                {
                    type = 'number',
                    label = 'Quantity',
                    default = 1,
                    min = 1,
                    max = 10,
                },
            })
            
            if input and input[1] then
                addToCart(item, input[1])
            end
            showCategoryMenu(locationKey, locationData)
        end,
    })
    
    -- Customizations if available
    if item.customizations and #item.customizations > 0 then
        table.insert(options, {
            title = 'Customize & Add',
            description = 'Make it your way',
            icon = 'sliders',
            onSelect = function()
                showCustomizations(item, locationKey, locationData)
            end,
        })
    end
    
    lib.registerContext({
        id = 'item_details',
        title = item.label,
        menu = 'category_items',
        options = options,
    })
    
    lib.showContext('item_details')
end

--- Show customization options
---@param item table
---@param locationKey string
---@param locationData table
local function showCustomizations(item, locationKey, locationData)
    local checkboxes = {}
    
    for _, custom in ipairs(item.customizations) do
        table.insert(checkboxes, {
            type = 'checkbox',
            label = custom.label,
            checked = custom.default or false,
        })
    end
    
    local input = lib.inputDialog('Customize ' .. item.label, checkboxes)
    
    if input then
        local selected = {}
        for i, custom in ipairs(item.customizations) do
            if input[i] then
                table.insert(selected, custom.label)
            end
        end
        
        addToCart(item, 1, #selected > 0 and selected or nil)
    end
    
    showCategoryMenu(locationKey, locationData)
end

--- Show cart menu
---@param locationKey string
---@param locationData table
local function showCartMenu(locationKey, locationData)
    local options = {}
    local subtotal, tax, total = calculateCartTotal()
    
    if #cart == 0 then
        table.insert(options, {
            title = 'Your cart is empty',
            description = 'Add items from the menu',
            icon = 'shopping-cart',
            disabled = true,
        })
    else
        -- Cart items
        for i, item in ipairs(cart) do
            local customStr = ''
            if item.customizations then
                customStr = ' (' .. table.concat(item.customizations, ', ') .. ')'
            end
            
            table.insert(options, {
                title = ('%dx %s%s'):format(item.amount, item.label, customStr),
                description = FreeRestaurants.Utils.FormatMoney(item.price * item.amount),
                icon = 'utensils',
                onSelect = function()
                    showCartItemOptions(i, locationKey, locationData)
                end,
            })
        end
        
        -- Totals
        table.insert(options, {
            title = '---',
            disabled = true,
        })
        
        table.insert(options, {
            title = ('Subtotal: %s'):format(FreeRestaurants.Utils.FormatMoney(subtotal)),
            disabled = true,
        })
        
        if tax > 0 then
            table.insert(options, {
                title = ('Tax: %s'):format(FreeRestaurants.Utils.FormatMoney(tax)),
                disabled = true,
            })
        end
        
        table.insert(options, {
            title = ('Total: %s'):format(FreeRestaurants.Utils.FormatMoney(total)),
            disabled = true,
        })
        
        -- Place order
        table.insert(options, {
            title = 'Place Order',
            description = 'Pay and submit your order',
            icon = 'credit-card',
            onSelect = function()
                placeOrder(locationKey, locationData)
            end,
        })
        
        -- Clear cart
        table.insert(options, {
            title = 'Clear Cart',
            icon = 'trash',
            onSelect = function()
                clearCart()
                showCategoryMenu(locationKey, locationData)
            end,
        })
    end
    
    lib.registerContext({
        id = 'cart_menu',
        title = ('Cart (%s)'):format(FreeRestaurants.Utils.FormatMoney(total)),
        menu = 'customer_menu',
        options = options,
    })
    
    lib.showContext('cart_menu')
end

--- Show cart item options
---@param index number
---@param locationKey string
---@param locationData table
local function showCartItemOptions(index, locationKey, locationData)
    local item = cart[index]
    if not item then return end
    
    local options = {
        {
            title = 'Change Quantity',
            icon = 'hashtag',
            onSelect = function()
                local input = lib.inputDialog('Change Quantity', {
                    {
                        type = 'number',
                        label = 'Quantity',
                        default = item.amount,
                        min = 0,
                        max = 10,
                    },
                })
                
                if input then
                    updateCartQuantity(index, input[1])
                end
                showCartMenu(locationKey, locationData)
            end,
        },
        {
            title = 'Remove',
            icon = 'trash',
            onSelect = function()
                removeFromCart(index)
                showCartMenu(locationKey, locationData)
            end,
        },
    }
    
    lib.registerContext({
        id = 'cart_item_options',
        title = item.label,
        menu = 'cart_menu',
        options = options,
    })
    
    lib.showContext('cart_item_options')
end

-- ============================================================================
-- ORDER PLACEMENT
-- ============================================================================

--- Place the order
---@param locationKey string
---@param locationData table
local function placeOrder(locationKey, locationData)
    if #cart == 0 then
        lib.notify({
            title = 'Cart Empty',
            description = 'Add items to your cart first.',
            type = 'error',
        })
        return
    end
    
    local subtotal, tax, total = calculateCartTotal()
    
    -- Payment method selection
    local payment = lib.alertDialog({
        header = 'Payment',
        content = ('Total: %s\n\nHow would you like to pay?'):format(
            FreeRestaurants.Utils.FormatMoney(total)
        ),
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Cash',
            cancel = 'Card',
        },
    })
    
    if not payment then return end
    
    local paymentMethod = payment == 'confirm' and 'cash' or 'card'
    
    -- Submit order to server
    lib.showTextUI('Processing order...', { icon = 'spinner' })
    
    local success, orderId, message = lib.callback.await(
        'free-restaurants:server:placeOrder',
        false,
        locationKey,
        cart,
        paymentMethod,
        total
    )
    
    lib.hideTextUI()
    
    if success then
        pendingOrder = {
            id = orderId,
            locationKey = locationKey,
            items = cart,
            total = total,
        }
        
        clearCart()
        
        lib.notify({
            title = 'Order Placed',
            description = ('Order #%s - We\'ll let you know when it\'s ready!'):format(orderId),
            type = 'success',
            duration = 5000,
        })
        
        lib.hideContext()
    else
        lib.notify({
            title = 'Order Failed',
            description = message or 'Could not place your order.',
            type = 'error',
        })
    end
end

-- ============================================================================
-- ORDER PICKUP
-- ============================================================================

--- Pickup ready order
---@param orderId string
local function pickupOrder(orderId)
    local success = lib.callback.await('free-restaurants:server:pickupOrder', false, orderId)
    
    if success then
        lib.notify({
            title = 'Order Received',
            description = 'Enjoy your food!',
            type = 'success',
        })
        pendingOrder = nil
    else
        lib.notify({
            title = 'Pickup Failed',
            description = 'Could not pickup order.',
            type = 'error',
        })
    end
end

-- ============================================================================
-- TARGET SETUP
-- ============================================================================

--- Setup customer order points
local function setupCustomerTargets()
    for restaurantType, locations in pairs(Config.Locations) do
        if type(locations) == 'table' and restaurantType ~= 'Settings' then
            for locationId, locationData in pairs(locations) do
                if type(locationData) == 'table' and locationData.enabled then
                    local key = ('%s_%s'):format(restaurantType, locationId)
                    
                    -- Counter/ordering point
                    if locationData.customer and locationData.customer.orderPoint then
                        local orderPoint = locationData.customer.orderPoint
                        
                        exports.ox_target:addBoxZone({
                            name = ('%s_order'):format(key),
                            coords = orderPoint.coords,
                            size = orderPoint.targetSize or vec3(2, 1, 2),
                            rotation = orderPoint.heading or 0,
                            debug = Config.Debug,
                            options = {
                                {
                                    name = 'order_menu',
                                    label = 'View Menu',
                                    icon = 'fa-solid fa-book-open',
                                    onSelect = function()
                                        openOrderingMenu(key, locationData)
                                    end,
                                },
                            },
                        })
                    end
                    
                    -- Pickup point
                    if locationData.customer and locationData.customer.pickupPoint then
                        local pickupPoint = locationData.customer.pickupPoint
                        
                        exports.ox_target:addBoxZone({
                            name = ('%s_pickup'):format(key),
                            coords = pickupPoint.coords,
                            size = pickupPoint.targetSize or vec3(2, 1, 2),
                            rotation = pickupPoint.heading or 0,
                            debug = Config.Debug,
                            options = {
                                {
                                    name = 'pickup_order',
                                    label = 'Pickup Order',
                                    icon = 'fa-solid fa-hand-holding',
                                    canInteract = function()
                                        return pendingOrder ~= nil
                                    end,
                                    onSelect = function()
                                        if pendingOrder then
                                            pickupOrder(pendingOrder.id)
                                        end
                                    end,
                                },
                            },
                        })
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

-- Order ready notification
RegisterNetEvent('free-restaurants:client:orderReady', function(orderId)
    if pendingOrder and pendingOrder.id == orderId then
        lib.notify({
            title = 'Order Ready!',
            description = ('Order #%s is ready for pickup!'):format(orderId),
            type = 'success',
            icon = 'bell',
            duration = 10000,
        })
        
        PlaySoundFrontend(-1, 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    end
end)

-- Initialize on ready
RegisterNetEvent('free-restaurants:client:ready', function()
    setupCustomerTargets()
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('OpenOrderingMenu', openOrderingMenu)
exports('GetCart', function() return cart end)
exports('GetCartTotal', calculateCartTotal)
exports('AddToCart', addToCart)
exports('ClearCart', clearCart)
exports('GetPendingOrder', function() return pendingOrder end)

FreeRestaurants.Utils.Debug('client/customers.lua loaded')
