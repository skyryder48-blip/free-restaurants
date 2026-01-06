--[[
    free-restaurants Client NPC Customer System
    
    Handles:
    - NPC customer ped spawning
    - Customer animations and behavior
    - Waiting/receiving animations
    - Customer despawning
    
    DEPENDENCIES:
    - client/main.lua
    - ox_lib
]]

-- ============================================================================
-- LOCAL STATE
-- ============================================================================

-- Active NPC customers: [orderId] = { ped, blip, ... }
local activeNPCs = {}

-- Animation dictionaries
local ANIM_DICTS = {
    waiting = 'amb@world_human_hang_out_street@female_arms_crossed@idle_a',
    happy = 'mp_player_int_uppergrab',
    frustrated = 'mp_player_int_upperfinger',
    eating = 'mp_player_inteat@pnq',
}

-- ============================================================================
-- PED MANAGEMENT
-- ============================================================================

--- Spawn NPC customer ped
---@param npcData table NPC data from server
---@param locationData table Restaurant location
---@return number|nil pedHandle
local function spawnCustomerPed(npcData, locationData)
    local model = joaat(npcData.model)
    
    -- Request model
    if not lib.requestModel(model, 5000) then
        FreeRestaurants.Utils.Error('Failed to load NPC model: ' .. npcData.model)
        return nil
    end
    
    -- Get spawn position (customer area)
    local spawnPos = locationData.customerArea or locationData.coords
    if type(spawnPos) == 'table' and spawnPos.x then
        spawnPos = vec3(spawnPos.x, spawnPos.y, spawnPos.z)
    end
    
    -- Add some randomness to position
    local offsetX = math.random(-20, 20) / 10
    local offsetY = math.random(-20, 20) / 10
    spawnPos = spawnPos + vec3(offsetX, offsetY, 0)
    
    -- Create ped
    local ped = CreatePed(4, model, spawnPos.x, spawnPos.y, spawnPos.z, math.random(0, 360), true, true)
    
    SetModelAsNoLongerNeeded(model)
    
    if not DoesEntityExist(ped) then
        return nil
    end
    
    -- Configure ped
    SetPedFleeAttributes(ped, 0, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdollFromPlayerImpact(ped, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, false)
    
    -- Play waiting animation
    playWaitingAnimation(ped)
    
    return ped
end

--- Play waiting animation
---@param ped number
local function playWaitingAnimation(ped)
    if not DoesEntityExist(ped) then return end
    
    local dict = ANIM_DICTS.waiting
    lib.requestAnimDict(dict)
    
    TaskPlayAnim(ped, dict, 'idle_a', 8.0, -8.0, -1, 1, 0, false, false, false)
end

--- Play reaction animation
---@param ped number
---@param reaction string 'happy', 'frustrated'
local function playReactionAnimation(ped, reaction)
    if not DoesEntityExist(ped) then return end
    
    local dict = ANIM_DICTS[reaction]
    if not dict then return end
    
    lib.requestAnimDict(dict)
    
    local clip = reaction == 'happy' and 'idle_a' or 'idle_a'
    TaskPlayAnim(ped, dict, clip, 8.0, -8.0, 2000, 0, 0, false, false, false)
end

--- Make NPC walk away and despawn
---@param ped number
local function despawnCustomer(ped)
    if not DoesEntityExist(ped) then return end
    
    -- Clear current task
    ClearPedTasks(ped)
    
    -- Walk away
    local pedCoords = GetEntityCoords(ped)
    local walkTarget = pedCoords + vec3(
        math.random(-20, 20),
        math.random(-20, 20),
        0
    )
    
    TaskGoStraightToCoord(ped, walkTarget.x, walkTarget.y, walkTarget.z, 1.0, 5000, 0.0, 0.0)
    
    -- Delete after walking
    SetTimeout(5000, function()
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end)
end

-- ============================================================================
-- NPC CUSTOMER MANAGEMENT
-- ============================================================================

--- Handle new NPC order
---@param orderData table
local function handleNPCOrderCreated(orderData)
    -- Get location data
    local locationKey, locationData = FreeRestaurants.Client.GetCurrentLocation()
    if not locationData then
        -- Try to find location from order
        for restType, locations in pairs(Config.Locations) do
            if type(locations) == 'table' then
                for locId, locData in pairs(locations) do
                    local key = ('%s_%s'):format(restType, locId)
                    if key == orderData.locationKey then
                        locationData = locData
                        break
                    end
                end
            end
            if locationData then break end
        end
    end
    
    if not locationData then return end
    
    -- Spawn the customer
    local ped = spawnCustomerPed(orderData.npc, locationData)
    
    if ped then
        activeNPCs[orderData.orderId] = {
            ped = ped,
            npc = orderData.npc,
            orderData = orderData,
            createdAt = GetGameTimer(),
        }
        
        -- Create overhead marker
        CreateThread(function()
            local npcData = activeNPCs[orderData.orderId]
            while npcData and DoesEntityExist(npcData.ped) do
                Wait(0)
                
                local pedCoords = GetEntityCoords(npcData.ped)
                
                -- Draw marker above head
                DrawMarker(
                    25, -- Type: Question mark
                    pedCoords.x, pedCoords.y, pedCoords.z + 1.2,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    0.3, 0.3, 0.3,
                    255, 200, 0, 150,
                    true, false, 2, false, nil, nil, false
                )
                
                -- Check if still active
                npcData = activeNPCs[orderData.orderId]
            end
        end)
        
        FreeRestaurants.Utils.Debug(('Spawned NPC customer: %s'):format(orderData.npc.fullName))
    end
end

--- Handle NPC order completed
---@param data table
local function handleNPCOrderCompleted(data)
    local npcData = activeNPCs[data.orderId]
    if not npcData then return end
    
    -- Play reaction based on satisfaction
    if data.satisfaction == 'happy' then
        playReactionAnimation(npcData.ped, 'happy')
    elseif data.satisfaction == 'frustrated' then
        playReactionAnimation(npcData.ped, 'frustrated')
    end
    
    -- Wait then despawn
    SetTimeout(3000, function()
        if activeNPCs[data.orderId] then
            despawnCustomer(npcData.ped)
            activeNPCs[data.orderId] = nil
        end
    end)
    
    -- Show tip notification
    if data.tip and data.tip > 0 then
        lib.notify({
            title = 'Tip Received',
            description = ('%s left a %s tip!'):format(data.npc.fullName, FreeRestaurants.Utils.FormatMoney(data.tip)),
            type = 'success',
            icon = 'coins',
        })
    end
end

--- Handle NPC order cancelled/expired
---@param orderId string
local function handleNPCOrderExpired(orderId)
    local npcData = activeNPCs[orderId]
    if not npcData then return end
    
    -- Play frustrated animation
    playReactionAnimation(npcData.ped, 'frustrated')
    
    -- Despawn after animation
    SetTimeout(2000, function()
        if activeNPCs[orderId] then
            despawnCustomer(npcData.ped)
            activeNPCs[orderId] = nil
        end
    end)
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

RegisterNetEvent('free-restaurants:client:npcOrderCreated', function(orderData)
    handleNPCOrderCreated(orderData)
end)

RegisterNetEvent('free-restaurants:client:npcOrderCompleted', function(data)
    handleNPCOrderCompleted(data)
end)

RegisterNetEvent('free-restaurants:client:npcOrderExpired', function(orderId)
    handleNPCOrderExpired(orderId)
end)

-- Clean up on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    for orderId, npcData in pairs(activeNPCs) do
        if DoesEntityExist(npcData.ped) then
            DeleteEntity(npcData.ped)
        end
    end
    activeNPCs = {}
end)

-- Clean up when leaving restaurant area
RegisterNetEvent('free-restaurants:client:exitedRestaurant', function(locationKey)
    -- Despawn all NPCs for this location
    for orderId, npcData in pairs(activeNPCs) do
        if npcData.orderData.locationKey == locationKey then
            if DoesEntityExist(npcData.ped) then
                DeleteEntity(npcData.ped)
            end
            activeNPCs[orderId] = nil
        end
    end
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('GetActiveNPCs', function() return activeNPCs end)

FreeRestaurants.Utils.Debug('client/npc-customers.lua loaded')
