--[[
    free-restaurants Server Crafting System

    Handles:
    - Recipe validation
    - Ingredient consumption
    - Item creation with quality metadata
    - XP rewards and skill progression
    - Failure handling

    DEPENDENCIES:
    - server/main.lua
    - ox_inventory
    - qbx_core
]]

print('[free-restaurants] server/crafting.lua loading...')

-- Forward declarations for functions used before definition
local calculateLevel

-- ============================================================================
-- PENDING STATION ITEMS
-- ============================================================================

-- Track items waiting for pickup at stations
-- Key format: "locationKey:stationKey:slotIndex"
local pendingStationItems = {}

-- ============================================================================
-- QUALITY SYSTEM
-- ============================================================================

--- Calculate item quality based on crafting quality and freshness
---@param craftQuality number 0.0 to 1.0
---@param ingredientFreshness? number Average freshness of ingredients (0-100)
---@return number quality 0-100
local function calculateItemQuality(craftQuality, ingredientFreshness)
    local baseQuality = craftQuality * 100
    
    -- Apply freshness modifier if provided
    if ingredientFreshness then
        local freshnessModifier = ingredientFreshness / 100
        baseQuality = baseQuality * freshnessModifier
    end
    
    -- Clamp to valid range
    return math.floor(math.max(0, math.min(100, baseQuality)))
end

--- Get quality label for display
---@param quality number 0-100
---@return string label
---@return string tier
local function getQualityInfo(quality)
    if quality >= 90 then
        return 'Excellent', 'excellent'
    elseif quality >= 75 then
        return 'Good', 'good'
    elseif quality >= 50 then
        return 'Average', 'average'
    elseif quality >= 25 then
        return 'Poor', 'poor'
    else
        return 'Terrible', 'terrible'
    end
end

-- ============================================================================
-- INGREDIENT VALIDATION
-- ============================================================================

--- Check if player has all required ingredients
---@param source number
---@param ingredients table { [item] = amount }
---@return boolean hasAll
---@return table missing
---@return number avgFreshness
local function validateIngredients(source, ingredients)
    local missing = {}
    local hasAll = true
    local totalFreshness = 0
    local freshnessCount = 0

    for _, ingredient in ipairs(ingredients) do
        local item = ingredient.item
        local amount = ingredient.count or 1
        local count = exports.ox_inventory:Search(source, 'count', item)

        if count < amount then
            missing[item] = amount - count
            hasAll = false
        else
            -- Check freshness of ingredients if they have decay
            local items = exports.ox_inventory:Search(source, 'slots', item)
            if items then
                for _, slot in pairs(items) do
                    if slot.metadata and slot.metadata.freshness then
                        totalFreshness = totalFreshness + slot.metadata.freshness
                        freshnessCount = freshnessCount + 1
                    end
                end
            end
        end
    end

    local avgFreshness = freshnessCount > 0 and (totalFreshness / freshnessCount) or 100

    return hasAll, missing, avgFreshness
end

--- Remove ingredients from player inventory
---@param source number
---@param ingredients table { [item] = amount }
---@return boolean success
local function removeIngredients(source, ingredients)
    for _, ingredient in ipairs(ingredients) do
        local item = ingredient.item
        local amount = ingredient.count or 1
        local removed = exports.ox_inventory:RemoveItem(source, item, amount)
        if not removed then
            return false
        end
    end
    return true
end

--- Remove partial ingredients on failure (configurable percentage)
---@param source number
---@param ingredients table
---@param lossPercentage number 0.0 to 1.0
local function removePartialIngredients(source, ingredients, lossPercentage)
    for _, ingredient in ipairs(ingredients) do
        local item = ingredient.item
        local amount = ingredient.count or 1
        local lostAmount = math.ceil(amount * lossPercentage)
        if lostAmount > 0 then
            exports.ox_inventory:RemoveItem(source, item, lostAmount)
        end
    end
end

--- Return ingredients to player inventory (for cancelled crafting)
---@param source number
---@param ingredients table Array of {item, count} objects
---@return boolean success
local function returnIngredients(source, ingredients)
    for _, ingredient in ipairs(ingredients) do
        local item = ingredient.item
        local amount = ingredient.count or 1
        exports.ox_inventory:AddItem(source, item, amount)
    end
    return true
