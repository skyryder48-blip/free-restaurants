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

-- Forward declarations for functions used before definition
local calculateLevel

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

--- Complete craft callback
lib.callback.register('free-restaurants:server:completeCraft', function(source, recipeId, quality, locationKey)
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
    
    -- Remove ingredients
    if not removeIngredients(source, recipe.ingredients) then
        return false, 'Failed to remove ingredients'
    end
    
    -- Calculate final quality with freshness
    local finalQuality = calculateItemQuality(quality, avgFreshness)
    
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

--- Craft failed callback
lib.callback.register('free-restaurants:server:craftFailed', function(source, recipeId, locationKey)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end
    
    local recipe = Config.Recipes.Items[recipeId]
    if not recipe then return false end

    -- Remove partial ingredients based on config
    local lossPercentage = Config.Cooking and Config.Cooking.Quality and Config.Cooking.Quality.ingredientWaste or 0.5
    removePartialIngredients(source, recipe.ingredients, lossPercentage)
    
    print(('[free-restaurants] Player %s failed craft: %s'):format(
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

--- Complete batch craft callback
lib.callback.register('free-restaurants:server:completeBatchCraft', function(source, recipeId, amount, locationKey)
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
    
    -- Remove all ingredients
    if not removeIngredients(source, batchIngredients) then
        return false, 'Failed to remove ingredients'
    end
    
    -- Calculate quality (batch crafting is slightly lower quality)
    local batchQualityPenalty = 0.9 -- 90% of normal quality
    local finalQuality = calculateItemQuality(batchQualityPenalty, avgFreshness)
    
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
-- EXPORTS
-- ============================================================================

exports('ValidateIngredients', validateIngredients)
exports('RemoveIngredients', removeIngredients)
exports('CreateCraftedItem', createCraftedItem)
exports('AwardCraftXP', awardCraftXP)
exports('CalculateLevel', calculateLevel)

print('[free-restaurants] server/crafting.lua loaded')
