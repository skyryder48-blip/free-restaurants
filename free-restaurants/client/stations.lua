--[[
    free-restaurants Client Station System
    
    Handles:
    - Multi-player slot management (concurrent usage of station slots)
    - ox_target zone creation for all stations per location
    - Station state tracking with state bags for synchronization
    - Prop spawning for food items during cooking
    - Particle effects (steam, smoke, sizzle)
    - Escalating fire system (smoke → small fire → large fire → spreading)
    - Simple slot HUD for current station
    
    DEPENDENCIES:
    - client/main.lua (state management, location detection)
    - ox_lib (zones, state bags, callbacks)
    - ox_target (interaction system)
    
    STATE SYNCHRONIZATION:
    - Uses GlobalState for cross-client station data
    - Server-authoritative slot claiming prevents race conditions
    - Local cache for performance optimization
]]

-- ============================================================================
-- LOCAL STATE
-- ============================================================================

local stationTargets = {}           -- Registered ox_target zones
local stationSlots = {}             -- Local cache of slot states per station
local activeParticles = {}          -- Active particle effect handles
local activeFires = {}              -- Active fire handles
local spawnedProps = {}             -- Spawned cooking props (entity handles)
local currentStation = nil          -- Currently interacting station key
local currentSlot = nil             -- Currently claimed slot number
local hudVisible = false            -- HUD visibility state

-- Prop model cache to avoid repeated streaming requests
local modelCache = {}

-- Pending pickup items at stations (tracked client-side for timers)
-- Key format: "locationKey_stationKey_slotIndex"
local pendingPickups = {}

-- Forward declaration for pickup functions
local startPickupTimer
local handleItemBurnOrSpill
local pickupItemFromStation

-- Forward declarations for functions used before definition
local hideStationHUD
local updateStationHUD
local getAvailableRecipes
local canCraftRecipe
local startCookingAtSlot
local onStationSlotSelected
local deleteFoodProp
local stopParticleEffect
local cleanupSlot

-- ============================================================================
-- FOOD PROP DEFINITIONS
-- ============================================================================

--[[
    Food props available in GTA5 for cooking visuals.
    Format: [recipeId or ingredientName] = { raw = model, cooked = model, burnt = model }
    
    PLACEHOLDER SYSTEM:
    - If a specific prop doesn't exist, use 'PLACEHOLDER' as the model
    - Placeholders use a generic food prop with color tinting
]]

local FoodProps = {
    -- Burgers and Meat
    ['patty'] = {
        raw = 'prop_cs_steak',
        cooking = 'prop_cs_steak',
        cooked = 'prop_cs_burger_01',
        burnt = 'prop_cs_burger_01',  -- Will add smoke/char effect
    },
    ['burger'] = {
        raw = 'prop_cs_burger_01',
        cooking = 'prop_cs_burger_01',
        cooked = 'prop_food_burg1',
        burnt = 'prop_food_burg1',
    },
    ['hotdog'] = {
        raw = 'prop_cs_hotdog_01',
        cooking = 'prop_cs_hotdog_01',
        cooked = 'prop_cs_hotdog_02',
        burnt = 'prop_cs_hotdog_02',
    },
    ['steak'] = {
        raw = 'prop_cs_steak',
        cooking = 'prop_cs_steak',
        cooked = 'prop_cs_steak',
        burnt = 'prop_cs_steak',
    },
    
    -- Fried Items
    ['fries'] = {
        raw = 'PLACEHOLDER',
        cooking = 'PLACEHOLDER',
        cooked = 'prop_food_chips',
        burnt = 'prop_food_chips',
    },
    ['chicken_nuggets'] = {
        raw = 'PLACEHOLDER',
        cooking = 'PLACEHOLDER',
        cooked = 'prop_food_cb_nugets',
        burnt = 'prop_food_cb_nugets',
    },
    
    -- Pizza
    ['pizza'] = {
        raw = 'prop_pizza_box_01',
        cooking = 'prop_pizza_box_01',
        cooked = 'prop_pizza_box_02',
        burnt = 'prop_pizza_box_02',
    },
    
    -- Drinks
    ['soda'] = {
        raw = 'prop_food_bs_soda_01',
        cooked = 'prop_food_bs_soda_01',
    },
    ['coffee'] = {
        raw = 'prop_food_bs_coffee',
        cooked = 'prop_food_bs_coffee',
    },
    ['milkshake'] = {
        raw = 'prop_plastic_cup_02',
        cooked = 'prop_plastic_cup_02',
    },
    
    -- Generic placeholder
    ['PLACEHOLDER'] = {
        raw = 'prop_food_bs_tray_02',
        cooking = 'prop_food_bs_tray_02',
        cooked = 'prop_food_bs_tray_02',
        burnt = 'prop_food_bs_tray_02',
    },
}

-- ============================================================================
-- PARTICLE EFFECT DEFINITIONS
-- ============================================================================

local ParticleEffects = {
    -- Cooking stages
    steam_light = {
        dict = 'core',
        name = 'ent_amb_steam',
        scale = 0.3,
        offset = vec3(0.0, 0.0, 0.2),
    },
    steam_heavy = {
        dict = 'core',
        name = 'ent_amb_steam',
        scale = 0.6,
        offset = vec3(0.0, 0.0, 0.3),
    },
    sizzle = {
        dict = 'core',
        name = 'ent_amb_smoke_foundry',
        scale = 0.2,
        offset = vec3(0.0, 0.0, 0.1),
    },
    smoke_cooking = {
        dict = 'core',
        name = 'ent_amb_smoke_foundry',
        scale = 0.4,
        offset = vec3(0.0, 0.0, 0.3),
    },
    
    -- Warning/Burning stages
    smoke_warning = {
        dict = 'core',
        name = 'ent_amb_smoke_factory_mid',
        scale = 0.6,
        offset = vec3(0.0, 0.0, 0.4),
    },
    smoke_burning = {
        dict = 'core',
        name = 'ent_amb_smoke_factory_mid',
        scale = 1.0,
        offset = vec3(0.0, 0.0, 0.5),
    },
    flame_small = {
        dict = 'core',
        name = 'ent_amb_torch_fire',
        scale = 0.5,
        offset = vec3(0.0, 0.0, 0.3),
    },
    flame_medium = {
        dict = 'core',
        name = 'ent_amb_torch_fire',
        scale = 1.0,
        offset = vec3(0.0, 0.0, 0.4),
    },
    flame_large = {
        dict = 'core',
        name = 'ent_amb_barrel_fire',
        scale = 1.5,
        offset = vec3(0.0, 0.0, 0.5),
    },
    
    -- Station-specific
    fryer_bubbles = {
        dict = 'core',
        name = 'ent_amb_steam',
        scale = 0.4,
        offset = vec3(0.0, 0.0, 0.0),
    },
    oven_heat = {
        dict = 'core',
        name = 'ent_amb_steam',
        scale = 0.5,
        offset = vec3(0.0, 0.0, 0.2),
    },
}

-- ============================================================================
-- FIRE ESCALATION SYSTEM
-- ============================================================================

--[[
    Fire Stages:
    1. SMOKE_WARNING - Visual smoke, no fire yet
    2. SMALL_FIRE - Contained fire at station
    3. MEDIUM_FIRE - Growing fire
    4. LARGE_FIRE - Major fire, starts spreading
    5. SPREADING - Fire propagates through environment
    
    Integration with external firefighter scripts via events.
]]

local FireStages = {
    SMOKE_WARNING = 1,
    SMALL_FIRE = 2,
    MEDIUM_FIRE = 3,
    LARGE_FIRE = 4,
    SPREADING = 5,
}

