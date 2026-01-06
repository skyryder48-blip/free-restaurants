--[[
    free-restaurants Client Delivery System
    
    Handles:
    - Delivery mission UI
    - GPS waypoint management
    - Delivery pickup and dropoff interactions
    - Delivery vehicle management
    
    DEPENDENCIES:
    - client/main.lua
    - ox_lib
    - ox_target
]]

-- ============================================================================
-- LOCAL STATE
-- ============================================================================

local activeDelivery = nil
local deliveryBlip = nil
local deliveryCheckpoint = nil
local isOnDelivery = false

-- ============================================================================
-- GPS & WAYPOINT MANAGEMENT
-- ============================================================================

--- Set delivery waypoint
---@param coords vector3
---@param label string
local function setDeliveryWaypoint(coords, label)
    -- Remove existing blip
    clearDeliveryWaypoint()
    
    -- Create blip
    deliveryBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(deliveryBlip, 478) -- Delivery icon
    SetBlipColour(deliveryBlip, 5) -- Yellow
    SetBlipScale(deliveryBlip, 1.0)
    SetBlipRoute(deliveryBlip, true)
    SetBlipRouteColour(deliveryBlip, 5)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(label or 'Delivery')
    EndTextCommandSetBlipName(deliveryBlip)
    
    -- Set GPS waypoint
    SetNewWaypoint(coords.x, coords.y)
end

--- Clear delivery waypoint
local function clearDeliveryWaypoint()
    if deliveryBlip and DoesBlipExist(deliveryBlip) then
        RemoveBlip(deliveryBlip)
        deliveryBlip = nil
    end
    
    -- Clear GPS route
    SetWaypointOff()
end

-- ============================================================================
-- DELIVERY UI
-- ============================================================================