end

-- ============================================================================
-- ITEM CREATION
-- ============================================================================

--- Create crafted item with quality metadata
---@param source number
---@param recipe table Recipe configuration
---@param quality number 0-100
---@return boolean success
local function createCraftedItem(source, recipe, quality)
    local result = recipe.result
    if not result then return false end
    
    local itemName = type(result) == 'table' and result.item or result
    local amount = type(result) == 'table' and result.amount or 1
    
    -- Build metadata
    local metadata = {
        quality = quality,
        craftedAt = os.time(),
        craftedBy = exports.qbx_core:GetPlayer(source)?.PlayerData?.citizenid,
    }
    
    -- Add freshness for food items (starts at quality level)
    if recipe.category == 'food' or recipe.isFoodItem then
        metadata.freshness = quality
        metadata.decayRate = recipe.decayRate or 1.0
    end
    
    -- Add any custom metadata from recipe
    if recipe.metadata then
        for k, v in pairs(recipe.metadata) do
            metadata[k] = v
        end
    end
    
    -- Apply quality tier label
    local qualityLabel, qualityTier = getQualityInfo(quality)
    metadata.qualityLabel = qualityLabel
    metadata.qualityTier = qualityTier
    
    -- Add item to inventory
    local success = exports.ox_inventory:AddItem(source, itemName, amount, metadata)
    
    return success
end

-- ============================================================================
-- XP AND PROGRESSION
-- ============================================================================

--- Award XP for successful craft
---@param source number
---@param recipe table Recipe configuration
---@param quality number 0-100
---@return number xpAwarded
local function awardCraftXP(source, recipe, quality)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return 0 end
    
    local baseXP = recipe.xpReward or 10
    
    -- Quality multiplier
    local qualityMultiplier = 0.5 + (quality / 100) * 0.5 -- 50% to 100%
    
    -- Difficulty multiplier
    local difficultyMultiplier = 1.0
    if recipe.difficulty == 'hard' then
        difficultyMultiplier = 1.5
    elseif recipe.difficulty == 'medium' then
        difficultyMultiplier = 1.25
    end
    
    local totalXP = math.floor(baseXP * qualityMultiplier * difficultyMultiplier)
    
    -- Update player progression
    local citizenid = player.PlayerData.citizenid
    local restaurantData = exports['free-restaurants']:GetPlayerRestaurantData(citizenid)
    
    restaurantData.cookingXp = restaurantData.cookingXp + totalXP
    restaurantData.totalCrafts = restaurantData.totalCrafts + 1
    
    -- Update skill for recipe category
    local category = recipe.category or 'general'
    restaurantData.skills[category] = (restaurantData.skills[category] or 0) + 1
    
    -- Check for level up
    local newLevel = calculateLevel(restaurantData.cookingXp)
    local leveledUp = newLevel > restaurantData.cookingLevel
    
    if leveledUp then
        restaurantData.cookingLevel = newLevel
        
        -- Notify player of level up
        TriggerClientEvent('free-restaurants:client:levelUp', source, {
            newLevel = newLevel,
            totalXp = restaurantData.cookingXp,
        })
    end
    
    -- Save data
    exports['free-restaurants']:SavePlayerRestaurantData(citizenid, restaurantData)
    
    return totalXP
end

--- Calculate level from XP
---@param xp number
---@return number level
calculateLevel = function(xp)
    -- Simple level curve: 100 * level^2 XP per level
    local level = 1
    local xpRequired = 0
    
    while xp >= xpRequired do
        level = level + 1
        xpRequired = xpRequired + (100 * level * level)
    end
    
    return math.max(1, level - 1)
end