local fireEscalationTimers = {}     -- Timers for fire progression
local fireState = {}                -- Current fire state per station

-- Fire configuration (times in milliseconds)
local FireConfig = {
    escalationTimes = {
        [FireStages.SMOKE_WARNING] = 15000,     -- 15s of smoke before small fire
        [FireStages.SMALL_FIRE] = 20000,        -- 20s before medium fire
        [FireStages.MEDIUM_FIRE] = 15000,       -- 15s before large fire
        [FireStages.LARGE_FIRE] = 10000,        -- 10s before spreading
    },
    spreadInterval = 5000,                      -- 5s between spread attempts
    spreadRadius = 3.0,                         -- Initial spread radius
    maxSpreadRadius = 15.0,                     -- Maximum spread distance
    spreadRadiusGrowth = 2.0,                   -- How much radius grows each spread
}

-- ============================================================================
-- MODEL & ASSET LOADING
-- ============================================================================

--- Request and cache a model
---@param model string|number Model name or hash
---@param timeout? number Timeout in ms (default 5000)
---@return boolean success
local function requestModel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    
    if modelCache[hash] then
        return true
    end
    
    if not IsModelValid(hash) then
        FreeRestaurants.Utils.Debug(('Invalid model: %s'):format(model))
        return false
    end
    
    lib.requestModel(hash, 5000)
    modelCache[hash] = true
    return true
end

--- Request particle effect dictionary
---@param dict string Dictionary name
---@return boolean success
local function requestParticleFx(dict)
    if HasNamedPtfxAssetLoaded(dict) then
        return true
    end
    
    RequestNamedPtfxAsset(dict)
    local timeout = 5000
    local startTime = GetGameTimer()
    
    while not HasNamedPtfxAssetLoaded(dict) do
        Wait(10)
        if GetGameTimer() - startTime > timeout then
            FreeRestaurants.Utils.Error(('Failed to load PTFX dict: %s'):format(dict))
            return false
        end
    end
    
    return true
end

-- ============================================================================
-- SLOT STATE MANAGEMENT
-- ============================================================================

---@class SlotState
---@field occupied boolean Whether slot is in use
---@field playerId number|nil Server ID of player using slot
---@field playerName string|nil Name of player using slot
---@field status string Current status: 'empty', 'preparing', 'cooking', 'ready', 'warning', 'burnt'
---@field recipeId string|nil Recipe being cooked
---@field startTime number|nil When cooking started
---@field cookTime number|nil Total cook time
---@field progress number|nil Current progress (0-100)
---@field quality number|nil Current quality (0-100)

--- Get the state bag key for a station
---@param locationKey string
---@param stationKey string
---@return string
local function getStationStateKey(locationKey, stationKey)
    return ('restaurant:%s:%s'):format(locationKey, stationKey)
end

--- Get slot state from cache or global state
---@param locationKey string
---@param stationKey string
---@param slotIndex number
---@return SlotState
local function getSlotState(locationKey, stationKey, slotIndex)
    local cacheKey = ('%s_%s'):format(locationKey, stationKey)
    
    if not stationSlots[cacheKey] then
        stationSlots[cacheKey] = {}
    end
    
    if not stationSlots[cacheKey][slotIndex] then
        stationSlots[cacheKey][slotIndex] = {
            occupied = false,
            playerId = nil,
            playerName = nil,
            status = 'empty',
            recipeId = nil,
            startTime = nil,
            cookTime = nil,
            progress = 0,
            quality = 100,
        }
    end
    
    return stationSlots[cacheKey][slotIndex]
end

--- Update local slot cache from state bag
---@param locationKey string
---@param stationKey string
---@param slotData table
local function updateLocalSlotCache(locationKey, stationKey, slotData)
    local cacheKey = ('%s_%s'):format(locationKey, stationKey)
    stationSlots[cacheKey] = slotData
    
    -- Update HUD if this is our current station
    if currentStation == cacheKey then
        updateStationHUD(stationKey, slotData)
    end
end

--- Claim a slot for the local player
---@param locationKey string
---@param stationKey string
---@param slotIndex number
---@param recipeId string
---@return boolean success
local function claimSlot(locationKey, stationKey, slotIndex, recipeId)
    local success = lib.callback.await('free-restaurants:server:claimSlot', false, {
        locationKey = locationKey,
        stationKey = stationKey,
        slotIndex = slotIndex,
        recipeId = recipeId,
    })
    
    if success then
        currentStation = ('%s_%s'):format(locationKey, stationKey)
        currentSlot = slotIndex
        FreeRestaurants.Client.UpdatePlayerState('activeStation', currentStation)
    end
    
    return success
end

--- Release a slot
---@param locationKey string
---@param stationKey string
---@param slotIndex number
---@param status? string Final status ('completed', 'cancelled', 'burnt')
---@return boolean success
local function releaseSlot(locationKey, stationKey, slotIndex, status)
    local success = lib.callback.await('free-restaurants:server:releaseSlot', false, {
        locationKey = locationKey,
        stationKey = stationKey,
        slotIndex = slotIndex,
        status = status or 'completed',
    })
    
    if success then
        -- Clean up local state
        local cacheKey = ('%s_%s'):format(locationKey, stationKey)
        if currentStation == cacheKey and currentSlot == slotIndex then
            currentStation = nil
            currentSlot = nil
            FreeRestaurants.Client.UpdatePlayerState('activeStation', nil)
        end
        
        -- Clean up props and effects for this slot
        cleanupSlot(cacheKey, slotIndex)
    end
    
    return success
end

-- ============================================================================
-- PROP MANAGEMENT
-- ============================================================================

--- Get prop key for tracking
---@param stationKey string
---@param slotIndex number
---@return string
local function getPropKey(stationKey, slotIndex)
    return ('%s_slot%d'):format(stationKey, slotIndex)
end

--- Spawn a food prop at a station slot
---@param stationKey string
---@param slotIndex number
---@param propType string Key from FoodProps table
---@param state string 'raw', 'cooking', 'cooked', 'burnt'
---@param coords vector3
---@param heading number
---@return number|nil entityHandle
local function spawnFoodProp(stationKey, slotIndex, propType, state, coords, heading)
    local propKey = getPropKey(stationKey, slotIndex)
    
    -- Clean up existing prop at this slot
    if spawnedProps[propKey] then
        deleteFoodProp(stationKey, slotIndex)
    end
    
    -- Get prop definition
    local propDef = FoodProps[propType] or FoodProps['PLACEHOLDER']
    local modelName = propDef[state] or propDef.raw
    
    if modelName == 'PLACEHOLDER' then
        modelName = FoodProps['PLACEHOLDER'][state] or FoodProps['PLACEHOLDER'].raw
    end
    
    -- Request and spawn model
    if not requestModel(modelName) then
        FreeRestaurants.Utils.Error(('Failed to load prop model: %s'):format(modelName))
        return nil
    end
    
    local hash = joaat(modelName)
    local entity = CreateObjectNoOffset(hash, coords.x, coords.y, coords.z, false, false, true)
    
    if not entity or entity == 0 then
        FreeRestaurants.Utils.Error('Failed to create prop entity')
        return nil
    end
    
    -- Configure prop
    SetEntityHeading(entity, heading)
    PlaceObjectOnGroundProperly(entity)
    FreezeEntityPosition(entity, true)
    SetEntityCollision(entity, false, false)
    
    -- Apply visual effects based on state
    if state == 'burnt' then
        -- Darken the prop to indicate burnt
        SetEntityAlpha(entity, 200, false)
    end
    
    -- Store reference
    spawnedProps[propKey] = {
        entity = entity,
        model = modelName,
        state = state,
        propType = propType,
    }
    
    SetModelAsNoLongerNeeded(hash)
    
    return entity
