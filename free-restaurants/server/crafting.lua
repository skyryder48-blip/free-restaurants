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
local getPendingItemKey

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
lib.callback.register('free-restaurants:server:completeBatchCraft', function(source, recipeId, amount, locationKey, avgFreshness, finalQuality)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false, 'Player not found' end

    local recipe = Config.Recipes.Items[recipeId]
    if not recipe then return false, 'Invalid recipe' end

    -- Use passed quality or calculate with penalty
    local itemQuality
    if finalQuality then
        itemQuality = calculateItemQuality(finalQuality, avgFreshness or 100)
    else
        local batchQualityPenalty = 0.9 -- 90% of normal quality
        itemQuality = calculateItemQuality(batchQualityPenalty, avgFreshness or 100)
    end

    -- Create items
    local resultItem = type(recipe.result) == 'table' and recipe.result.item or recipe.result
    local resultAmount = type(recipe.result) == 'table' and recipe.result.amount or 1
    local totalItems = resultAmount * amount

    local metadata = {
        quality = itemQuality,
        craftedAt = os.time(),
        craftedBy = player.PlayerData.citizenid,
        freshness = itemQuality,
    }

    local success = exports.ox_inventory:AddItem(source, resultItem, totalItems, metadata)
    if not success then
        return false, 'Inventory full'
    end

    -- Award XP (reduced for batch)
    local baseXP = recipe.xpReward or 10
    local batchXP = math.floor(baseXP * amount * 0.75) -- 75% XP per item in batch
    awardCraftXP(source, recipe, itemQuality)

    -- Track tasks
    for i = 1, amount do
        exports['free-restaurants']:IncrementTasks(source)
    end

    print(('[free-restaurants] Player %s batch crafted %dx %s'):format(
        player.PlayerData.citizenid, amount, recipeId
    ))

    return true, nil
end)