-- Helper function to check if table contains value
local function tableContains(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then return true end
    end
    return false
end

--- Check if player can craft recipe (level requirement)
---@param source number
---@param recipe table
---@return boolean canCraft
---@return string? reason
local function canCraftRecipe(source, recipe)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false, 'Player not found' end
    
    -- Check level requirement
    if recipe.levelRequired then
        local restaurantData = exports['free-restaurants']:GetPlayerRestaurantData(player.PlayerData.citizenid)
        if restaurantData.cookingLevel < recipe.levelRequired then
            return false, ('Requires cooking level %d'):format(recipe.levelRequired)
        end
    end
    
    -- Check if recipe is unlocked
    if recipe.requiresUnlock then
        local restaurantData = exports['free-restaurants']:GetPlayerRestaurantData(player.PlayerData.citizenid)
        if not restaurantData.unlockedRecipes or not tableContains(restaurantData.unlockedRecipes, recipe.id) then
            return false, 'Recipe not unlocked'
        end
    end
    
    return true, nil
end

-- ============================================================================
-- CALLBACKS
-- ============================================================================

print('[free-restaurants] Registering crafting callbacks...')

--- Consume ingredients at start of crafting
lib.callback.register('free-restaurants:server:consumeIngredients', function(source, recipeId)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false, 'Player not found' end

    -- Get recipe
    local recipe = Config.Recipes.Items[recipeId]
    if not recipe then return false, 'Invalid recipe' end

    -- Validate can craft
    local canCraft, reason = canCraftRecipe(source, recipe)
    if not canCraft then return false, reason end

    -- Validate ingredients
    local hasAll, missing, avgFreshness = validateIngredients(source, recipe.ingredients)
    if not hasAll then return false, 'Missing ingredients' end

    -- Remove ingredients NOW (at start of crafting)
    if not removeIngredients(source, recipe.ingredients) then
        return false, 'Failed to remove ingredients'
    end

    print(('[free-restaurants] Player %s started crafting %s - ingredients consumed'):format(
        player.PlayerData.citizenid, recipeId
    ))

    -- Return success and the freshness for quality calculation later
    return true, avgFreshness
end)

--- Complete craft callback (ingredients already consumed)
lib.callback.register('free-restaurants:server:completeCraft', function(source, recipeId, quality, locationKey, avgFreshness)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false, 'Player not found' end

    -- Get recipe
    local recipe = Config.Recipes.Items[recipeId]
    if not recipe then return false, 'Invalid recipe' end

    -- Calculate final quality with freshness (passed from consumeIngredients)
    local finalQuality = calculateItemQuality(quality, avgFreshness or 100)

    -- Create item
    if not createCraftedItem(source, recipe, finalQuality) then
        return false, 'Inventory full'
    end

    -- Award XP
    local xpAwarded = awardCraftXP(source, recipe, finalQuality)

    -- Add to business earnings if configured
    local session = exports['free-restaurants']:GetSession(source)
    if session and recipe.businessValue then
        exports['free-restaurants']:UpdateBusinessBalance(
            session.job,
            recipe.businessValue,
            'production',
            ('Crafted %s'):format(recipe.label),
            player.PlayerData.citizenid
        )
    end

    -- Track task completion
    exports['free-restaurants']:IncrementTasks(source)

    print(('[free-restaurants] Player %s crafted %s (quality: %d, xp: %d)'):format(
        player.PlayerData.citizenid, recipeId, finalQuality, xpAwarded
    ))

    return true, nil
end)

--- Return ingredients when crafting is cancelled
lib.callback.register('free-restaurants:server:returnIngredients', function(source, recipeId)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end

    local recipe = Config.Recipes.Items[recipeId]
    if not recipe then return false end

    -- Return all ingredients to player
    returnIngredients(source, recipe.ingredients)

    print(('[free-restaurants] Player %s cancelled craft %s - ingredients returned'):format(
        player.PlayerData.citizenid, recipeId
    ))

    return true
end)

--- Get available recipes for station
lib.callback.register('free-restaurants:server:getAvailableRecipes', function(source, stationType)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return {} end
    
    local restaurantData = exports['free-restaurants']:GetPlayerRestaurantData(player.PlayerData.citizenid)
    local availableRecipes = {}
    
    for recipeId, recipe in pairs(Config.Recipes.Items) do
        -- Check station match
        local stationMatch = false
        if type(recipe.station) == 'table' then
            for _, s in ipairs(recipe.station) do
                if s == stationType then
                    stationMatch = true
                    break
                end
            end
        else
            stationMatch = recipe.station == stationType
        end
        
        if stationMatch then
            -- Check level requirement
            local levelOk = not recipe.levelRequired or restaurantData.cookingLevel >= recipe.levelRequired
            
            -- Check if unlocked
            local unlocked = not recipe.requiresUnlock or
                (restaurantData.unlockedRecipes and tableContains(restaurantData.unlockedRecipes, recipeId))
            
            if levelOk and unlocked then
                table.insert(availableRecipes, {
                    id = recipeId,
                    label = recipe.label,
                    ingredients = recipe.ingredients,
                    cookTime = recipe.cookTime,
                    difficulty = recipe.difficulty,
                    levelRequired = recipe.levelRequired,
                })
            end
        end
    end
    
    return availableRecipes
end)

--- Consume ingredients for batch crafting at start
lib.callback.register('free-restaurants:server:consumeBatchIngredients', function(source, recipeId, amount)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false, 'Player not found' end

    local recipe = Config.Recipes.Items[recipeId]
    if not recipe then return false, 'Invalid recipe' end

    -- Calculate ingredients needed for batch
    local batchIngredients = {}
    for _, ingredient in ipairs(recipe.ingredients) do
        table.insert(batchIngredients, {
            item = ingredient.item,
            count = (ingredient.count or 1) * amount
        })
    end

    -- Validate ingredients
    local hasAll, missing, avgFreshness = validateIngredients(source, batchIngredients)
    if not hasAll then return false, 'Missing ingredients' end

    -- Remove all ingredients NOW
    if not removeIngredients(source, batchIngredients) then
        return false, 'Failed to remove ingredients'
    end

    print(('[free-restaurants] Player %s started batch craft %dx %s - ingredients consumed'):format(
        player.PlayerData.citizenid, amount, recipeId
    ))

    return true, avgFreshness
end)

--- Return batch ingredients when cancelled
lib.callback.register('free-restaurants:server:returnBatchIngredients', function(source, recipeId, amount)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end

    local recipe = Config.Recipes.Items[recipeId]
    if not recipe then return false end

    -- Return all batch ingredients
    local batchIngredients = {}
    for _, ingredient in ipairs(recipe.ingredients) do
        table.insert(batchIngredients, {
            item = ingredient.item,
            count = (ingredient.count or 1) * amount
        })
    end

    returnIngredients(source, batchIngredients)

    print(('[free-restaurants] Player %s cancelled batch craft %dx %s - ingredients returned'):format(
        player.PlayerData.citizenid, amount, recipeId
    ))

    return true
end)

--- Complete batch craft callback (ingredients already consumed)
lib.callback.register('free-restaurants:server:completeBatchCraft', function(source, recipeId, amount, locationKey, avgFreshness)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false, 'Player not found' end

    local recipe = Config.Recipes.Items[recipeId]
    if not recipe then return false, 'Invalid recipe' end

    -- Calculate quality (batch crafting is slightly lower quality)
    local batchQualityPenalty = 0.9 -- 90% of normal quality
    local finalQuality = calculateItemQuality(batchQualityPenalty, avgFreshness or 100)

    -- Create items
    local resultItem = type(recipe.result) == 'table' and recipe.result.item or recipe.result
    local resultAmount = type(recipe.result) == 'table' and recipe.result.amount or 1
    local totalItems = resultAmount * amount

    local metadata = {
        quality = finalQuality,
        craftedAt = os.time(),
        craftedBy = player.PlayerData.citizenid,
        freshness = finalQuality,
    }

    local success = exports.ox_inventory:AddItem(source, resultItem, totalItems, metadata)
    if not success then
        return false, 'Inventory full'
    end

    -- Award XP (reduced for batch)
    local baseXP = recipe.xpReward or 10
    local batchXP = math.floor(baseXP * amount * 0.75) -- 75% XP per item in batch
    awardCraftXP(source, recipe, finalQuality)

    -- Track tasks
    for i = 1, amount do
        exports['free-restaurants']:IncrementTasks(source)
    end

    print(('[free-restaurants] Player %s batch crafted %dx %s'):format(
        player.PlayerData.citizenid, amount, recipeId
    ))
    
    return true, nil
end)

--- Unlock recipe callback
lib.callback.register('free-restaurants:server:unlockRecipe', function(source, recipeId)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end
    
    local recipe = Config.Recipes.Items[recipeId]
    if not recipe then return false end

    -- Check unlock requirements
    if recipe.unlockCost then
        -- Check if player has money
        if player.PlayerData.money.cash < recipe.unlockCost then
            return false, 'Not enough money'
        end
        
        player.Functions.RemoveMoney('cash', recipe.unlockCost, 'recipe-unlock')
    end
    
    -- Add to unlocked recipes
    local restaurantData = exports['free-restaurants']:GetPlayerRestaurantData(player.PlayerData.citizenid)
    restaurantData.unlockedRecipes = restaurantData.unlockedRecipes or {}
    table.insert(restaurantData.unlockedRecipes, recipeId)
    
    exports['free-restaurants']:SavePlayerRestaurantData(player.PlayerData.citizenid, restaurantData)
    
    return true, nil
end)

-- ============================================================================
-- STATION PICKUP SYSTEM
-- ============================================================================

--- Generate a unique key for pending station items
---@param locationKey string
---@param stationKey string
---@param slotIndex number
---@return string
local function getPendingItemKey(locationKey, stationKey, slotIndex)
    return ('%s:%s:%d'):format(locationKey, stationKey, slotIndex)
end

--- Store a crafted item at the station for pickup (instead of giving directly)
lib.callback.register('free-restaurants:server:storeAtStation', function(source, recipeId, quality, locationKey, stationKey, slotIndex, avgFreshness)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false, 'Player not found' end

    -- Get recipe
    local recipe = Config.Recipes.Items[recipeId]
    if not recipe then return false, 'Invalid recipe' end

    -- Calculate final quality with freshness
    local finalQuality = calculateItemQuality(quality, avgFreshness or 100)

    -- Get result item info
    local result = recipe.result
    if not result then return false, 'Recipe has no result' end

    local itemName = type(result) == 'table' and result.item or result
    local amount = type(result) == 'table' and result.amount or 1

    -- Build metadata
    local metadata = {
        quality = finalQuality,
        craftedAt = os.time(),
        craftedBy = player.PlayerData.citizenid,
    }

    -- Add freshness for food items
    if recipe.category == 'food' or recipe.isFoodItem then
        metadata.freshness = finalQuality
        metadata.decayRate = recipe.decayRate or 1.0
    end

    -- Add any custom metadata from recipe
    if recipe.metadata then
        for k, v in pairs(recipe.metadata) do
            metadata[k] = v
        end
    end

    -- Apply quality tier label
    local qualityLabel, qualityTier = getQualityInfo(finalQuality)
    metadata.qualityLabel = qualityLabel
    metadata.qualityTier = qualityTier

    -- Store pending item at station (not in player inventory yet)
    local pendingKey = getPendingItemKey(locationKey, stationKey, slotIndex)
    pendingStationItems[pendingKey] = {
        recipeId = recipeId,
        itemName = itemName,
        amount = amount,
        metadata = metadata,
        quality = finalQuality,
        craftedBy = source,
        craftedAt = os.time(),
        locationKey = locationKey,
        stationKey = stationKey,
        slotIndex = slotIndex,
        recipe = recipe,
    }

    -- Award XP immediately (crafting is done, just needs pickup)
    awardCraftXP(source, recipe, finalQuality)

    -- Add to business earnings if configured
    local session = exports['free-restaurants']:GetSession(source)
    if session and recipe.businessValue then
        exports['free-restaurants']:UpdateBusinessBalance(
            session.job,
            recipe.businessValue,
            'production',
            ('Crafted %s'):format(recipe.label),
            player.PlayerData.citizenid
        )
    end

    -- Track task completion
    exports['free-restaurants']:IncrementTasks(source)

    print(('[free-restaurants] Player %s crafted %s - stored at station %s slot %d (quality: %d)'):format(
        player.PlayerData.citizenid, recipeId, stationKey, slotIndex, finalQuality
    ))

    return true, nil
end)

--- Pick up a crafted item from the station
lib.callback.register('free-restaurants:server:pickupFromStation', function(source, locationKey, stationKey, slotIndex)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false, 'Player not found' end

    local pendingKey = getPendingItemKey(locationKey, stationKey, slotIndex)
    local pendingItem = pendingStationItems[pendingKey]

    if not pendingItem then
        return false, 'No item at this station'
    end

    -- Add item to player inventory
    local success = exports.ox_inventory:AddItem(source, pendingItem.itemName, pendingItem.amount, pendingItem.metadata)

    if not success then
        return false, 'Inventory full'
    end

    -- Clear pending item
    pendingStationItems[pendingKey] = nil

    print(('[free-restaurants] Player %s picked up %s from station %s slot %d'):format(
        player.PlayerData.citizenid, pendingItem.itemName, stationKey, slotIndex
    ))

    return true, {
        itemName = pendingItem.itemName,
        amount = pendingItem.amount,
        quality = pendingItem.quality,
        recipeLabel = pendingItem.recipe.label,
    }
end)

--- Handle burn or spill event for item at station
lib.callback.register('free-restaurants:server:handleBurnOrSpill', function(source, locationKey, stationKey, slotIndex, isBurn)
    local pendingKey = getPendingItemKey(locationKey, stationKey, slotIndex)
    local pendingItem = pendingStationItems[pendingKey]

    if not pendingItem then
        return false, 'No item at this station'
    end

    local stationType = nil
    -- Try to get station type from config
    local locationConfig = Config.Locations and Config.Locations[locationKey]
    if locationConfig and locationConfig.stations and locationConfig.stations[stationKey] then
        stationType = locationConfig.stations[stationKey].type
    end

    local stationTypeConfig = stationType and Config.Stations.Types[stationType]
    local pickupConfig = stationTypeConfig and stationTypeConfig.pickup

    local resultItem = nil
    local resultAmount = 0

    if isBurn then
        -- Item burned - give burnt item if configured
        if pickupConfig and pickupConfig.burntItem then
            resultItem = pickupConfig.burntItem
            resultAmount = 1
        end
        print(('[free-restaurants] Item %s burned at station %s slot %d'):format(
            pendingItem.itemName, stationKey, slotIndex
        ))
    else
        -- Item spilled - give spilled item if configured
        if pickupConfig and pickupConfig.spilledItem then
            resultItem = pickupConfig.spilledItem
            resultAmount = 1
        end
        print(('[free-restaurants] Item %s spilled at station %s slot %d'):format(
            pendingItem.itemName, stationKey, slotIndex
        ))
    end

    -- Give replacement item if one is configured
    if resultItem and resultAmount > 0 and source then
        local player = exports.qbx_core:GetPlayer(source)
        if player then
            exports.ox_inventory:AddItem(source, resultItem, resultAmount)
        end
    end

    -- Clear pending item (it's destroyed/burnt/spilled)
    pendingStationItems[pendingKey] = nil

    return true, {
        wasBurn = isBurn,
        replacementItem = resultItem,
    }
end)

--- Check if there's a pending item at a station slot
lib.callback.register('free-restaurants:server:getPendingItem', function(source, locationKey, stationKey, slotIndex)
    local pendingKey = getPendingItemKey(locationKey, stationKey, slotIndex)
    local pendingItem = pendingStationItems[pendingKey]

    if not pendingItem then
        return nil
    end

    return {
        recipeId = pendingItem.recipeId,
        itemName = pendingItem.itemName,
        amount = pendingItem.amount,
        quality = pendingItem.quality,
        craftedAt = pendingItem.craftedAt,
        recipeLabel = pendingItem.recipe.label,
    }
end)

--- Clear a pending item (for admin/cleanup purposes)
lib.callback.register('free-restaurants:server:clearPendingItem', function(source, locationKey, stationKey, slotIndex)
    local pendingKey = getPendingItemKey(locationKey, stationKey, slotIndex)

    if pendingStationItems[pendingKey] then
        pendingStationItems[pendingKey] = nil
        return true
    end

    return false
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('ValidateIngredients', validateIngredients)
exports('RemoveIngredients', removeIngredients)
exports('CreateCraftedItem', createCraftedItem)
exports('AwardCraftXP', awardCraftXP)
exports('CalculateLevel', calculateLevel)
exports('GetPendingStationItem', function(locationKey, stationKey, slotIndex)
    local pendingKey = getPendingItemKey(locationKey, stationKey, slotIndex)
    return pendingStationItems[pendingKey]
end)
exports('ClearPendingStationItem', function(locationKey, stationKey, slotIndex)
    local pendingKey = getPendingItemKey(locationKey, stationKey, slotIndex)
    pendingStationItems[pendingKey] = nil
end)

print('[free-restaurants] server/crafting.lua loaded')
