--[[
    free-restaurants Server Decay System
    
    Handles:
    - Food freshness decay over time
    - Quality degradation
    - Spoiled item handling
    - Storage-based decay modifiers
    
    DEPENDENCIES:
    - ox_inventory
]]

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local DecayConfig = {
    -- How often to process decay (milliseconds)
    updateInterval = 60000, -- 1 minute
    
    -- Base decay rate per hour (percentage)
    baseDecayRate = 5, -- 5% per hour
    
    -- Decay modifiers by storage type
    storageModifiers = {
        player = 1.0,           -- Normal decay in player inventory
        stash = 0.8,            -- 80% decay in storage
        freezer = 0.1,          -- 10% decay in freezer
        fridge = 0.3,           -- 30% decay in fridge
    },
    
    -- Minimum freshness before item is considered spoiled
    spoiledThreshold = 10,
    
    -- What happens to spoiled items
    spoiledAction = 'degrade', -- 'remove', 'degrade', or 'keep'
}

-- Track which items should decay
local decayableItems = {}

-- Helper function (must be defined before use)
local function tableCount(tbl)
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

--- Build list of decayable items from recipes
local function initializeDecayableItems()
    -- Add all food items from recipes
    for recipeId, recipe in pairs(Config.Recipes) do
        if recipe.isFoodItem or recipe.category == 'food' or recipe.category == 'drinks' then
            local resultItem = type(recipe.result) == 'table' and recipe.result.item or recipe.result
            if resultItem then
                decayableItems[resultItem] = {
                    decayRate = recipe.decayRate or 1.0,
                    spoiledItem = recipe.spoiledItem, -- Optional replacement when spoiled
                }
            end
        end
    end
    
    -- Add raw ingredients
    local ingredients = {
        'patty_raw', 'chicken_raw', 'fish_raw', 'lettuce', 'tomato',
        'cheese', 'milk', 'cream', 'eggs', 'butter',
    }
    
    for _, item in ipairs(ingredients) do
        if not decayableItems[item] then
            decayableItems[item] = {
                decayRate = 1.5, -- Raw ingredients decay faster
            }
        end
    end
    
    print(('[free-restaurants] Initialized decay for %d items'):format(tableCount(decayableItems)))
end

-- ============================================================================
-- DECAY PROCESSING
-- ============================================================================

--- Process decay for a single item
---@param item table Item data from ox_inventory
---@param decayRate number Rate modifier
---@param timeElapsed number Time in hours
---@return table|nil updatedItem Updated item or nil if spoiled
local function processItemDecay(item, decayRate, timeElapsed)
    if not item.metadata then return item end
    
    local freshness = item.metadata.freshness
    if not freshness then return item end
    
    -- Calculate decay amount
    local decayAmount = DecayConfig.baseDecayRate * decayRate * timeElapsed
    local newFreshness = math.max(0, freshness - decayAmount)
    
    -- Update metadata
    item.metadata.freshness = newFreshness
    
    -- Also degrade quality proportionally
    if item.metadata.quality then
        local qualityLoss = (freshness - newFreshness) * 0.5 -- Quality degrades at half rate
        item.metadata.quality = math.max(0, item.metadata.quality - qualityLoss)
    end
    
    -- Check if spoiled
    if newFreshness <= DecayConfig.spoiledThreshold then
        item.metadata.spoiled = true
        
        if DecayConfig.spoiledAction == 'remove' then
            return nil -- Item should be removed
        end
    end
    
    return item
end

--- Process decay for a player's inventory
---@param source number Player source
local function processPlayerDecay(source)
    local items = exports.ox_inventory:GetInventoryItems(source)
    if not items then return end
    
    local currentTime = os.time()
    local updates = {}
    local removals = {}
    
    for slot, item in pairs(items) do
        if item and decayableItems[item.name] then
            local decayConfig = decayableItems[item.name]
            
            -- Calculate time since last decay check
            local lastDecay = item.metadata and item.metadata.lastDecay or currentTime
            local timeElapsed = (currentTime - lastDecay) / 3600 -- Convert to hours
            
            if timeElapsed > 0 then
                local updatedItem = processItemDecay(
                    item,
                    decayConfig.decayRate * DecayConfig.storageModifiers.player,
                    timeElapsed
                )
                
                if updatedItem then
                    updatedItem.metadata.lastDecay = currentTime
                    updates[slot] = updatedItem.metadata
                else
                    table.insert(removals, { slot = slot, item = item })
                end
            end
        end
    end
    
    -- Apply updates
    for slot, metadata in pairs(updates) do
        exports.ox_inventory:SetMetadata(source, slot, metadata)
    end
    
    -- Remove spoiled items
    for _, removal in ipairs(removals) do
        exports.ox_inventory:RemoveItem(source, removal.item.name, removal.item.count, nil, removal.slot)
        
        -- Notify player
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Food Spoiled',
            description = ('%s has gone bad and was discarded'):format(removal.item.label or removal.item.name),
            type = 'warning',
        })
    end