--- Complete multi-slot batch craft - items stay at slots for any player to pick up
lib.callback.register('free-restaurants:server:completeBatchCraftMultiSlot', function(source, recipeId, amount, locationKey, stationKey, claimedSlots, avgFreshness, finalQuality)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false, 'Player not found' end

    local recipe = Config.Recipes.Items[recipeId]
    if not recipe then return false, 'Invalid recipe' end

    -- Use passed quality or calculate
    local itemQuality
    if finalQuality then
        itemQuality = calculateItemQuality(finalQuality, avgFreshness or 100)
    else
        itemQuality = calculateItemQuality(1.0, avgFreshness or 100)
    end

    -- Get result item info
    local resultItem = type(recipe.result) == 'table' and recipe.result.item or recipe.result
    local resultAmount = type(recipe.result) == 'table' and (recipe.result.count or recipe.result.amount) or 1

    -- Build metadata
    local metadata = {
        quality = itemQuality,
        craftedAt = os.time(),
        craftedBy = player.PlayerData.citizenid,
    }

    -- Add freshness for food items
    if recipe.category == 'food' or recipe.isFoodItem then
        metadata.freshness = itemQuality
        metadata.decayRate = recipe.decayRate or 1.0
    end

    -- Apply quality tier label
    local qualityLabel, qualityTier = getQualityInfo(itemQuality)
    metadata.qualityLabel = qualityLabel
    metadata.qualityTier = qualityTier

    -- Store pending items at each slot for pickup
    local fullStationKey = ('%s_%s'):format(locationKey, stationKey)

    for i, slotIndex in ipairs(claimedSlots) do
        -- Store in pendingStationItems for server-side pickup
        local pendingKey = getPendingItemKey(locationKey, stationKey, slotIndex)
        pendingStationItems[pendingKey] = {
            recipeId = recipeId,
            itemName = resultItem,
            amount = resultAmount,
            metadata = metadata,
            quality = itemQuality,
            craftedBy = source,
            craftedByName = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname,
            craftedAt = os.time(),
            locationKey = locationKey,
            stationKey = stationKey,
            slotIndex = slotIndex,
            recipe = recipe,
            isBatchItem = true,
            batchIndex = i,
            batchTotal = amount,
        }

        -- Mark slot as ready for pickup
        exports['free-restaurants']:MarkSlotForPickup(source, locationKey, stationKey, slotIndex)

        print(('[free-restaurants] Stored batch item %d/%d at %s slot %d'):format(
            i, amount, fullStationKey, slotIndex
        ))
    end

    -- Award XP (reduced for batch)
    local baseXP = recipe.xpReward or 10
    local batchXP = math.floor(baseXP * amount * 0.75) -- 75% XP per item in batch
    awardCraftXP(source, recipe, itemQuality)

    -- Track tasks
    for i = 1, amount do
        exports['free-restaurants']:IncrementTasks(source)
    end

    print(('[free-restaurants] Player %s completed multi-slot batch: %dx %s at slots %s'):format(
        player.PlayerData.citizenid, amount, recipeId, table.concat(claimedSlots, ', ')
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
getPendingItemKey = function(locationKey, stationKey, slotIndex)
    return ('%s:%s:%d'):format(locationKey, stationKey, slotIndex)
end

--- Store a crafted item at the station for pickup (instead of giving directly)
lib.callback.register('free-restaurants:server:storeAtStation', function(source, recipeId, quality, locationKey, stationKey, slotIndex, avgFreshness)
    print(('[free-restaurants] storeAtStation called: player=%d, recipe=%s, location=%s, station=%s, slot=%d'):format(
        source, recipeId, locationKey, stationKey, slotIndex
    ))

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

    -- Mark slot as ready for pickup - this clears playerSlots so player can craft elsewhere
    -- while keeping the slot occupied for the pending item
    print(('[free-restaurants] About to call MarkSlotForPickup for player %d at %s/%s slot %d'):format(
        source, locationKey, stationKey, slotIndex
    ))
    local markResult = exports['free-restaurants']:MarkSlotForPickup(source, locationKey, stationKey, slotIndex)
    print(('[free-restaurants] MarkSlotForPickup returned: %s'):format(tostring(markResult)))

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

    -- Release the slot so it can be used again
    -- Use playerId 0 for forced release since the original crafter may have disconnected
    exports['free-restaurants']:ReleaseSlot(0, locationKey, stationKey, slotIndex, 'completed')

    -- Broadcast to ALL clients to clear their pending pickups and cleanup for this slot
    TriggerClientEvent('free-restaurants:client:slotPickedUp', -1, {
        locationKey = locationKey,
        stationKey = stationKey,
        slotIndex = slotIndex,
    })

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
--- Items remain in slot with 0 durability - must be manually cleaned up
lib.callback.register('free-restaurants:server:handleBurnOrSpill', function(source, locationKey, stationKey, slotIndex, isBurn)
    local pendingKey = getPendingItemKey(locationKey, stationKey, slotIndex)
    local pendingItem = pendingStationItems[pendingKey]

    if not pendingItem then
        return false, 'No item at this station'
    end

    local stationType = nil
    -- Try to get station type from config
    local locationConfig = nil

    -- Try direct lookup first (flat structure)
    if Config.Locations and Config.Locations[locationKey] then
        locationConfig = Config.Locations[locationKey]
    else
        -- Try nested lookup (restaurant_sublocation -> Config.Locations[restaurant][sublocation])
        local restaurant, sublocation = locationKey:match('([^_]+)_(.+)')
        if restaurant and sublocation and Config.Locations and Config.Locations[restaurant] then
            locationConfig = Config.Locations[restaurant][sublocation]
        end
    end

    if locationConfig and locationConfig.stations and locationConfig.stations[stationKey] then
        stationType = locationConfig.stations[stationKey].type
    end

    local status = isBurn and 'burnt' or 'spilled'

    -- Mark the item as ruined but KEEP IT IN THE SLOT
    -- Player must manually clean up/dispose of burnt/spilled items
    pendingItem.quality = 0
    pendingItem.durability = 0
    pendingItem.status = status
    pendingItem.ruinedAt = os.time()

    -- Update metadata to reflect ruined state
    pendingItem.metadata = pendingItem.metadata or {}
    pendingItem.metadata.quality = 0
    pendingItem.metadata.durability = 0
    pendingItem.metadata.ruined = true
    pendingItem.metadata.ruinedType = status
    pendingItem.metadata.ruinedAt = os.time()

    -- Update the slot status but keep it occupied
    exports['free-restaurants']:UpdateSlot(0, locationKey, stationKey, slotIndex, {
        status = status,
        quality = 0,
    })

    print(('[free-restaurants] Item %s %s at station %s slot %d - remains in slot for cleanup'):format(
        pendingItem.itemName, status, stationKey, slotIndex
    ))

    -- Broadcast the state change to clients
    TriggerClientEvent('free-restaurants:client:syncCookingState', -1, {
        locationKey = locationKey,
        stationKey = stationKey,
        slotIndex = slotIndex,
        status = status,
        progress = 100,
        quality = 0,
        recipeId = pendingItem.recipeId,
        recipeLabel = pendingItem.recipe and pendingItem.recipe.label or 'Ruined Item',
    })

    return true, {
        wasBurn = isBurn,
        itemRemains = true, -- Item stays in slot
        status = status,
    }
end)

--- Clean up a ruined (burnt/spilled) item from a station slot
--- This is called when player manually disposes of the ruined item
lib.callback.register('free-restaurants:server:cleanupRuinedItem', function(source, locationKey, stationKey, slotIndex)
    local pendingKey = getPendingItemKey(locationKey, stationKey, slotIndex)
    local pendingItem = pendingStationItems[pendingKey]

    if not pendingItem then
        return false, 'No item at this station'
    end

    -- Check if item is actually ruined
    if pendingItem.status ~= 'burnt' and pendingItem.status ~= 'spilled' then
        return false, 'Item is not ruined'
    end

    -- Clear pending item
    pendingStationItems[pendingKey] = nil

    -- Release the slot
    exports['free-restaurants']:ReleaseSlot(0, locationKey, stationKey, slotIndex, 'cleaned')

    -- Broadcast cleanup to all clients
    TriggerClientEvent('free-restaurants:client:slotPickedUp', -1, {
        locationKey = locationKey,
        stationKey = stationKey,
        slotIndex = slotIndex,
    })

    print(('[free-restaurants] Ruined item cleaned up at station %s slot %d by player %d'):format(
        stationKey, slotIndex, source
    ))

    return true
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
-- AUTONOMOUS COOKING SYSTEM
-- ============================================================================

-- Track active cooking sessions
-- Key format: "locationKey:stationKey:slotIndex"
local activeCookingSessions = {}

--- Get cooking session key
---@param locationKey string
---@param stationKey string
---@param slotIndex number
---@return string
local function getCookingSessionKey(locationKey, stationKey, slotIndex)
    return ('%s:%s:%d'):format(locationKey, stationKey, slotIndex)
end

--- Broadcast cooking state to all clients
---@param locationKey string
---@param stationKey string
---@param slotIndex number
---@param status string 'cooking', 'ready', 'burnt', 'cancelled'
---@param progress number 0-100
---@param data table Additional data
local function broadcastCookingState(locationKey, stationKey, slotIndex, status, progress, data)
    TriggerClientEvent('free-restaurants:client:syncCookingState', -1, {
        locationKey = locationKey,
        stationKey = stationKey,
        slotIndex = slotIndex,
        status = status,
        progress = progress,
        recipeId = data.recipeId,
        recipeLabel = data.recipeLabel,
        quality = data.quality,
        startTime = data.startTime,
        endTime = data.endTime,
        craftedBy = data.craftedBy,
    })
end

--- Complete autonomous cooking - called when timer finishes
---@param sessionKey string The cooking session key
local function completeAutonomousCooking(sessionKey)
    local session = activeCookingSessions[sessionKey]
    if not session then return end

    local recipe = Config.Recipes.Items[session.recipeId]
    if not recipe then
        activeCookingSessions[sessionKey] = nil
        return
    end

    -- Calculate final quality with freshness
    local finalQuality = calculateItemQuality(session.quality, session.avgFreshness or 100)

    -- Get result item info
    local result = recipe.result
    local itemName = type(result) == 'table' and result.item or result
    local amount = type(result) == 'table' and (result.amount or result.count) or 1

    -- Build metadata
    local metadata = {
        quality = finalQuality,
        craftedAt = os.time(),
        craftedBy = session.craftedByCid,
    }

    -- Add freshness for food items
    if recipe.category == 'food' or recipe.isFoodItem then
        metadata.freshness = finalQuality
        metadata.decayRate = recipe.decayRate or 1.0
    end

    -- Apply quality tier label
    local qualityLabel, qualityTier = getQualityInfo(finalQuality)
    metadata.qualityLabel = qualityLabel
    metadata.qualityTier = qualityTier

    -- Store pending item at station for pickup
    local pendingKey = getPendingItemKey(session.locationKey, session.stationKey, session.slotIndex)
    pendingStationItems[pendingKey] = {
        recipeId = session.recipeId,
        itemName = itemName,
        amount = amount,
        metadata = metadata,
        quality = finalQuality,
        craftedBy = session.craftedBy,
        craftedByCid = session.craftedByCid,
        craftedByName = session.craftedByName,
        craftedAt = os.time(),
        locationKey = session.locationKey,
        stationKey = session.stationKey,
        slotIndex = session.slotIndex,
        recipe = recipe,
    }

    -- Mark slot as ready for pickup
    exports['free-restaurants']:MarkSlotForPickup(session.craftedBy, session.locationKey, session.stationKey, session.slotIndex)

    -- Award XP
    if session.craftedBy and GetPlayerName(session.craftedBy) then
        awardCraftXP(session.craftedBy, recipe, finalQuality)
        exports['free-restaurants']:IncrementTasks(session.craftedBy)
    end

    -- Broadcast cooking complete to all clients
    broadcastCookingState(session.locationKey, session.stationKey, session.slotIndex, 'ready', 100, {
        recipeId = session.recipeId,
        recipeLabel = recipe.label,
        quality = finalQuality,
        startTime = session.startTime,
        endTime = os.time() * 1000,
        craftedBy = session.craftedBy,
    })

    -- Notify the player who started the cooking (if still online)
    if session.craftedBy and GetPlayerName(session.craftedBy) then
        TriggerClientEvent('free-restaurants:client:cookingFinished', session.craftedBy, {
            recipeId = session.recipeId,
            recipeLabel = recipe.label,
            locationKey = session.locationKey,
            stationKey = session.stationKey,
            slotIndex = session.slotIndex,
            quality = finalQuality,
        })
    end

    print(('[free-restaurants] Autonomous cooking complete: %s at %s/%s slot %d (quality: %d)'):format(
        session.recipeId, session.locationKey, session.stationKey, session.slotIndex, finalQuality
    ))

    -- Clear the cooking session
    activeCookingSessions[sessionKey] = nil
end

--- Start autonomous cooking for a single slot
lib.callback.register('free-restaurants:server:startAutonomousCooking', function(source, data)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end

    local recipe = Config.Recipes.Items[data.recipeId]
    if not recipe then return false end

    local sessionKey = getCookingSessionKey(data.locationKey, data.stationKey, data.slotIndex)

    -- Check if slot is already cooking
    if activeCookingSessions[sessionKey] then
        return false
    end

    local craftTime = data.craftTime or 10000  -- Default 10 seconds

    -- Store cooking session
    activeCookingSessions[sessionKey] = {
        recipeId = data.recipeId,
        locationKey = data.locationKey,
        stationKey = data.stationKey,
        slotIndex = data.slotIndex,
        quality = data.quality or 1.0,
        avgFreshness = data.avgFreshness or 100,
        craftTime = craftTime,
        startTime = os.time() * 1000,
        endTime = (os.time() * 1000) + craftTime,
        craftedBy = source,
        craftedByCid = player.PlayerData.citizenid,
        craftedByName = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname,
    }

    -- Broadcast cooking started to all clients
    broadcastCookingState(data.locationKey, data.stationKey, data.slotIndex, 'cooking', 0, {
        recipeId = data.recipeId,
        recipeLabel = recipe.label,
        quality = data.quality,
        startTime = activeCookingSessions[sessionKey].startTime,
        endTime = activeCookingSessions[sessionKey].endTime,
        craftedBy = source,
    })

    -- Start timer for cooking completion
    SetTimeout(craftTime, function()
        completeAutonomousCooking(sessionKey)
    end)

    print(('[free-restaurants] Started autonomous cooking: %s at %s/%s slot %d (time: %dms)'):format(
        data.recipeId, data.locationKey, data.stationKey, data.slotIndex, craftTime
    ))

    return true
end)

--- Start autonomous cooking for multiple slots (batch)
lib.callback.register('free-restaurants:server:startBatchAutonomousCooking', function(source, data)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end

    local recipe = Config.Recipes.Items[data.recipeId]
    if not recipe then return false end

    local craftTime = data.craftTime or 10000
    local slots = data.slots or {}

    if #slots == 0 then return false end

    -- Start cooking for each slot
    for i, slotIndex in ipairs(slots) do
        local sessionKey = getCookingSessionKey(data.locationKey, data.stationKey, slotIndex)

        -- Check if slot is already cooking
        if activeCookingSessions[sessionKey] then
            print(('[free-restaurants] Slot %d already cooking, skipping'):format(slotIndex))
        else
            -- Store cooking session
            activeCookingSessions[sessionKey] = {
                recipeId = data.recipeId,
                locationKey = data.locationKey,
                stationKey = data.stationKey,
                slotIndex = slotIndex,
                quality = data.quality or 1.0,
                avgFreshness = data.avgFreshness or 100,
                craftTime = craftTime,
                startTime = os.time() * 1000,
                endTime = (os.time() * 1000) + craftTime,
                craftedBy = source,
                craftedByCid = player.PlayerData.citizenid,
                craftedByName = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname,
                isBatchItem = true,
                batchIndex = i,
                batchTotal = #slots,
            }

            -- Broadcast cooking started
            broadcastCookingState(data.locationKey, data.stationKey, slotIndex, 'cooking', 0, {
                recipeId = data.recipeId,
                recipeLabel = recipe.label,
                quality = data.quality,
                startTime = activeCookingSessions[sessionKey].startTime,
                endTime = activeCookingSessions[sessionKey].endTime,
                craftedBy = source,
            })

            -- Start timer for this slot's cooking completion
            local capturedSessionKey = sessionKey
            SetTimeout(craftTime, function()
                completeAutonomousCooking(capturedSessionKey)
            end)
        end
    end

    print(('[free-restaurants] Started batch autonomous cooking: %dx %s at %s/%s (time: %dms)'):format(
        #slots, data.recipeId, data.locationKey, data.stationKey, craftTime
    ))

    return true
end)

--- Get current cooking state for a slot (for late-joining players)
lib.callback.register('free-restaurants:server:getCookingState', function(source, locationKey, stationKey, slotIndex)
    local sessionKey = getCookingSessionKey(locationKey, stationKey, slotIndex)
    local session = activeCookingSessions[sessionKey]

    if not session then
        -- Check if there's a pending item (cooking finished)
        local pendingKey = getPendingItemKey(locationKey, stationKey, slotIndex)
        local pending = pendingStationItems[pendingKey]
        if pending then
            return {
                status = 'ready',
                recipeId = pending.recipeId,
                recipeLabel = pending.recipe.label,
                quality = pending.quality,
            }
        end
        return nil
    end

    local now = os.time() * 1000
    local progress = math.floor(((now - session.startTime) / session.craftTime) * 100)
    progress = math.min(100, math.max(0, progress))

    local recipe = Config.Recipes.Items[session.recipeId]

    return {
        status = 'cooking',
        recipeId = session.recipeId,
        recipeLabel = recipe and recipe.label or session.recipeId,
        quality = session.quality,
        progress = progress,
        startTime = session.startTime,
        endTime = session.endTime,
        craftedBy = session.craftedBy,
        craftedByName = session.craftedByName,
    }
end)

--- Cancel cooking (e.g., if station is damaged or admin action)
lib.callback.register('free-restaurants:server:cancelCooking', function(source, locationKey, stationKey, slotIndex)
    local sessionKey = getCookingSessionKey(locationKey, stationKey, slotIndex)
    local session = activeCookingSessions[sessionKey]

    if not session then
        return false, 'No active cooking at this slot'
    end

    -- Broadcast cancellation
    broadcastCookingState(locationKey, stationKey, slotIndex, 'cancelled', 0, {
        recipeId = session.recipeId,
        recipeLabel = '',
        quality = 0,
        startTime = session.startTime,
        endTime = os.time() * 1000,
        craftedBy = session.craftedBy,
    })

    -- Release the slot
    exports['free-restaurants']:ReleaseSlot(0, locationKey, stationKey, slotIndex, 'cancelled')

    -- Clear the session
    activeCookingSessions[sessionKey] = nil

    return true
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

-- ============================================================================
-- FIRE MANAGEMENT & DISPATCH INTEGRATION
-- ============================================================================

-- Track active fires for dispatch integration
local activeFires = {}

-- Register fire started (called from client via server event)
RegisterNetEvent('free-restaurants:server:fireStarted', function(data)
    if not data then return end

    local fireKey = ('%s_%d'):format(data.stationKey, data.slotIndex)
    local source = source

    activeFires[fireKey] = {
        stationKey = data.stationKey,
        slotIndex = data.slotIndex,
        coords = data.coords,
        stage = data.stage or 1,
        fireConfig = data.fireConfig,
        startTime = os.time(),
        reportedBy = source,
    }

    -- Trigger dispatch notification for emergency services
    TriggerEvent('free-restaurants:server:dispatchFireAlert', {
        fireKey = fireKey,
        coords = data.coords,
        stationKey = data.stationKey,
        slotIndex = data.slotIndex,
        fireType = data.fireConfig and data.fireConfig.type or 'regular',
        severity = data.stage or 1,
    })

    print(('[free-restaurants] Fire started: %s (type: %s)'):format(
        fireKey, data.fireConfig and data.fireConfig.type or 'unknown'
    ))
end)

-- Register fire extinguished
RegisterNetEvent('free-restaurants:server:fireExtinguished', function(data)
    if not data then return end

    local fireKey = ('%s_%d'):format(data.stationKey, data.slotIndex)

    if activeFires[fireKey] then
        activeFires[fireKey] = nil

        -- Notify dispatch that fire is out
        TriggerEvent('free-restaurants:server:dispatchFireCleared', {
            fireKey = fireKey,
            stationKey = data.stationKey,
            slotIndex = data.slotIndex,
        })

        print(('[free-restaurants] Fire extinguished: %s'):format(fireKey))
    end
end)

-- ============================================================================
-- DISPATCH EXPORTS (For integration with dispatch scripts)
-- ============================================================================

-- Get all active fires
exports('GetActiveFires', function()
    return activeFires
end)

-- Get fire count
exports('GetActiveFireCount', function()
    local count = 0
    for _ in pairs(activeFires) do
        count = count + 1
    end
    return count
end)

-- Get fire by key
exports('GetFire', function(fireKey)
    return activeFires[fireKey]
end)

-- Get fires near coordinates
exports('GetFiresNearCoords', function(coords, radius)
    radius = radius or 50.0
    local nearbyFires = {}

    for fireKey, fire in pairs(activeFires) do
        if fire.coords then
            local distance = #(vector3(coords.x, coords.y, coords.z) - vector3(fire.coords.x, fire.coords.y, fire.coords.z))
            if distance <= radius then
                nearbyFires[fireKey] = fire
                nearbyFires[fireKey].distance = distance
            end
        end
    end

    return nearbyFires
end)

-- Notify dispatch of fire (can be called externally)
exports('NotifyDispatchFire', function(fireKey, additionalData)
    local fire = activeFires[fireKey]
    if not fire then return false end

    TriggerEvent('free-restaurants:server:dispatchFireAlert', {
        fireKey = fireKey,
        coords = fire.coords,
        stationKey = fire.stationKey,
        slotIndex = fire.slotIndex,
        fireType = fire.fireConfig and fire.fireConfig.type or 'regular',
        severity = fire.stage or 1,
        additionalData = additionalData,
    })

    return true
end)

-- Clear fire by key (server-side, broadcasts to all clients)
exports('ClearFire', function(fireKey)
    local fire = activeFires[fireKey]
    if not fire then return false end

    -- Broadcast to all clients to stop the fire
    TriggerClientEvent('free-restaurants:client:adminClearFire', -1, {
        stationKey = fire.stationKey,
        slotIndex = fire.slotIndex,
    })

    activeFires[fireKey] = nil
    return true
end)

-- Clear all fires
exports('ClearAllFires', function()
    local count = 0
    for fireKey, fire in pairs(activeFires) do
        TriggerClientEvent('free-restaurants:client:adminClearFire', -1, {
            stationKey = fire.stationKey,
            slotIndex = fire.slotIndex,
        })
        count = count + 1
    end
    activeFires = {}
    return count
end)

-- ============================================================================
-- ADMIN COMMANDS
-- ============================================================================

-- Admin command to clear fires
lib.addCommand('clearfires', {
    help = 'Clear all restaurant fires (Admin only)',
    params = {
        { name = 'location', type = 'string', help = 'Location key (optional, leave blank for all)', optional = true },
    },
    restricted = 'group.admin',
}, function(source, args)
    local locationFilter = args.location

    if locationFilter then
        -- Clear fires at specific location
        local count = 0
        for fireKey, fire in pairs(activeFires) do
            if fire.stationKey and fire.stationKey:find(locationFilter) then
                TriggerClientEvent('free-restaurants:client:adminClearFire', -1, {
                    stationKey = fire.stationKey,
                    slotIndex = fire.slotIndex,
                })
                activeFires[fireKey] = nil
                count = count + 1
            end
        end

        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Fires Cleared',
            description = ('Cleared %d fires at %s'):format(count, locationFilter),
            type = 'success',
        })
    else
        -- Clear all fires
        local count = exports['free-restaurants']:ClearAllFires()

        TriggerClientEvent('ox_lib:notify', source, {
            title = 'All Fires Cleared',
            description = ('Cleared %d fires'):format(count),
            type = 'success',
        })
    end
end)

-- Admin command to list active fires
lib.addCommand('listfires', {
    help = 'List all active restaurant fires (Admin only)',
    restricted = 'group.admin',
}, function(source, args)
    local count = 0
    local fireList = {}

    for fireKey, fire in pairs(activeFires) do
        count = count + 1
        table.insert(fireList, ('%s (stage %d, %s)'):format(
            fireKey,
            fire.stage or 1,
            fire.fireConfig and fire.fireConfig.type or 'regular'
        ))
    end

    if count > 0 then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Active Fires: ' .. count,
            description = table.concat(fireList, '\n'),
            type = 'warning',
            duration = 10000,
        })
    else
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'No Active Fires',
            description = 'All clear!',
            type = 'success',
        })
    end
end)