end

--- Delete a food prop
---@param stationKey string
---@param slotIndex number
deleteFoodProp = function(stationKey, slotIndex)
    local propKey = getPropKey(stationKey, slotIndex)
    local propData = spawnedProps[propKey]
    
    if propData and propData.entity and DoesEntityExist(propData.entity) then
        DeleteEntity(propData.entity)
    end
    
    spawnedProps[propKey] = nil
end

--- Update prop state (swap models for cooking progression)
---@param stationKey string
---@param slotIndex number
---@param newState string 'raw', 'cooking', 'cooked', 'burnt'
local function updatePropState(stationKey, slotIndex, newState)
    local propKey = getPropKey(stationKey, slotIndex)
    local propData = spawnedProps[propKey]
    
    if not propData then return end
    
    -- Get current position before deletion
    local coords = GetEntityCoords(propData.entity)
    local heading = GetEntityHeading(propData.entity)
    
    -- Respawn with new state
    spawnFoodProp(stationKey, slotIndex, propData.propType, newState, coords, heading)
end

-- ============================================================================
-- PARTICLE EFFECT MANAGEMENT
-- ============================================================================

--- Get particle key for tracking
---@param stationKey string
---@param slotIndex number
---@param effectType string
---@return string
local function getParticleKey(stationKey, slotIndex, effectType)
    return ('%s_slot%d_%s'):format(stationKey, slotIndex, effectType)
end

--- Start a particle effect at a location
---@param stationKey string
---@param slotIndex number
---@param effectType string Key from ParticleEffects table
---@param coords vector3
---@return number|nil handle
local function startParticleEffect(stationKey, slotIndex, effectType, coords)
    local particleKey = getParticleKey(stationKey, slotIndex, effectType)
    
    -- Stop existing effect of same type
    stopParticleEffect(stationKey, slotIndex, effectType)
    
    local effect = ParticleEffects[effectType]
    if not effect then
        FreeRestaurants.Utils.Debug(('Unknown particle effect: %s'):format(effectType))
        return nil
    end
    
    -- Load particle dictionary
    if not requestParticleFx(effect.dict) then
        return nil
    end
    
    -- Calculate position with offset
    local effectCoords = coords + effect.offset
    
    -- Start looped particle effect
    UseParticleFxAssetNextCall(effect.dict)
    local handle = StartParticleFxLoopedAtCoord(
        effect.name,
        effectCoords.x, effectCoords.y, effectCoords.z,
        0.0, 0.0, 0.0,
        effect.scale,
        false, false, false, false
    )
    
    if handle and handle > 0 then
        activeParticles[particleKey] = {
            handle = handle,
            effect = effectType,
            coords = effectCoords,
        }
        return handle
    end
    
    return nil
end

--- Stop a specific particle effect
---@param stationKey string
---@param slotIndex number
---@param effectType string
stopParticleEffect = function(stationKey, slotIndex, effectType)
    local particleKey = getParticleKey(stationKey, slotIndex, effectType)
    local particleData = activeParticles[particleKey]
    
    if particleData and particleData.handle then
        StopParticleFxLooped(particleData.handle, true)  -- true = fade out
    end
    
    activeParticles[particleKey] = nil
end