end

--- Process decay for a stash
---@param stashId string Stash identifier
---@param storageType? string Type of storage for modifier
local function processStashDecay(stashId, storageType)
    local items = exports.ox_inventory:GetInventoryItems(stashId)
    if not items then return end
    
    storageType = storageType or 'stash'
    local modifier = DecayConfig.storageModifiers[storageType] or 1.0
    
    local currentTime = os.time()
    local updates = {}
    local removals = {}
    
    for slot, item in pairs(items) do
        if item and decayableItems[item.name] then
            local decayConfig = decayableItems[item.name]
            
            local lastDecay = item.metadata and item.metadata.lastDecay or currentTime
            local timeElapsed = (currentTime - lastDecay) / 3600
            
            if timeElapsed > 0 then
                local updatedItem = processItemDecay(
                    item,
                    decayConfig.decayRate * modifier,
                    timeElapsed
                )
                
                if updatedItem then
                    updatedItem.metadata.lastDecay = currentTime
                    updates[slot] = updatedItem.metadata
                else
                    table.insert(removals, { slot = slot, item = item })
                end
            end
        end
    end
    
    -- Apply updates
    for slot, metadata in pairs(updates) do
        exports.ox_inventory:SetMetadata(stashId, slot, metadata)
    end
    
    -- Remove spoiled items
    for _, removal in ipairs(removals) do
        exports.ox_inventory:RemoveItem(stashId, removal.item.name, removal.item.count, nil, removal.slot)
    end
end

-- ============================================================================
-- DECAY THREAD
-- ============================================================================

CreateThread(function()
    -- Wait for initialization
    Wait(5000)
    initializeDecayableItems()
    
    while true do
        Wait(DecayConfig.updateInterval)
        
        -- Process all online players
        local players = exports.qbx_core:GetQBPlayers()
        for _, player in pairs(players) do
            processPlayerDecay(player.PlayerData.source)
        end
        
        -- Process restaurant stashes
        for restaurantType, locations in pairs(Config.Locations or {}) do
            if type(locations) == 'table' and restaurantType ~= 'Settings' then
                for locationId, locationData in pairs(locations) do
                    if type(locationData) == 'table' and locationData.storage then
                        for storageId, storageData in pairs(locationData.storage) do
                            local stashId = ('restaurant_%s_%s_%s'):format(
                                restaurantType, locationId, storageId
                            )
                            
                            -- Determine storage type for decay modifier
                            local storageType = 'stash'
                            if storageId:match('freezer') then
                                storageType = 'freezer'
                            elseif storageId:match('fridge') or storageData.decayMultiplier then
                                storageType = 'fridge'
                            end
                            
                            processStashDecay(stashId, storageType)
                        end
                    end
                end
            end
        end
    end
end)

-- ============================================================================
-- CALLBACKS
-- ============================================================================

--- Get freshness of items
lib.callback.register('free-restaurants:server:getItemFreshness', function(source, itemName)
    local items = exports.ox_inventory:Search(source, 'slots', itemName)
    
    local freshnessList = {}
    if items then
        for slot, item in pairs(items) do
            if item.metadata and item.metadata.freshness then
                table.insert(freshnessList, {
                    slot = slot,
                    count = item.count,
                    freshness = item.metadata.freshness,
                    quality = item.metadata.quality,
                    spoiled = item.metadata.spoiled,
                })
            end
        end
    end
    
    return freshnessList
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('ProcessPlayerDecay', processPlayerDecay)
exports('ProcessStashDecay', processStashDecay)
exports('GetDecayableItems', function() return decayableItems end)
exports('AddDecayableItem', function(itemName, config)
    decayableItems[itemName] = config
end)

print('[free-restaurants] server/decay.lua loaded')