--- Show available deliveries menu
---@param locationKey string
---@param locationData table
local function showDeliveryMenu(locationKey, locationData)
    -- Get available deliveries
    local deliveries = lib.callback.await('free-restaurants:server:getAvailableDeliveries', false, locationData.job)
    
    local options = {}
    
    -- Header
    table.insert(options, {
        title = 'Delivery Orders',
        description = 'Available deliveries from this location',
        icon = 'truck',
        disabled = true,
    })
    
    if not deliveries or #deliveries == 0 then
        table.insert(options, {
            title = 'No Deliveries Available',
            description = 'Check back later for new orders',
            icon = 'box',
            disabled = true,
        })
        
        -- Option to request new delivery
        table.insert(options, {
            title = 'Request New Delivery',
            description = 'Generate a new delivery order',
            icon = 'plus',
            onSelect = function()
                requestNewDelivery(locationKey, locationData)
            end,
        })
    else
        for _, delivery in ipairs(deliveries) do
            local dest = delivery.destination
            local timeLeft = delivery.expiresAt - os.time()
            local timeStr = timeLeft > 60 and ('%dm'):format(math.floor(timeLeft / 60)) or ('%ds'):format(timeLeft)
            
            table.insert(options, {
                title = ('Delivery to %s'):format(dest.label or delivery.destinationKey),
                description = ('%d items - Expires: %s'):format(#delivery.items, timeStr),
                icon = 'location-dot',
                metadata = {
                    { label = 'Distance', value = dest.distance and ('%.1f km'):format(dest.distance / 1000) or 'Unknown' },
                    { label = 'Payout', value = FreeRestaurants.Utils.FormatMoney(delivery.totalPayout) },
                },
                onSelect = function()
                    showDeliveryDetails(delivery, locationKey, locationData)
                end,
            })
        end
    end
    
    lib.registerContext({
        id = 'delivery_menu',
        title = 'Deliveries',
        options = options,
    })
    
    lib.showContext('delivery_menu')
end

--- Show delivery details
---@param delivery table
---@param locationKey string
---@param locationData table
local function showDeliveryDetails(delivery, locationKey, locationData)
    local dest = delivery.destination
    
    local itemList = {}
    for _, item in ipairs(delivery.items) do
        table.insert(itemList, ('%dx %s'):format(item.amount, item.label))
    end
    
    local options = {
        {
            title = 'Delivery Details',
            description = dest.label,
            icon = 'info-circle',
            disabled = true,
        },
        {
            title = 'Items to Deliver',
            description = table.concat(itemList, ', '),
            icon = 'box',
            disabled = true,
        },
        {
            title = ('Delivery Fee: %s'):format(FreeRestaurants.Utils.FormatMoney(delivery.deliveryFee)),
            disabled = true,
        },
        {
            title = ('Estimated Tip: %s'):format(FreeRestaurants.Utils.FormatMoney(delivery.estimatedTip)),
            disabled = true,
        },
        {
            title = 'Accept Delivery',
            description = 'Start this delivery',
            icon = 'check',
            onSelect = function()
                acceptDelivery(delivery, locationKey, locationData)
            end,
        },
    }
    
    lib.registerContext({
        id = 'delivery_details',
        title = 'Delivery',
        menu = 'delivery_menu',
        options = options,
    })
    
    lib.showContext('delivery_details')
end

--- Request a new delivery
---@param locationKey string
---@param locationData table
local function requestNewDelivery(locationKey, locationData)
    lib.showTextUI('Requesting delivery...', { icon = 'spinner' })
    
    local delivery, error = lib.callback.await('free-restaurants:server:requestDelivery', false, locationKey)
    
    lib.hideTextUI()
    
    if delivery then
        lib.notify({
            title = 'New Delivery',
            description = ('Delivery to %s is ready!'):format(delivery.destination.label),
            type = 'success',
        })
        
        showDeliveryDetails(delivery, locationKey, locationData)
    else
        lib.notify({
            title = 'No Deliveries',
            description = error or 'Could not generate delivery',
            type = 'error',
        })
    end
end

-- ============================================================================
-- DELIVERY WORKFLOW
-- ============================================================================

--- Accept a delivery
---@param delivery table
---@param locationKey string
---@param locationData table
local function acceptDelivery(delivery, locationKey, locationData)
    local success = lib.callback.await('free-restaurants:server:acceptDelivery', false, delivery.id)
    
    if success then
        activeDelivery = delivery
        activeDelivery.status = 'accepted'
        isOnDelivery = true
        
        lib.notify({
            title = 'Delivery Accepted',
            description = 'Pick up the items from the packaging station',
            type = 'success',
        })
        
        -- Show pickup prompt
        lib.showTextUI('[E] Pick up delivery items', { icon = 'box' })
        
        -- Monitor for pickup
        CreateThread(function()
            waitForPickup(locationKey, locationData)
        end)
    else
        lib.notify({
            title = 'Accept Failed',
            description = 'Could not accept this delivery',
            type = 'error',
        })
    end
end

--- Wait for player to pick up items
---@param locationKey string
---@param locationData table
local function waitForPickup(locationKey, locationData)
    while activeDelivery and activeDelivery.status == 'accepted' do
        Wait(100)
        
        if IsControlJustPressed(0, 38) then -- E key
            attemptPickup()
        end
    end
    
    lib.hideTextUI()
end

--- Attempt to pick up delivery items
local function attemptPickup()
    if not activeDelivery then return end
    
    lib.showTextUI('Picking up items...', { icon = 'spinner' })
    
    local success = lib.callback.await('free-restaurants:server:pickupDelivery', false, activeDelivery.id)
    
    lib.hideTextUI()
    
    if success then
        activeDelivery.status = 'picked_up'
        
        lib.notify({
            title = 'Items Collected',
            description = 'Head to the delivery location',
            type = 'success',
        })
        
        -- Set waypoint to destination
        local dest = activeDelivery.destination
        setDeliveryWaypoint(dest.coords, dest.label)
        
        -- Start delivery tracking
        CreateThread(function()
            trackDeliveryProgress()
        end)
    else
        lib.notify({
            title = 'Pickup Failed',
            description = 'Make sure you have all the required items',
            type = 'error',
        })
    end
end

--- Track delivery progress and arrival
local function trackDeliveryProgress()
    while activeDelivery and activeDelivery.status == 'picked_up' do
        Wait(500)
        
        local playerCoords = GetEntityCoords(cache.ped)
        local dest = activeDelivery.destination
        local distance = #(playerCoords - dest.coords)
        
        -- Update HUD with distance
        if distance < 200 then
            lib.showTextUI(('Destination: %.0fm'):format(distance), { icon = 'location-dot' })
        end
        
        -- Check if arrived
        if distance < 3.0 then
            lib.hideTextUI()
            arriveAtDestination()
            break
        end
    end
end

--- Handle arrival at destination
local function arriveAtDestination()
    if not activeDelivery then return end
    
    lib.notify({
        title = 'Arrived',
        description = 'Press E to complete delivery',
        type = 'inform',
    })
    
    lib.showTextUI('[E] Complete Delivery', { icon = 'check' })
    
    -- Wait for completion
    CreateThread(function()
        while activeDelivery and activeDelivery.status == 'picked_up' do
            Wait(100)
            
            local playerCoords = GetEntityCoords(cache.ped)
            local distance = #(playerCoords - activeDelivery.destination.coords)
            
            -- Check if player left
            if distance > 10.0 then
                lib.hideTextUI()
                lib.notify({
                    title = 'Too Far',
                    description = 'Return to the delivery location',
                    type = 'warning',
                })
                trackDeliveryProgress()
                return
            end
            
            if IsControlJustPressed(0, 38) then -- E key
                completeDelivery()
                break
            end
        end
    end)
end

--- Complete the delivery
local function completeDelivery()
    if not activeDelivery then return end
    
    -- Progress bar for delivery animation
    local success = lib.progressCircle({
        duration = 3000,
        label = 'Delivering order...',
        useWhileDead = false,
        canCancel = false,
        disable = {
            move = true,
            combat = true,
        },
        anim = {
            dict = 'mp_common',
            clip = 'givetake1_a',
        },
    })
    
    if success then
        local completed, earnings = lib.callback.await('free-restaurants:server:completeDelivery', false, activeDelivery.id)
        
        lib.hideTextUI()
        clearDeliveryWaypoint()
        
        if completed then
            lib.notify({
                title = 'Delivery Complete!',
                description = ('You earned %s'):format(FreeRestaurants.Utils.FormatMoney(earnings)),
                type = 'success',
                duration = 5000,
            })
            
            activeDelivery = nil
            isOnDelivery = false
        else
            lib.notify({
                title = 'Delivery Failed',
                description = 'Could not complete delivery',
                type = 'error',
            })
        end
    end
end

--- Cancel active delivery
local function cancelActiveDelivery()
    if not activeDelivery then return end
    
    local confirm = lib.alertDialog({
        header = 'Cancel Delivery',
        content = 'Are you sure you want to cancel this delivery?',
        centered = true,
        cancel = true,
    })
    
    if confirm == 'confirm' then
        local success = lib.callback.await('free-restaurants:server:cancelDelivery', false, activeDelivery.id, 'Player cancelled')
        
        if success then
            clearDeliveryWaypoint()
            lib.hideTextUI()
            
            lib.notify({
                title = 'Delivery Cancelled',
                type = 'inform',
            })
            
            activeDelivery = nil
            isOnDelivery = false
        end
    end
end

-- ============================================================================
-- TARGET SETUP
-- ============================================================================

--- Setup delivery targets for a location
---@param locationKey string
---@param locationData table
local function setupDeliveryTargets(locationKey, locationData)
    -- Delivery board/station
    if locationData.delivery and locationData.delivery.board then
        local board = locationData.delivery.board
        
        exports.ox_target:addBoxZone({
            name = ('%s_delivery_board'):format(locationKey),
            coords = board.coords,
            size = board.targetSize or vec3(1.0, 1.0, 2.0),
            rotation = board.heading or 0,
            debug = Config.Debug,
            options = {
                {
                    name = 'view_deliveries',
                    label = 'View Deliveries',
                    icon = 'fa-solid fa-truck',
                    canInteract = function()
                        return FreeRestaurants.Client.IsOnDuty()
                    end,
                    onSelect = function()
                        showDeliveryMenu(locationKey, locationData)
                    end,
                },
                {
                    name = 'cancel_delivery',
                    label = 'Cancel Active Delivery',
                    icon = 'fa-solid fa-times',
                    canInteract = function()
                        return isOnDelivery
                    end,
                    onSelect = function()
                        cancelActiveDelivery()
                    end,
                },
            },
        })
    end
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

-- Enter restaurant - setup targets
RegisterNetEvent('free-restaurants:client:enteredRestaurant', function(locationKey, locationData)
    if locationData.delivery then
        setupDeliveryTargets(locationKey, locationData)
    end
end)

-- Exit restaurant - cleanup
RegisterNetEvent('free-restaurants:client:exitedRestaurant', function(locationKey)
    -- Don't cancel delivery when leaving (they need to deliver!)
end)

-- Player dropped/logged out
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    clearDeliveryWaypoint()
end)

-- Command to check active delivery
RegisterCommand('mydelivery', function()
    if activeDelivery then
        local dest = activeDelivery.destination
        lib.notify({
            title = 'Active Delivery',
            description = ('To: %s - Status: %s'):format(dest.label, activeDelivery.status),
            type = 'inform',
        })
        
        if activeDelivery.status == 'picked_up' then
            setDeliveryWaypoint(dest.coords, dest.label)
        end
    else
        lib.notify({
            title = 'No Active Delivery',
            type = 'inform',
        })
    end
end, false)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('GetActiveDelivery', function() return activeDelivery end)
exports('IsOnDelivery', function() return isOnDelivery end)
exports('CancelDelivery', cancelActiveDelivery)
exports('ShowDeliveryMenu', showDeliveryMenu)

FreeRestaurants.Utils.Debug('client/delivery.lua loaded')