--- Stop all particle effects for a slot
---@param stationKey string
---@param slotIndex number
local function stopAllSlotParticles(stationKey, slotIndex)
    local prefix = ('%s_slot%d_'):format(stationKey, slotIndex)
    
    for key, particleData in pairs(activeParticles) do
        if key:sub(1, #prefix) == prefix then
            if particleData.handle then
                StopParticleFxLooped(particleData.handle, true)
            end
            activeParticles[key] = nil
        end
    end
end

--- Update particle effects based on cooking state
---@param stationKey string
---@param slotIndex number
---@param status string
---@param stationType string
---@param coords vector3
local function updateCookingParticles(stationKey, slotIndex, status, stationType, coords)
    -- Stop all current particles for this slot
    stopAllSlotParticles(stationKey, slotIndex)
    
    -- Start appropriate particles based on status
    if status == 'cooking' then
        if stationType == 'grill' or stationType == 'stovetop' then
            startParticleEffect(stationKey, slotIndex, 'sizzle', coords)
            startParticleEffect(stationKey, slotIndex, 'steam_light', coords)
        elseif stationType == 'fryer' then
            startParticleEffect(stationKey, slotIndex, 'fryer_bubbles', coords)
            startParticleEffect(stationKey, slotIndex, 'steam_heavy', coords)
        elseif stationType == 'oven' or stationType == 'pizza_oven' then
            startParticleEffect(stationKey, slotIndex, 'oven_heat', coords)
        else
            startParticleEffect(stationKey, slotIndex, 'steam_light', coords)
        end
        
    elseif status == 'warning' then
        startParticleEffect(stationKey, slotIndex, 'smoke_warning', coords)
        
    elseif status == 'burnt' then
        startParticleEffect(stationKey, slotIndex, 'smoke_burning', coords)
    end
end

-- ============================================================================
-- FIRE SYSTEM
-- ============================================================================

--- Get fire key for tracking
---@param stationKey string
---@param slotIndex number
---@return string
local function getFireKey(stationKey, slotIndex)
    return ('%s_slot%d'):format(stationKey, slotIndex)
end

--- Start fire at a station slot
---@param stationKey string
---@param slotIndex number
---@param coords vector3
---@param initialStage? number Starting fire stage (default: SMOKE_WARNING)
local function startFire(stationKey, slotIndex, coords, initialStage)
    local fireKey = getFireKey(stationKey, slotIndex)
    initialStage = initialStage or FireStages.SMOKE_WARNING
    
    -- Initialize fire state
    fireState[fireKey] = {
        stage = initialStage,
        coords = coords,
        spreadRadius = FireConfig.spreadRadius,
        fireHandles = {},
    }
    
    -- Update visuals for initial stage
    updateFireVisuals(stationKey, slotIndex)
    
    -- Start escalation timer
    scheduleFireEscalation(stationKey, slotIndex)
    
    -- Emit event for external scripts (firefighter integration)
    TriggerEvent('free-restaurants:client:fireStarted', {
        stationKey = stationKey,
        slotIndex = slotIndex,
        coords = coords,
        stage = initialStage,
    })
    
    -- Also trigger server event for sync
    TriggerServerEvent('free-restaurants:server:fireStarted', {
        stationKey = stationKey,
        slotIndex = slotIndex,
        coords = coords,
        stage = initialStage,
    })
end

--- Update fire visuals based on current stage
---@param stationKey string
---@param slotIndex number
local function updateFireVisuals(stationKey, slotIndex)
    local fireKey = getFireKey(stationKey, slotIndex)
    local state = fireState[fireKey]
    
    if not state then return end
    
    local coords = state.coords
    
    -- Stop existing particles for this slot
    stopAllSlotParticles(stationKey, slotIndex)
    
    -- Apply visuals based on stage
    if state.stage == FireStages.SMOKE_WARNING then
        startParticleEffect(stationKey, slotIndex, 'smoke_warning', coords)
        
    elseif state.stage == FireStages.SMALL_FIRE then
        startParticleEffect(stationKey, slotIndex, 'smoke_burning', coords)
        startParticleEffect(stationKey, slotIndex, 'flame_small', coords)
        
    elseif state.stage == FireStages.MEDIUM_FIRE then
        startParticleEffect(stationKey, slotIndex, 'smoke_burning', coords)
        startParticleEffect(stationKey, slotIndex, 'flame_medium', coords)
        
    elseif state.stage >= FireStages.LARGE_FIRE then
        startParticleEffect(stationKey, slotIndex, 'smoke_burning', coords)
        startParticleEffect(stationKey, slotIndex, 'flame_large', coords)
        
        -- Start actual script fire for spreading
        if state.stage == FireStages.LARGE_FIRE then
            local fireHandle = StartScriptFire(coords.x, coords.y, coords.z, 5, false)
            table.insert(state.fireHandles, fireHandle)
            
        elseif state.stage == FireStages.SPREADING then
            -- Add more fires as it spreads
            local fireHandle = StartScriptFire(coords.x, coords.y, coords.z, 15, true)
            table.insert(state.fireHandles, fireHandle)
        end
    end
end

--- Schedule fire escalation
---@param stationKey string
---@param slotIndex number
local function scheduleFireEscalation(stationKey, slotIndex)
    local fireKey = getFireKey(stationKey, slotIndex)
    local state = fireState[fireKey]
    
    if not state then return end
    
    -- Get escalation time for current stage
    local escalationTime = FireConfig.escalationTimes[state.stage]
    
    if not escalationTime then
        -- Already at max stage, start spreading
        if state.stage == FireStages.SPREADING then
            scheduleFireSpread(stationKey, slotIndex)
        end
        return
    end
    
    -- Clear existing timer
    if fireEscalationTimers[fireKey] then
        -- Note: Can't cancel setTimeout, but we track state
    end
    
    -- Schedule escalation
    fireEscalationTimers[fireKey] = SetTimeout(escalationTime, function()
        escalateFire(stationKey, slotIndex)
    end)
end

--- Escalate fire to next stage
---@param stationKey string
---@param slotIndex number
local function escalateFire(stationKey, slotIndex)
    local fireKey = getFireKey(stationKey, slotIndex)
    local state = fireState[fireKey]
    
    if not state then return end
    
    -- Move to next stage
    state.stage = state.stage + 1
    
    FreeRestaurants.Utils.Debug(('Fire escalated to stage %d at %s slot %d'):format(
        state.stage, stationKey, slotIndex
    ))
    
    -- Update visuals
    updateFireVisuals(stationKey, slotIndex)
    
    -- Continue escalation chain
    scheduleFireEscalation(stationKey, slotIndex)
    
    -- Notify server and external scripts
    TriggerEvent('free-restaurants:client:fireEscalated', {
        stationKey = stationKey,
        slotIndex = slotIndex,
        coords = state.coords,
        stage = state.stage,
    })
    
    TriggerServerEvent('free-restaurants:server:fireEscalated', {
        stationKey = stationKey,
        slotIndex = slotIndex,
        coords = state.coords,
        stage = state.stage,
    })
end

--- Schedule fire spreading
---@param stationKey string
---@param slotIndex number
local function scheduleFireSpread(stationKey, slotIndex)
    local fireKey = getFireKey(stationKey, slotIndex)
    local state = fireState[fireKey]
    
    if not state or state.stage < FireStages.SPREADING then return end
    
    SetTimeout(FireConfig.spreadInterval, function()
        spreadFire(stationKey, slotIndex)
    end)
end

--- Spread fire to nearby areas
---@param stationKey string
---@param slotIndex number
local function spreadFire(stationKey, slotIndex)
    local fireKey = getFireKey(stationKey, slotIndex)
    local state = fireState[fireKey]
    
    if not state or state.stage < FireStages.SPREADING then return end
    
    -- Calculate spread position
    local angle = math.random() * 2 * math.pi
    local distance = math.random() * state.spreadRadius
    local spreadX = state.coords.x + math.cos(angle) * distance
    local spreadY = state.coords.y + math.sin(angle) * distance
    local spreadZ = state.coords.z
    
    -- Get ground Z at spread location
    local found, groundZ = GetGroundZFor_3dCoord(spreadX, spreadY, spreadZ + 5.0, false)
    if found then
        spreadZ = groundZ
    end
    
    -- Start fire at spread location
    local fireHandle = StartScriptFire(spreadX, spreadY, spreadZ, 10, true)
    table.insert(state.fireHandles, fireHandle)
    
    -- Grow spread radius
    if state.spreadRadius < FireConfig.maxSpreadRadius then
        state.spreadRadius = state.spreadRadius + FireConfig.spreadRadiusGrowth
    end
    
    FreeRestaurants.Utils.Debug(('Fire spreading at radius %.1f'):format(state.spreadRadius))
    
    -- Continue spreading
    scheduleFireSpread(stationKey, slotIndex)
    
    -- Notify external scripts
    TriggerEvent('free-restaurants:client:fireSpreading', {
        stationKey = stationKey,
        slotIndex = slotIndex,
        spreadCoords = vec3(spreadX, spreadY, spreadZ),
        spreadRadius = state.spreadRadius,
    })
end

--- Stop fire at a station slot (called by external firefighter scripts)
---@param stationKey string
---@param slotIndex number
local function stopFire(stationKey, slotIndex)
    local fireKey = getFireKey(stationKey, slotIndex)
    local state = fireState[fireKey]
    
    if not state then return end
    
    -- Stop all script fires
    for _, handle in ipairs(state.fireHandles) do
        RemoveScriptFire(handle)
    end
    
    -- Stop particles
    stopAllSlotParticles(stationKey, slotIndex)
    
    -- Clear state
    fireState[fireKey] = nil
    fireEscalationTimers[fireKey] = nil
    
    FreeRestaurants.Utils.Debug(('Fire extinguished at %s slot %d'):format(stationKey, slotIndex))
    
    TriggerEvent('free-restaurants:client:fireExtinguished', {
        stationKey = stationKey,
        slotIndex = slotIndex,
    })
    
    TriggerServerEvent('free-restaurants:server:fireExtinguished', {
        stationKey = stationKey,
        slotIndex = slotIndex,
    })
end

-- ============================================================================
-- SLOT CLEANUP
-- ============================================================================

--- Clean up all effects and props for a slot
---@param stationKey string
---@param slotIndex number
cleanupSlot = function(stationKey, slotIndex)
    -- Delete prop
    deleteFoodProp(stationKey, slotIndex)
    
    -- Stop particles (but not fire - fire persists until extinguished)
    local fireKey = getFireKey(stationKey, slotIndex)
    if not fireState[fireKey] then
        stopAllSlotParticles(stationKey, slotIndex)
    end
end

-- ============================================================================
-- HUD COMMUNICATION (DISABLED)
-- ============================================================================

--- Show the station HUD (disabled)
---@param stationKey string
---@param stationType string
---@param capacity number Number of slots
local function showStationHUD(stationKey, stationType, capacity)
    -- HUD disabled
end

--- Hide the station HUD (disabled)
hideStationHUD = function()
    -- HUD disabled
end

--- Update the station HUD with current slot data (disabled)
---@param stationKey string
---@param slotData table
updateStationHUD = function(stationKey, slotData)
    -- HUD disabled
end

-- ============================================================================
-- STATION TARGET SETUP
-- ============================================================================

--- Calculate slot positions around a station
---@param stationCoords vector3
---@param stationType string
---@param numSlots number
---@param stationHeading number
---@return table slotPositions Array of {coords, heading} for each slot
local function calculateSlotPositions(stationCoords, stationType, numSlots, stationHeading)
    local positions = {}
    local stationConfig = Config.Stations.Types[stationType]
    
    if not stationConfig then
        -- Default: single slot at station coords
        for i = 1, numSlots do
            positions[i] = {
                coords = stationCoords + vec3(0.3 * (i - 1), 0, 0),
                heading = stationHeading,
            }
        end
        return positions
    end
    
    -- Calculate based on station type
    local slotSpacing = 0.4  -- Distance between slot centers
    local startOffset = -((numSlots - 1) * slotSpacing) / 2
    
    -- Get the right vector for the station's orientation
    local rad = math.rad(stationHeading)
    local rightX = math.cos(rad)
    local rightY = math.sin(rad)
    
    for i = 1, numSlots do
        local offset = startOffset + (i - 1) * slotSpacing
        positions[i] = {
            coords = vec3(
                stationCoords.x + rightX * offset,
                stationCoords.y + rightY * offset,
                stationCoords.z
            ),
            heading = stationHeading,
        }
    end
    
    return positions
end

--- Create ox_target zones for a station
---@param locationKey string
---@param stationKey string
---@param stationData table Station configuration from locations
---@param stationTypeConfig table Station type configuration
local function createStationTargets(locationKey, stationKey, stationData, stationTypeConfig)
    local fullStationKey = ('%s_%s'):format(locationKey, stationKey)
    
    -- Get capacity
    local capacity = stationTypeConfig.capacity or { slots = 1 }
    local numSlots = capacity.slots or 1
    local simultaneousWork = capacity.simultaneousWork ~= false
    
    -- Calculate slot positions
    local slotPositions = calculateSlotPositions(
        stationData.coords,
        stationData.type,
        numSlots,
        stationData.heading or 0.0
    )
    
    -- Initialize slot cache
    stationSlots[fullStationKey] = {}
    for i = 1, numSlots do
        stationSlots[fullStationKey][i] = {
            occupied = false,
            status = 'empty',
        }
    end
    
    -- Create main station target zone
    local targetOptions = {}
    
    -- Add slot options
    for slotIndex = 1, numSlots do
        -- Option to use the slot (start crafting)
        table.insert(targetOptions, {
            name = ('%s_slot_%d'):format(fullStationKey, slotIndex),
            label = numSlots > 1
                and ('Use %s (Slot %d)'):format(stationData.label, slotIndex)
                or ('Use %s'):format(stationData.label),
            icon = 'fa-solid fa-fire-burner',
            -- Removed groups filter - canInteract checks duty status instead
            canInteract = function()
                -- Debug: Log all checks
                local isOnDuty = FreeRestaurants.Client.IsOnDuty()
                local slotState = getSlotState(locationKey, stationKey, slotIndex)
                local hasCanCook = FreeRestaurants.Client.HasPermission('canCook')

                -- Check if on duty
                if not isOnDuty then
                    return false
                end

                -- Check if slot is available
                if slotState.occupied then
                    return false
                end

                -- Check if player already using another slot (if not simultaneous)
                if currentStation and not simultaneousWork then
                    return false
                end

                -- Check permissions - skip if minGrade is 0 (falsy) or not set
                local requirements = stationTypeConfig.requirements
                if requirements and requirements.minGrade and requirements.minGrade > 0 then
                    if not hasCanCook then
                        return false
                    end
                end

                return true
            end,
            onSelect = function()
                onStationSlotSelected(locationKey, stationKey, slotIndex, stationData, stationTypeConfig)
            end,
        })

        -- Option to pick up completed item from slot
        table.insert(targetOptions, {
            name = ('%s_slot_%d_pickup'):format(fullStationKey, slotIndex),
            label = numSlots > 1
                and ('Pick Up Item (Slot %d)'):format(slotIndex)
                or 'Pick Up Item',
            icon = 'fa-solid fa-hand',
            canInteract = function()
                -- Check if on duty
                if not FreeRestaurants.Client.IsOnDuty() then
                    return false
                end

                -- Check if there's a pending pickup at this slot
                local pendingKey = ('%s_%s_%d'):format(locationKey, stationKey, slotIndex)
                return pendingPickups[pendingKey] ~= nil
            end,
            onSelect = function()
                local pendingKey = ('%s_%s_%d'):format(locationKey, stationKey, slotIndex)
                pickupItemFromStation(pendingKey)
            end,
        })
    end
    
    -- Add view HUD option (always available when on duty)
    table.insert(targetOptions, {
        name = ('%s_view_hud'):format(fullStationKey),
        label = ('View %s Status'):format(stationData.label),
        icon = 'fa-solid fa-eye',
        canInteract = function()
            return FreeRestaurants.Client.IsOnDuty()
        end,
        onSelect = function()
            showStationHUD(fullStationKey, stationData.type, numSlots)
        end,
    })
    
    -- Register the target zone
    exports.ox_target:addBoxZone({
        name = fullStationKey,
        coords = stationData.coords,
        size = stationData.targetSize or vec3(1.5, 1.0, 1.5),
        rotation = stationData.heading or 0,
        debug = Config.Debug,
        options = targetOptions,
    })
    
    stationTargets[fullStationKey] = true
    
    FreeRestaurants.Utils.Debug(('Created station target: %s with %d slots'):format(fullStationKey, numSlots))
end

--- Remove station targets for a location
---@param locationKey string|nil
local function removeLocationStationTargets(locationKey)
    if not locationKey then
        FreeRestaurants.Utils.Debug('removeLocationStationTargets called with nil locationKey, skipping')
        return
    end

    local prefix = locationKey .. '_'
    
    for key, _ in pairs(stationTargets) do
        if key:sub(1, #prefix) == prefix then
            exports.ox_target:removeZone(key)
            stationTargets[key] = nil
            
            -- Clean up all slots
            if stationSlots[key] then
                for slotIndex, _ in pairs(stationSlots[key]) do
                    cleanupSlot(key, slotIndex)
                end
                stationSlots[key] = nil
            end
        end
    end
end

-- ============================================================================
-- STATION INTERACTION
-- ============================================================================

--- Called when player selects a station slot
---@param locationKey string
---@param stationKey string
---@param slotIndex number
---@param stationData table
---@param stationTypeConfig table
onStationSlotSelected = function(locationKey, stationKey, slotIndex, stationData, stationTypeConfig)
    local fullStationKey = ('%s_%s'):format(locationKey, stationKey)

    -- Show recipe selection menu
    local recipes = getAvailableRecipes(stationData.type)
    
    if #recipes == 0 then
        lib.notify({
            title = 'No Recipes',
            description = 'No recipes available for this station.',
            type = 'error',
        })
        return
    end
    
    local menuOptions = {}
    
    for _, recipe in ipairs(recipes) do
        local canCraft, reason = canCraftRecipe(recipe)
        
        table.insert(menuOptions, {
            title = recipe.label,
            description = reason or ('Cook Time: %ds'):format(recipe.cookTime / 1000),
            icon = recipe.icon or 'fa-solid fa-utensils',
            disabled = not canCraft,
            onSelect = function()
                startCookingAtSlot(locationKey, stationKey, slotIndex, recipe, stationData, stationTypeConfig)
            end,
        })
    end
    
    lib.registerContext({
        id = 'station_recipe_select',
        title = stationData.label,
        options = menuOptions,
    })
    
    lib.showContext('station_recipe_select')
end

--- Check if a recipe can use a specific station type
---@param recipe table
---@param stationType string
---@return boolean
local function recipeUsesStation(recipe, stationType)
    if not recipe.stations then return false end

    for _, stationStep in ipairs(recipe.stations) do
        if stationStep.type == stationType then
            return true
        end
    end

    return false
end

--- Get available recipes for a station type
---@param stationType string
---@return table recipes
getAvailableRecipes = function(stationType)
    local recipes = {}

    -- Recipes are stored in Config.Recipes.Items
    local recipeItems = Config.Recipes and Config.Recipes.Items or {}

    -- Debug: Check if recipes are loaded
    local recipeCount = 0
    for _ in pairs(recipeItems) do
        recipeCount = recipeCount + 1
    end
    print(('[free-restaurants] getAvailableRecipes: checking %d recipes for station type: %s'):format(recipeCount, stationType))

    if recipeCount == 0 then
        print('[free-restaurants] WARNING: No recipes loaded in Config.Recipes.Items!')
        if not Config.Recipes then
            print('[free-restaurants] ERROR: Config.Recipes is nil')
        else
            print('[free-restaurants] Config.Recipes exists, available keys:')
            for k, _ in pairs(Config.Recipes) do
                print(('  - %s'):format(tostring(k)))
            end
        end
    end

    for recipeId, recipe in pairs(recipeItems) do
        if recipeUsesStation(recipe, stationType) then
            -- Check level requirements
            local playerLevel = FreeRestaurants.Client.GetPlayerState('cookingLevel') or 1
            if not recipe.levelRequired or playerLevel >= recipe.levelRequired then
                -- Create a copy with ID attached
                local recipeCopy = {}
                for k, v in pairs(recipe) do
                    recipeCopy[k] = v
                end
                recipeCopy.id = recipeId

                -- Calculate total cook time from all station steps
                local totalTime = 0
                for _, step in ipairs(recipe.stations) do
                    totalTime = totalTime + (step.duration or 5000)
                end
                recipeCopy.cookTime = totalTime

                table.insert(recipes, recipeCopy)
                print(('[free-restaurants] Recipe matched: %s for station %s'):format(recipeId, stationType))
            end
        end
    end

    print(('[free-restaurants] Found %d recipes for station type: %s'):format(#recipes, stationType))
    return recipes
end

--- Check if player can craft a recipe
---@param recipe table
---@return boolean canCraft
---@return string? reason
canCraftRecipe = function(recipe)
    if not recipe.ingredients then
        return true, nil
    end

    -- Ingredients are stored as array: { { item = 'name', count = 1 }, ... }
    for _, ingredient in ipairs(recipe.ingredients) do
        local itemName = ingredient.item
        local requiredCount = ingredient.count or 1

        local playerCount = exports.ox_inventory:Search('count', itemName)
        if playerCount < requiredCount then
            local label = ingredient.label or itemName
            return false, ('Missing: %s (need %d)'):format(label, requiredCount)
        end
    end

    return true, nil
end

--- Start cooking at a station slot
---@param locationKey string
---@param stationKey string
---@param slotIndex number
---@param recipe table
---@param stationData table
---@param stationTypeConfig table
startCookingAtSlot = function(locationKey, stationKey, slotIndex, recipe, stationData, stationTypeConfig)
    local fullStationKey = ('%s_%s'):format(locationKey, stationKey)

    -- Claim the slot on server
    local success = claimSlot(locationKey, stationKey, slotIndex, recipe.id)

    if not success then
        lib.notify({
            title = 'Slot Unavailable',
            description = 'This slot is already in use.',
            type = 'error',
        })
        return
    end

    -- Show HUD
    showStationHUD(fullStationKey, stationData.type, stationTypeConfig.capacity.slots or 1)

    -- Get slot position for prop/particle placement
    local slotPositions = calculateSlotPositions(
        stationData.coords,
        stationData.type,
        stationTypeConfig.capacity.slots or 1,
        stationData.heading or 0.0
    )
    local slotPos = slotPositions[slotIndex]

    -- Spawn initial prop (raw state)
    local propType = recipe.propType or recipe.id
    spawnFoodProp(fullStationKey, slotIndex, propType, 'raw', slotPos.coords, slotPos.heading)

    -- Trigger cooking workflow in cooking.lua
    TriggerEvent('free-restaurants:client:startCrafting', recipe.id, recipe, {
        locationKey = locationKey,
        stationKey = stationKey,
        slotIndex = slotIndex,
        stationData = stationData,
        stationTypeConfig = stationTypeConfig,
        slotCoords = slotPos.coords,
    })
end

--- Called when cooking state updates (from cooking.lua)
---@param data table Cooking state data
-- ============================================================================
-- PICKUP SYSTEM (Burn/Spill Mechanics)
-- ============================================================================

--- Pick up an item from the station
---@param pendingKey string The pending pickup key
pickupItemFromStation = function(pendingKey)
    local pending = pendingPickups[pendingKey]
    if not pending then
        return false, 'No item to pick up'
    end

    -- Call server to pick up the item
    local success, result = lib.callback.await(
        'free-restaurants:server:pickupFromStation',
        false,
        pending.locationKey,
        pending.stationKey,
        pending.slotIndex
    )

    if success then
        lib.notify({
            title = 'Item Picked Up',
            description = ('Collected %s'):format(result.recipeLabel or 'item'),
            type = 'success',
        })

        -- Clean up the pending pickup
        pendingPickups[pendingKey] = nil

        -- Release the slot now
        local fullStationKey = ('%s_%s'):format(pending.locationKey, pending.stationKey)
        releaseSlot(pending.locationKey, pending.stationKey, pending.slotIndex, 'collected')
        cleanupSlot(fullStationKey, pending.slotIndex)

        return true
    else
        lib.notify({
            title = 'Pickup Failed',
            description = result or 'Could not pick up item',
            type = 'error',
        })
        return false
    end
end

--- Handle item burn or spill when timer expires
---@param pendingKey string The pending pickup key
handleItemBurnOrSpill = function(pendingKey)
    local pending = pendingPickups[pendingKey]
    if not pending then return end

    local pickupConfig = pending.pickupConfig
    local isBurn = pickupConfig.canBurn
    local fullStationKey = ('%s_%s'):format(pending.locationKey, pending.stationKey)

    -- Call server to handle burn/spill
    lib.callback.await(
        'free-restaurants:server:handleBurnOrSpill',
        false,
        pending.locationKey,
        pending.stationKey,
        pending.slotIndex,
        isBurn
    )

    -- Show notification
    if isBurn then
        lib.notify({
            title = 'Food Burned!',
            description = ('%s was left too long and burned!'):format(pending.recipeLabel or 'Item'),
            type = 'error',
        })

        -- Trigger burnt state for particles/fire
        TriggerEvent('free-restaurants:client:cookingStateUpdate', {
            locationKey = pending.locationKey,
            stationKey = pending.stationKey,
            slotIndex = pending.slotIndex,
            stationType = pending.stationType,
            slotCoords = pending.slotCoords,
            status = 'burnt',
            progress = 100,
            quality = 0,
        })
    else
        lib.notify({
            title = 'Drink Spilled!',
            description = ('%s was left too long and spilled!'):format(pending.recipeLabel or 'Item'),
            type = 'error',
        })

        -- Clean up the slot (spilled items don't cause fire)
        cleanupSlot(fullStationKey, pending.slotIndex)
    end

    -- Release the slot
    releaseSlot(pending.locationKey, pending.stationKey, pending.slotIndex, isBurn and 'burnt' or 'spilled')

    -- Remove from pending pickups
    pendingPickups[pendingKey] = nil
end

--- Start the pickup timer for an item
---@param pendingKey string The pending pickup key
---@param pickupConfig table The pickup configuration
startPickupTimer = function(pendingKey, pickupConfig)
    local timeout = pickupConfig.timeout * 1000  -- Convert to ms
    local warningTime = pickupConfig.warningTime * 1000

    -- Warning timer (if configured)
    if warningTime > 0 and warningTime < timeout then
        SetTimeout(timeout - warningTime, function()
            local pending = pendingPickups[pendingKey]
            if not pending then return end  -- Already picked up

            -- Show warning
            if pickupConfig.canBurn then
                lib.notify({
                    title = 'Warning!',
                    description = ('%s is about to burn! Pick it up now!'):format(pending.recipeLabel or 'Food'),
                    type = 'warning',
                })
            elseif pickupConfig.canSpill then
                lib.notify({
                    title = 'Warning!',
                    description = ('%s is about to spill! Pick it up now!'):format(pending.recipeLabel or 'Drink'),
                    type = 'warning',
                })
            end

            -- Update state to warning
            TriggerEvent('free-restaurants:client:cookingStateUpdate', {
                locationKey = pending.locationKey,
                stationKey = pending.stationKey,
                slotIndex = pending.slotIndex,
                stationType = pending.stationType,
                slotCoords = pending.slotCoords,
                status = 'warning',
                progress = 100,
                quality = pending.quality,
            })
        end)
    end

    -- Burn/Spill timer
    SetTimeout(timeout, function()
        local pending = pendingPickups[pendingKey]
        if not pending then return end  -- Already picked up

        -- Item burned or spilled
        handleItemBurnOrSpill(pendingKey)
    end)
end

--- Check if there's a pending pickup at coordinates
---@param coords vector3
---@param maxDistance number
---@return string|nil pendingKey
---@return table|nil pendingData
local function findNearbyPendingPickup(coords, maxDistance)
    maxDistance = maxDistance or 2.0

    for pendingKey, pending in pairs(pendingPickups) do
        if pending.slotCoords then
            local distance = #(coords - pending.slotCoords)
            if distance <= maxDistance then
                return pendingKey, pending
            end
        end
    end

    return nil, nil
end

-- ============================================================================
-- COOKING STATE HANDLERS
-- ============================================================================

local function onCookingStateUpdate(data)
    local fullStationKey = ('%s_%s'):format(data.locationKey, data.stationKey)
    local slotIndex = data.slotIndex

    -- Update slot state
    local slotState = getSlotState(data.locationKey, data.stationKey, slotIndex)
    slotState.status = data.status
    slotState.progress = data.progress
    slotState.quality = data.quality

    -- Update particles based on status
    local stationTypeConfig = Config.Stations.Types[data.stationType]
    updateCookingParticles(fullStationKey, slotIndex, data.status, data.stationType, data.slotCoords)
    
    -- Update prop state
    if data.status == 'cooking' and data.progress > 30 then
        updatePropState(fullStationKey, slotIndex, 'cooking')
    elseif data.status == 'ready' or data.status == 'completed' then
        updatePropState(fullStationKey, slotIndex, 'cooked')
    elseif data.status == 'burnt' then
        updatePropState(fullStationKey, slotIndex, 'burnt')
        -- Start fire!
        startFire(fullStationKey, slotIndex, data.slotCoords)
    elseif data.status == 'warning' then
        -- Approaching burn state
        startParticleEffect(fullStationKey, slotIndex, 'smoke_warning', data.slotCoords)
    end
    
    -- Update HUD
    updateStationHUD(fullStationKey, stationSlots[fullStationKey])
end

--- Called when cooking completes
---@param data table Completion data
local function onCookingComplete(data)
    local fullStationKey = ('%s_%s'):format(data.locationKey, data.stationKey)
    local slotIndex = data.slotIndex

    -- Handle 'ready_for_pickup' status - item stays at station
    if data.status == 'ready_for_pickup' then
        -- Don't release slot yet - item is waiting for pickup
        -- Start pickup timer if this station has timeout
        local pickupConfig = data.pickupConfig
        if pickupConfig and pickupConfig.required then
            -- Track pending pickup
            local pendingKey = ('%s_%s_%d'):format(data.locationKey, data.stationKey, slotIndex)
            pendingPickups[pendingKey] = {
                locationKey = data.locationKey,
                stationKey = data.stationKey,
                slotIndex = slotIndex,
                slotCoords = data.slotCoords,
                stationType = data.stationType,
                recipeId = data.recipeId,
                recipeLabel = data.recipeLabel,
                quality = data.quality,
                pickupConfig = pickupConfig,
                createdAt = GetGameTimer(),
            }

            -- Start timer if there's a timeout
            if pickupConfig.timeout and pickupConfig.timeout > 0 then
                startPickupTimer(pendingKey, pickupConfig)
            end
        end

        -- Keep the slot marked as in-use until pickup
        -- Update slot state to 'ready'
        if stationSlots[fullStationKey] and stationSlots[fullStationKey][slotIndex] then
            stationSlots[fullStationKey][slotIndex].status = 'ready'
            stationSlots[fullStationKey][slotIndex].recipeLabel = data.recipeLabel
        end

        -- Hide HUD if this was our station
        if currentStation == fullStationKey then
            hideStationHUD()
        end
        return
    end

    -- For other statuses (completed, failed, cancelled, burnt), release slot normally
    releaseSlot(data.locationKey, data.stationKey, slotIndex, data.status)

    -- Clean up if not burnt (burnt items keep fire going)
    if data.status ~= 'burnt' then
        cleanupSlot(fullStationKey, slotIndex)
    end

    -- Hide HUD if this was our station
    if currentStation == fullStationKey then
        hideStationHUD()
    end
end

-- ============================================================================
-- NUI CALLBACKS
-- ============================================================================

--- Handle HUD close from NUI
RegisterNUICallback('closeHUD', function(data, cb)
    hideStationHUD()
    cb('ok')
end)

-- ============================================================================
-- STATE BAG HANDLERS
-- ============================================================================

--- Handle state bag changes for station slots
AddStateBagChangeHandler('', '', function(bagName, key, value, _reserved, replicated)
    -- Only handle restaurant station state bags
    if not key:match('^restaurant:') then return end
    
    -- Parse the key: restaurant:locationKey:stationKey
    local parts = {}
    for part in key:gmatch('[^:]+') do
        table.insert(parts, part)
    end
    
    if #parts < 3 then return end
    
    local locationKey = parts[2]
    local stationKey = parts[3]
    
    -- Schedule update for next frame (entity might not exist yet)
    SetTimeout(0, function()
        if value then
            updateLocalSlotCache(locationKey, stationKey, value)
        end
    end)
end)

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

-- Initialize stations when entering a restaurant
RegisterNetEvent('free-restaurants:client:enteredRestaurant', function(locationKey, locationData)
    print(('[free-restaurants] Station setup triggered for: %s'):format(locationKey))
    FreeRestaurants.Utils.Debug(('Setting up stations for: %s'):format(locationKey))

    if not locationData then
        print('[free-restaurants] ERROR: locationData is nil')
        return
    end

    if not locationData.stations then
        print(('[free-restaurants] No stations defined for location: %s'):format(locationKey))
        return
    end

    print(('[free-restaurants] Found stations table for %s, checking Config.Stations.Types...'):format(locationKey))

    -- Detailed diagnostic for Config.Stations
    if not Config then
        print('[free-restaurants] ERROR: Config is nil!')
        return
    end
    if not Config.Stations then
        print('[free-restaurants] ERROR: Config.Stations is nil!')
        print('[free-restaurants] Available Config keys:')
        for k, _ in pairs(Config) do
            print(('  - %s'):format(tostring(k)))
        end
        return
    end
    if not Config.Stations.Types then
        print('[free-restaurants] ERROR: Config.Stations.Types is nil!')
        print('[free-restaurants] Available Config.Stations keys:')
        for k, _ in pairs(Config.Stations) do
            print(('  - %s'):format(tostring(k)))
        end
        return
    end

    print(('[free-restaurants] Config.Stations.Types found with station definitions'):format())

    local stationCount = 0
    -- Create targets for each station
    for stationKey, stationData in pairs(locationData.stations) do
        local stationTypeConfig = Config.Stations.Types[stationData.type]

        if stationTypeConfig then
            -- Add job reference if not present
            stationData.job = stationData.job or locationData.job

            print(('[free-restaurants] Creating station target: %s (type: %s)'):format(stationKey, stationData.type))
            createStationTargets(locationKey, stationKey, stationData, stationTypeConfig)
            stationCount = stationCount + 1
        else
            print(('[free-restaurants] WARNING: Unknown station type: %s'):format(stationData.type))
            FreeRestaurants.Utils.Debug(('Unknown station type: %s'):format(stationData.type))
        end
    end

    print(('[free-restaurants] Created %d station targets for %s'):format(stationCount, locationKey))
end)

-- Clean up stations when leaving a restaurant
RegisterNetEvent('free-restaurants:client:exitedRestaurant', function(locationKey)
    FreeRestaurants.Utils.Debug(('Cleaning up stations for: %s'):format(tostring(locationKey)))

    -- Hide HUD if visible
    hideStationHUD()

    -- Remove targets
    removeLocationStationTargets(locationKey)
end)

-- Handle cooking state updates from cooking.lua
RegisterNetEvent('free-restaurants:client:cookingStateUpdate', function(data)
    onCookingStateUpdate(data)
end)

-- Handle cooking completion from cooking.lua
RegisterNetEvent('free-restaurants:client:cookingComplete', function(data)
    onCookingComplete(data)
end)

-- External event: Fire extinguished (from firefighter scripts)
RegisterNetEvent('free-restaurants:client:externalFireExtinguished', function(coords, radius)
    -- Check all active fires and stop any within radius
    for fireKey, state in pairs(fireState) do
        if state and state.coords then
            local dist = #(state.coords - coords)
            if dist <= (radius or 5.0) then
                local parts = {}
                for part in fireKey:gmatch('[^_slot]+') do
                    table.insert(parts, part)
                end
                if #parts >= 2 then
                    stopFire(parts[1]:gsub('_slot$', ''), tonumber(parts[2]) or 1)
                end
            end
        end
    end
end)

-- Resource cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    -- Clean up all spawned props
    for _, propData in pairs(spawnedProps) do
        if propData.entity and DoesEntityExist(propData.entity) then
            DeleteEntity(propData.entity)
        end
    end
    
    -- Stop all particles
    for _, particleData in pairs(activeParticles) do
        if particleData.handle then
            StopParticleFxLooped(particleData.handle, false)
        end
    end
    
    -- Stop all script fires
    for _, state in pairs(fireState) do
        if state.fireHandles then
            for _, handle in ipairs(state.fireHandles) do
                RemoveScriptFire(handle)
            end
        end
    end
    
    -- Hide HUD
    hideStationHUD()
    
    -- Remove all targets
    for key, _ in pairs(stationTargets) do
        exports.ox_target:removeZone(key)
    end
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

-- Station state
exports('GetStationSlots', function(stationKey) return stationSlots[stationKey] end)
exports('GetSlotState', getSlotState)
exports('IsSlotAvailable', function(locationKey, stationKey, slotIndex)
    local state = getSlotState(locationKey, stationKey, slotIndex)
    return not state.occupied
end)

-- Prop management
exports('SpawnFoodProp', spawnFoodProp)
exports('DeleteFoodProp', deleteFoodProp)
exports('UpdatePropState', updatePropState)

-- Particle management
exports('StartParticleEffect', startParticleEffect)
exports('StopParticleEffect', stopParticleEffect)
exports('StopAllSlotParticles', stopAllSlotParticles)

-- Fire system
exports('StartFire', startFire)
exports('StopFire', stopFire)
exports('GetFireState', function(stationKey, slotIndex)
    return fireState[getFireKey(stationKey, slotIndex)]
end)

-- HUD
exports('ShowStationHUD', showStationHUD)
exports('HideStationHUD', hideStationHUD)
exports('UpdateStationHUD', updateStationHUD)

-- Slot management
exports('ClaimSlot', claimSlot)
exports('ReleaseSlot', releaseSlot)

-- Pickup system
exports('GetPendingPickups', function() return pendingPickups end)
exports('GetPendingPickup', function(locationKey, stationKey, slotIndex)
    local pendingKey = ('%s_%s_%d'):format(locationKey, stationKey, slotIndex)
    return pendingPickups[pendingKey]
end)
exports('PickupItemFromStation', function(locationKey, stationKey, slotIndex)
    local pendingKey = ('%s_%s_%d'):format(locationKey, stationKey, slotIndex)
    return pickupItemFromStation(pendingKey)
end)

-- ============================================================================
-- SERVER SYNC EVENT HANDLERS
-- ============================================================================

-- Sync fire from server (for late-joining players or cross-client sync)
RegisterNetEvent('free-restaurants:client:syncFire', function(data)
    if not data then return end
    
    local fireKey = getFireKey(data.stationKey, data.slotIndex)
    
    -- Create fire if not already exists
    if not fireState[fireKey] then
        fireState[fireKey] = {
            level = data.level or 1,
            startTime = GetGameTimer(),
            lastEscalation = GetGameTimer(),
        }
    else
        fireState[fireKey].level = data.level or fireState[fireKey].level
    end
    
    -- Ensure fire is visually burning
    if data.coords then
        StartScriptFire(data.coords.x, data.coords.y, data.coords.z, 
            math.min(25, (data.level or 1) * 3), data.level > 2)
    end
    
    FreeRestaurants.Utils.Debug(('Synced fire: %s level %d'):format(fireKey, data.level or 1))
end)

-- Sync fire extinguished from server
RegisterNetEvent('free-restaurants:client:syncFireExtinguished', function(data)
    if not data then return end
    
    local fireKey = getFireKey(data.stationKey, data.slotIndex)
    
    -- Clear fire state
    if fireState[fireKey] then
        fireState[fireKey] = nil
    end
    
    -- Stop script fires in area
    if data.coords then
        StopFireInRange(data.coords.x, data.coords.y, data.coords.z, 5.0)
    end
    
    FreeRestaurants.Utils.Debug(('Fire extinguished sync: %s'):format(fireKey))
end)

-- ============================================================================
-- GLOBAL TABLE
-- ============================================================================

FreeRestaurants.Stations = {
    GetSlotState = getSlotState,
    ClaimSlot = claimSlot,
    ReleaseSlot = releaseSlot,
    SpawnFoodProp = spawnFoodProp,
    DeleteFoodProp = deleteFoodProp,
    StartParticleEffect = startParticleEffect,
    StopParticleEffect = stopParticleEffect,
    StartFire = startFire,
    StopFire = stopFire,
    ShowHUD = showStationHUD,
    HideHUD = hideStationHUD,
}

FreeRestaurants.Utils.Debug('client/stations.lua loaded')