-- ============================================================================
-- CONSUMPTION SYSTEM
-- ============================================================================

--- Handle item consumption from client
--- Removes the item after player consumes it
RegisterNetEvent('free-restaurants:server:consumeItem', function(data)
    local source = source
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end

    if not data or not data.itemName then
        TriggerClientEvent('free-restaurants:client:consumptionComplete', source, {
            success = false,
            error = 'Invalid consumption data',
        })
        return
    end

    local itemName = data.itemName
    local slot = data.slot
    local usesConsumed = data.usesConsumed or 1
    local totalUses = data.totalUses or 1
    local partial = data.partial

    -- For partial consumption, we could implement partial item durability
    -- For now, if any uses were consumed, remove the whole item
    if usesConsumed > 0 then
        local success = exports.ox_inventory:RemoveItem(source, itemName, 1, nil, slot)

        if success then
            print(('[free-restaurants] Player %s consumed %s (%d/%d uses)'):format(
                player.PlayerData.citizenid, itemName, usesConsumed, totalUses
            ))

            TriggerClientEvent('free-restaurants:client:consumptionComplete', source, {
                success = true,
                itemName = itemName,
                usesConsumed = usesConsumed,
                partial = partial,
            })
        else
            TriggerClientEvent('free-restaurants:client:consumptionComplete', source, {
                success = false,
                error = 'Failed to remove item from inventory',
            })
        end
    end
end)

--- Get item effects configuration for client
--- This allows server to validate consumption
lib.callback.register('free-restaurants:server:getItemEffects', function(source, itemName)
    -- In production, you might want server-side effect validation
    -- For now, we trust the client-side Config.ItemEffects
    return true
end)

print('[free-restaurants] server/crafting.lua loaded')
