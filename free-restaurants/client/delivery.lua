--[[
    free-restaurants Client Delivery System

    Handles:
    - Delivery mission UI
    - GPS waypoint management
    - Delivery pickup and dropoff interactions
    - Delivery vehicle management with deposit
    - Customer NPC spawning at destination
    - Time countdown notifications

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
local deliveryVehicle = nil
local deliveryVehicleDeposit = 0
local customerNpc = nil
local countdownThread = nil

-- Customer NPC models for delivery destinations
local customerModels = {
    'a_m_y_business_03',
    'a_f_y_business_01',
    'a_m_m_business_01',
    'a_f_m_business_02',
    'a_m_y_hipster_02',
    'a_f_y_hipster_01',
    's_m_m_doctor_01',
    's_f_y_scrubs_01',
}

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
-- CUSTOMER NPC MANAGEMENT
-- ============================================================================

--- Spawn customer NPC at delivery destination
---@param coords vector3
---@param heading number
---@return number|nil pedHandle
local function spawnCustomerNpc(coords, heading)
    -- Clean up existing NPC
    deleteCustomerNpc()

    -- Select random model
    local modelName = customerModels[math.random(#customerModels)]
    local modelHash = joaat(modelName)

    -- Request model
    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 50 do
        Wait(100)
        timeout = timeout + 1
    end

    if not HasModelLoaded(modelHash) then
        return nil
    end

    -- Create ped slightly in front of delivery coords
    local spawnCoords = coords + vector3(0.0, 0.0, 0.0)
    customerNpc = CreatePed(4, modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z - 1.0, heading, false, true)

    if customerNpc and DoesEntityExist(customerNpc) then
        -- Configure NPC
        SetEntityInvincible(customerNpc, true)
        SetBlockingOfNonTemporaryEvents(customerNpc, true)
        FreezeEntityPosition(customerNpc, true)
        SetPedCanRagdoll(customerNpc, false)

        -- Play waiting animation
        local animDict = 'amb@world_human_stand_impatient@male@no_sign@idle_a'
        RequestAnimDict(animDict)
        while not HasAnimDictLoaded(animDict) do
            Wait(10)
        end
        TaskPlayAnim(customerNpc, animDict, 'idle_a', 8.0, -8.0, -1, 1, 0, false, false, false)

        SetModelAsNoLongerNeeded(modelHash)
        return customerNpc
    end

    SetModelAsNoLongerNeeded(modelHash)
    return nil
end

--- Delete customer NPC
local function deleteCustomerNpc()
    if customerNpc and DoesEntityExist(customerNpc) then
        DeleteEntity(customerNpc)
        customerNpc = nil
    end
end

--- Play customer receive animation
local function playCustomerReceiveAnimation()
    if not customerNpc or not DoesEntityExist(customerNpc) then return end

    -- Stop current animation
    ClearPedTasks(customerNpc)

    -- Play happy receive animation
    local animDict = 'mp_common'
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Wait(10)
    end
    TaskPlayAnim(customerNpc, animDict, 'givetake2_a', 8.0, -8.0, 2000, 0, 0, false, false, false)
end

-- ============================================================================
-- DELIVERY VEHICLE MANAGEMENT
-- ============================================================================

--- Show vehicle choice dialog
---@param locationData table
---@return string|nil choice 'vehicle', 'own', or nil if cancelled
local function showVehicleChoiceDialog(locationData)
    local vehicleConfig = lib.callback.await('free-restaurants:server:getDeliveryVehicleConfig', false)
    local deposit = vehicleConfig and vehicleConfig.deposit or 500
    local model = vehicleConfig and vehicleConfig.model or 'faggio3'

    local alert = lib.alertDialog({
        header = 'Delivery Vehicle',
        content = ('Would you like to use a company delivery vehicle?\n\n**Deposit:** $%d (refunded on return)\n**Vehicle:** %s\n\nOr use your own vehicle.'):format(deposit, model:upper()),
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Use Company Vehicle',
            cancel = 'Use Own Vehicle',
        },
    })

    if alert == 'confirm' then
        return 'vehicle'
    elseif alert == 'cancel' then
        return 'own'
    end

    return nil
end

--- Spawn delivery vehicle
---@param locationData table
---@return boolean success
local function spawnDeliveryVehicle(locationData)
    if not locationData.delivery or not locationData.delivery.vehicleSpawn then
        lib.notify({
            title = 'Error',
            description = 'No vehicle spawn point configured',
            type = 'error',
        })
        return false
    end

    local spawn = locationData.delivery.vehicleSpawn

    -- Request vehicle from server (handles deposit)
    local result, error = lib.callback.await('free-restaurants:server:spawnDeliveryVehicle', false, spawn.coords, spawn.heading)

    if not result then
        lib.notify({
            title = 'Cannot Spawn Vehicle',
            description = error or 'Unknown error',
            type = 'error',
        })
        return false
    end

    local modelHash = joaat(result.model)

    -- Request model
    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 100 do
        Wait(100)
        timeout = timeout + 1
    end

    if not HasModelLoaded(modelHash) then
        lib.notify({
            title = 'Error',
            description = 'Failed to load vehicle model',
            type = 'error',
        })
        -- Refund deposit since we couldn't spawn
        lib.callback.await('free-restaurants:server:returnDeliveryVehicle', false)
        return false
    end

    -- Create vehicle
    deliveryVehicle = CreateVehicle(modelHash, spawn.coords.x, spawn.coords.y, spawn.coords.z, spawn.heading, true, false)

    if deliveryVehicle and DoesEntityExist(deliveryVehicle) then
        SetVehicleOnGroundProperly(deliveryVehicle)
        SetVehicleEngineOn(deliveryVehicle, true, true, false)
        SetVehicleDirtLevel(deliveryVehicle, 0.0)

        -- Set as mission entity so it doesn't despawn
        SetEntityAsMissionEntity(deliveryVehicle, true, true)

        -- Store deposit amount
        deliveryVehicleDeposit = result.deposit

        -- Register with server
        local netId = NetworkGetNetworkIdFromEntity(deliveryVehicle)
        lib.callback.await('free-restaurants:server:registerDeliveryVehicle', false, netId, result.deposit)

        lib.notify({
            title = 'Vehicle Ready',
            description = ('$%d deposit taken - return vehicle to get it back'):format(result.deposit),
            type = 'success',
        })

        -- Warp player into vehicle
        TaskWarpPedIntoVehicle(cache.ped, deliveryVehicle, -1)

        SetModelAsNoLongerNeeded(modelHash)
        return true
    end

    SetModelAsNoLongerNeeded(modelHash)
    lib.callback.await('free-restaurants:server:returnDeliveryVehicle', false)
    return false
end

--- Return delivery vehicle and get deposit back
---@param locationData table
---@return boolean success
local function returnDeliveryVehicle(locationData)
    if not deliveryVehicle or not DoesEntityExist(deliveryVehicle) then
        deliveryVehicle = nil
        deliveryVehicleDeposit = 0
        return false
    end

    -- Check if player is near return point
    if locationData and locationData.delivery and locationData.delivery.returnPoint then
        local returnCoords = locationData.delivery.returnPoint.coords
        local playerCoords = GetEntityCoords(cache.ped)
        local distance = #(playerCoords - returnCoords)

        if distance > 50.0 then
            lib.notify({
                title = 'Too Far',
                description = 'Return the vehicle to the restaurant',
                type = 'warning',
            })
            return false
        end
    end

    -- Delete vehicle
    if IsPedInVehicle(cache.ped, deliveryVehicle, false) then
        TaskLeaveVehicle(cache.ped, deliveryVehicle, 0)
        Wait(1500)
    end

    DeleteEntity(deliveryVehicle)
    deliveryVehicle = nil

    -- Get deposit back
    local success, amount = lib.callback.await('free-restaurants:server:returnDeliveryVehicle', false)

    if success then
        lib.notify({
            title = 'Deposit Refunded',
            description = ('$%d returned'):format(amount),
            type = 'success',
        })
        deliveryVehicleDeposit = 0
        return true
    end

    return false
end

-- ============================================================================
-- TIME COUNTDOWN NOTIFICATIONS
-- ============================================================================

--- Start countdown notification thread
---@param timeLimit number Time limit in seconds
local function startCountdownNotifications(timeLimit)
    -- Stop existing thread
    stopCountdownNotifications()

    local startTime = GetGameTimer()
    local notified = {}

    countdownThread = CreateThread(function()
        while activeDelivery and activeDelivery.status == 'picked_up' do
            Wait(5000) -- Check every 5 seconds

            local elapsed = (GetGameTimer() - startTime) / 1000 -- Convert to seconds
            local remaining = timeLimit - elapsed

            -- Key notification intervals
            local intervals = {
                { time = 600, message = '10 minutes remaining', type = 'inform' },
                { time = 300, message = '5 minutes remaining', type = 'warning' },
                { time = 120, message = '2 minutes remaining!', type = 'warning' },
                { time = 60, message = '1 minute remaining!', type = 'error' },
                { time = 30, message = '30 seconds remaining!', type = 'error' },
            }

            for _, interval in ipairs(intervals) do
                if remaining <= interval.time and remaining > interval.time - 10 and not notified[interval.time] then
                    notified[interval.time] = true
                    lib.notify({
                        title = 'Delivery Time',
                        description = interval.message,
                        type = interval.type,
                        duration = 5000,
                    })

                    -- Play warning sound for urgent notifications
                    if interval.time <= 120 then
                        PlaySoundFrontend(-1, 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)
                    end
                end
            end

            -- Time expired
            if remaining <= 0 then
                lib.notify({
                    title = 'Time Expired!',
                    description = 'Delivery time limit exceeded - reduced tip',
                    type = 'error',
                    duration = 7000,
                })
                PlaySoundFrontend(-1, 'CHECKPOINT_MISSED', 'HUD_MINI_GAME_SOUNDSET', true)
                break
            end
        end
    end)
end

--- Stop countdown notification thread
local function stopCountdownNotifications()
    countdownThread = nil
end

-- ============================================================================
-- DELIVERY UI
-- ============================================================================

-- Forward declarations for mutually recursive functions
local showDeliveryMenu
local showDeliveryDetails
local requestNewDelivery
local acceptDelivery
local waitForOrderReady
local waitForPickup
local attemptPickup
local trackDeliveryProgress
local arriveAtDestination
local completeDelivery
local cancelActiveDelivery

--- Show available deliveries menu
---@param locationKey string
---@param locationData table
showDeliveryMenu = function(locationKey, locationData)
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
            -- timeRemaining is calculated server-side and passed with delivery data
            local timeLeft = delivery.timeRemaining or 600
            local timeStr = timeLeft > 60 and ('%dm'):format(math.floor(timeLeft / 60)) or ('%ds'):format(timeLeft)
            local distanceStr = delivery.distance and ('%.1f km'):format(delivery.distance / 1000) or 'Unknown'

            table.insert(options, {
                title = ('Delivery to %s'):format(dest.label or delivery.destinationKey),
                description = ('%d items - Expires: %s'):format(#delivery.items, timeStr),
                icon = 'location-dot',
                metadata = {
                    { label = 'Distance', value = distanceStr },
                    { label = 'Base Pay', value = FreeRestaurants.Utils.FormatMoney(delivery.deliveryFee) },
                    { label = 'Distance Bonus', value = FreeRestaurants.Utils.FormatMoney(delivery.distanceBonus or 0) },
                    { label = 'Est. Tip', value = FreeRestaurants.Utils.FormatMoney(delivery.estimatedTip) },
                    { label = 'Total', value = FreeRestaurants.Utils.FormatMoney(delivery.totalPayout) },
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
showDeliveryDetails = function(delivery, locationKey, locationData)
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
            icon = 'dollar-sign',
            disabled = true,
        },
        {
            title = ('Distance Bonus: %s'):format(FreeRestaurants.Utils.FormatMoney(delivery.distanceBonus or 0)),
            icon = 'road',
            disabled = true,
        },
        {
            title = ('Estimated Tip: %s'):format(FreeRestaurants.Utils.FormatMoney(delivery.estimatedTip)),
            icon = 'hand-holding-dollar',
            disabled = true,
        },
        {
            title = ('TOTAL PAYOUT: %s'):format(FreeRestaurants.Utils.FormatMoney(delivery.totalPayout)),
            icon = 'money-bill-wave',
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
requestNewDelivery = function(locationKey, locationData)
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
acceptDelivery = function(delivery, locationKey, locationData)
    local success, kdsOrderId = lib.callback.await('free-restaurants:server:acceptDelivery', false, delivery.id)

    if success then
        activeDelivery = delivery
        activeDelivery.status = 'accepted'
        activeDelivery.locationData = locationData
        activeDelivery.kdsOrderId = kdsOrderId
        isOnDelivery = true

        lib.notify({
            title = 'Delivery Accepted',
            description = 'Order sent to kitchen - wait for it to be prepared',
            type = 'success',
            duration = 5000,
        })

        -- Ask about vehicle choice while waiting
        local vehicleChoice = showVehicleChoiceDialog(locationData)

        if vehicleChoice == 'vehicle' then
            local spawned = spawnDeliveryVehicle(locationData)
            if not spawned then
                lib.notify({
                    title = 'Using Own Vehicle',
                    description = 'Company vehicle unavailable',
                    type = 'inform',
                })
            end
        end

        -- Start monitoring for order ready status
        CreateThread(function()
            waitForOrderReady(locationKey, locationData)
        end)
    else
        lib.notify({
            title = 'Accept Failed',
            description = 'Could not accept this delivery',
            type = 'error',
        })
    end
end

--- Wait for order to be ready for pickup
---@param locationKey string
---@param locationData table
waitForOrderReady = function(locationKey, locationData)
    local lastStatus = 'pending'
    lib.showTextUI('Waiting for kitchen to prepare order...', { icon = 'clock' })

    while activeDelivery and activeDelivery.status == 'accepted' do
        Wait(3000) -- Check every 3 seconds

        local ready, status = lib.callback.await('free-restaurants:server:isDeliveryReady', false, activeDelivery.id)

        -- Update UI based on status
        if status ~= lastStatus then
            lastStatus = status
            if status == 'cooking' then
                lib.showTextUI('Kitchen is preparing your order...', { icon = 'fire' })
            elseif status == 'ready' then
                lib.hideTextUI()
                lib.notify({
                    title = 'Order Ready!',
                    description = 'Pick up items from the packaging station',
                    type = 'success',
                    duration = 5000,
                })
                PlaySoundFrontend(-1, 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)

                -- Set GPS waypoint to delivery destination now
                local dest = activeDelivery.destination
                setDeliveryWaypoint(dest.coords, dest.label)

                -- Now wait for pickup
                waitForPickup(locationKey, locationData)
                return
            end
        end
    end

    lib.hideTextUI()
end

--- Wait for player to pick up items from pickup area
---@param locationKey string
---@param locationData table
waitForPickup = function(locationKey, locationData)
    lib.showTextUI('[E] Pick up delivery items from packaging station', { icon = 'box' })

    while activeDelivery and activeDelivery.status == 'accepted' do
        Wait(100)

        if IsControlJustPressed(0, 38) then -- E key
            attemptPickup()
        end
    end

    lib.hideTextUI()
end

--- Attempt to pick up delivery items from pickup stash
attemptPickup = function()
    if not activeDelivery then return end

    lib.showTextUI('Picking up items...', { icon = 'spinner' })

    local success, error = lib.callback.await('free-restaurants:server:pickupDelivery', false, activeDelivery.id)

    lib.hideTextUI()

    if success then
        activeDelivery.status = 'picked_up'

        lib.notify({
            title = 'Items Collected',
            description = 'Head to the delivery location - follow your GPS',
            type = 'success',
        })

        -- Start countdown notifications
        local timeLimit = activeDelivery.timeLimit or 1200 -- Default 20 minutes
        startCountdownNotifications(timeLimit)

        -- Spawn customer NPC at destination
        local dest = activeDelivery.destination
        CreateThread(function()
            spawnCustomerNpc(dest.coords, dest.heading or 0.0)
        end)

        -- Start delivery tracking
        CreateThread(function()
            trackDeliveryProgress()
        end)
    else
        lib.notify({
            title = 'Pickup Failed',
            description = error or 'Items not ready for pickup',
            type = 'error',
        })
    end
end

--- Track delivery progress and arrival
trackDeliveryProgress = function()
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
        if distance < 5.0 then
            lib.hideTextUI()
            arriveAtDestination()
            break
        end
    end
end

--- Handle arrival at destination
arriveAtDestination = function()
    if not activeDelivery then return end

    -- Stop countdown
    stopCountdownNotifications()

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
            if distance > 15.0 then
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
completeDelivery = function()
    if not activeDelivery then return end

    -- Play customer receive animation first
    playCustomerReceiveAnimation()

    -- Progress bar for delivery animation
    local success = lib.progressCircle({
        duration = 3000,
        label = 'Handing over order...',
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
        stopCountdownNotifications()

        -- Delete customer NPC with delay for natural feel
        CreateThread(function()
            Wait(2000)
            deleteCustomerNpc()
        end)

        if completed then
            -- Play success sound
            PlaySoundFrontend(-1, 'PICK_UP_COLLECTIBLE', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)

            lib.notify({
                title = 'Delivery Complete!',
                description = ('You earned %s'):format(FreeRestaurants.Utils.FormatMoney(earnings)),
                type = 'success',
                duration = 5000,
            })

            -- Check if we need to return a company vehicle
            local locationData = activeDelivery.locationData
            activeDelivery = nil
            isOnDelivery = false

            if deliveryVehicle and DoesEntityExist(deliveryVehicle) then
                lib.notify({
                    title = 'Return Vehicle',
                    description = 'Return the delivery vehicle to get your deposit back',
                    type = 'inform',
                    duration = 7000,
                })

                -- Set waypoint back to restaurant
                if locationData and locationData.delivery and locationData.delivery.returnPoint then
                    setDeliveryWaypoint(locationData.delivery.returnPoint.coords, 'Return Vehicle')
                end
            end
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
cancelActiveDelivery = function()
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
            stopCountdownNotifications()
            deleteCustomerNpc()

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
                {
                    name = 'return_vehicle',
                    label = 'Return Delivery Vehicle',
                    icon = 'fa-solid fa-car',
                    canInteract = function()
                        return deliveryVehicle and DoesEntityExist(deliveryVehicle) and not isOnDelivery
                    end,
                    onSelect = function()
                        returnDeliveryVehicle(locationData)
                    end,
                },
            },
        })
    end

    -- Vehicle return point (if different from board)
    if locationData.delivery and locationData.delivery.returnPoint then
        local returnPoint = locationData.delivery.returnPoint

        exports.ox_target:addSphereZone({
            name = ('%s_vehicle_return'):format(locationKey),
            coords = returnPoint.coords,
            radius = 5.0,
            debug = Config.Debug,
            options = {
                {
                    name = 'return_vehicle_point',
                    label = 'Return Delivery Vehicle',
                    icon = 'fa-solid fa-car',
                    canInteract = function()
                        return deliveryVehicle and DoesEntityExist(deliveryVehicle)
                    end,
                    onSelect = function()
                        returnDeliveryVehicle(locationData)
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

-- New delivery available notification
RegisterNetEvent('free-restaurants:client:newDeliveryAvailable', function(data)
    -- Play notification sound
    PlaySoundFrontend(-1, 'PHONE_GENERIC_RECEIVE_TEXT', 'HUD_MINI_GAME_SOUNDSET', true)

    local distanceBonus = data.distanceBonus or 0
    local description = ('To: %s | %d items | $%d'):format(data.destination, data.itemCount, data.payout)
    if distanceBonus > 0 then
        description = description .. (' (+$%d distance)'):format(distanceBonus)
    end

    lib.notify({
        title = 'New Delivery Available!',
        description = description,
        type = 'inform',
        icon = 'truck',
        duration = 8000,
    })
end)

-- Player dropped/logged out
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    clearDeliveryWaypoint()
    deleteCustomerNpc()
    stopCountdownNotifications()

    if deliveryVehicle and DoesEntityExist(deliveryVehicle) then
        DeleteEntity(deliveryVehicle)
    end
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

-- Command to return vehicle
RegisterCommand('returndeliveryvehicle', function()
    if deliveryVehicle and DoesEntityExist(deliveryVehicle) then
        if isOnDelivery then
            lib.notify({
                title = 'Cannot Return',
                description = 'Complete or cancel your delivery first',
                type = 'warning',
            })
        else
            -- Find nearest restaurant location for return
            local playerCoords = GetEntityCoords(cache.ped)
            -- Simple return without location check for command
            if IsPedInVehicle(cache.ped, deliveryVehicle, false) then
                TaskLeaveVehicle(cache.ped, deliveryVehicle, 0)
                Wait(1500)
            end
            DeleteEntity(deliveryVehicle)
            deliveryVehicle = nil

            local success, amount = lib.callback.await('free-restaurants:server:returnDeliveryVehicle', false)
            if success then
                lib.notify({
                    title = 'Vehicle Returned',
                    description = ('$%d deposit refunded'):format(amount),
                    type = 'success',
                })
            end
        end
    else
        lib.notify({
            title = 'No Vehicle',
            description = 'You don\'t have a delivery vehicle',
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
exports('HasDeliveryVehicle', function() return deliveryVehicle and DoesEntityExist(deliveryVehicle) end)

FreeRestaurants.Utils.Debug('client/delivery.lua loaded')
