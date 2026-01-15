--[[
    free-restaurants Server Decay System

    Handles:
    - Food freshness decay over time
    - Quality degradation
    - Spoiled item handling
    - Storage-based decay modifiers (refrigerator/freezer)
    - Realistic decay rates by food category

    DEPENDENCIES:
    - ox_inventory
    - config/item_effects.lua (for food item detection)
]]

print('[free-restaurants] server/decay.lua loading...')

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

local DecayConfig = {
    -- How often to process decay (milliseconds)
    updateInterval = 60000, -- 1 minute

    -- Base decay rate per hour (percentage of freshness lost)
    baseDecayRate = 2.0, -- 2% per hour baseline

    -- Decay modifiers by storage type
    storageModifiers = {
        player = 1.0,           -- Normal decay in player inventory
        ground = 1.5,           -- Faster decay on ground/dropped
        stash = 0.9,            -- Slightly slower in regular storage
        counter = 1.0,          -- Normal on counter/display
        refrigerator = 0.25,    -- 75% slower in refrigerator (cold)
        fridge = 0.25,          -- Alias for refrigerator
        freezer = 0.05,         -- 95% slower in freezer (frozen)
        cooler = 0.4,           -- 60% slower in cooler (ice)
        heated = 1.5,           -- 50% faster near heat sources
    },

    -- Minimum freshness before item is considered spoiled
    spoiledThreshold = 10,

    -- What happens to spoiled items
    spoiledAction = 'degrade', -- 'remove', 'degrade', or 'keep'

    -- Time before freshness starts decaying (grace period in hours)
    freshnesGracePeriod = 0.5, -- 30 minutes before decay starts
}

-- ============================================================================
-- REALISTIC DECAY RATES BY FOOD CATEGORY
-- ============================================================================

-- Decay rate multipliers by food type (higher = spoils faster)
local FoodCategoryDecayRates = {
    -- RAW INGREDIENTS (spoil fastest)
    raw_meat = 4.0,           -- Raw beef, chicken, fish - spoils in ~6 hours at room temp
    raw_seafood = 5.0,        -- Raw fish, shellfish - spoils even faster
    raw_poultry = 4.5,        -- Raw chicken - very perishable
    raw_eggs = 2.0,           -- Eggs - moderate shelf life

    -- DAIRY (spoils relatively fast)
    dairy_milk = 3.0,         -- Milk - spoils in ~8 hours unrefrigerated
    dairy_cream = 3.5,        -- Cream - slightly faster
    dairy_cheese_soft = 2.5,  -- Soft cheese - moderate
    dairy_cheese_hard = 1.0,  -- Hard cheese - lasts longer
    dairy_butter = 1.5,       -- Butter - moderate
    dairy_yogurt = 2.5,       -- Yogurt - moderate

    -- FRESH PRODUCE (variable decay)
    produce_leafy = 3.0,      -- Lettuce, spinach - wilts fast
    produce_tomato = 2.0,     -- Tomatoes - moderate
    produce_onion = 0.5,      -- Onions - very long shelf life
    produce_potato = 0.4,     -- Potatoes - very long shelf life
    produce_fruit = 2.0,      -- Most fruits - moderate
    produce_berries = 3.5,    -- Berries - spoil fast
    produce_citrus = 1.0,     -- Citrus - good shelf life
    produce_avocado = 2.5,    -- Avocados - ripen/spoil quickly

    -- COOKED FOODS (moderate decay)
    cooked_meat = 2.0,        -- Cooked meat dishes - ~12 hours at room temp
    cooked_seafood = 2.5,     -- Cooked seafood - slightly faster
    cooked_poultry = 2.0,     -- Cooked chicken
    cooked_vegetables = 1.5,  -- Cooked veggies
    cooked_pasta = 1.8,       -- Pasta dishes
    cooked_rice = 2.0,        -- Rice dishes
    cooked_soup = 2.0,        -- Soups/stews

    -- PREPARED/ASSEMBLED FOODS
    burger = 2.0,             -- Assembled burgers
    sandwich = 2.5,           -- Sandwiches - bread gets soggy
    pizza = 1.5,              -- Pizza - lasts reasonably well
    taco = 2.5,               -- Tacos - lettuce wilts
    salad = 3.0,              -- Salads - dressing, greens spoil fast
    wrap = 2.0,               -- Wraps/burritos

    -- FRIED FOODS
    fried = 1.5,              -- Fried foods - lose crispness but safe longer
    fries = 2.0,              -- Fries - get soggy/stale

    -- BAKED GOODS
    baked_bread = 1.0,        -- Bread - stales but safe
    baked_pastry = 1.5,       -- Pastries - cream filling spoils
    baked_cake = 2.0,         -- Cakes with frosting
    baked_cookie = 0.5,       -- Cookies - very long shelf life

    -- DESSERTS
    dessert_ice_cream = 5.0,  -- Ice cream - melts fast!
    dessert_custard = 3.0,    -- Custard/pudding
    dessert_fruit = 2.5,      -- Fruit desserts

    -- BEVERAGES
    beverage_coffee = 1.0,    -- Coffee - gets stale/cold
    beverage_juice = 2.5,     -- Fresh juice - ferments
    beverage_smoothie = 3.0,  -- Smoothies - separate/ferment
    beverage_soda = 0.1,      -- Soda - almost never spoils
    beverage_water = 0.05,    -- Water - essentially never spoils
    beverage_alcohol = 0.05,  -- Alcohol - preserves itself

    -- CONDIMENTS/SAUCES
    sauce = 0.5,              -- Most sauces - long shelf life
    sauce_dairy = 2.0,        -- Cream-based sauces
    sauce_fresh = 2.5,        -- Fresh salsas/guac

    -- DEFAULT
    default = 1.5,            -- Default for unspecified items
}

-- ============================================================================
-- ITEM CATEGORY MAPPING
-- ============================================================================

-- Map specific items to their decay category
local ItemDecayCategories = {
    -- Raw meats
    ['patty_raw'] = 'raw_meat',
    ['beef_raw'] = 'raw_meat',
    ['steak_raw'] = 'raw_meat',
    ['bacon_raw'] = 'raw_meat',
    ['ground_beef'] = 'raw_meat',

    -- Raw poultry
    ['chicken_raw'] = 'raw_poultry',
    ['chicken_breast'] = 'raw_poultry',
    ['chicken_wing'] = 'raw_poultry',
    ['turkey_raw'] = 'raw_poultry',

    -- Raw seafood
    ['fish_raw'] = 'raw_seafood',
    ['salmon_raw'] = 'raw_seafood',
    ['shrimp_raw'] = 'raw_seafood',
    ['tuna_raw'] = 'raw_seafood',

    -- Dairy
    ['milk'] = 'dairy_milk',
    ['cream'] = 'dairy_cream',
    ['cheese'] = 'dairy_cheese_soft',
    ['cheddar'] = 'dairy_cheese_hard',
    ['mozzarella'] = 'dairy_cheese_soft',
    ['butter'] = 'dairy_butter',
    ['eggs'] = 'raw_eggs',
    ['yogurt'] = 'dairy_yogurt',

    -- Fresh produce
    ['lettuce'] = 'produce_leafy',
    ['spinach'] = 'produce_leafy',
    ['tomato'] = 'produce_tomato',
    ['onion'] = 'produce_onion',
    ['potato'] = 'produce_potato',
    ['jalapeño'] = 'produce_fruit',
    ['avocado'] = 'produce_avocado',
    ['lime'] = 'produce_citrus',
    ['lemon'] = 'produce_citrus',

    -- Cooked items - burgers
    ['bleeder_burger'] = 'burger',
    ['bleeder_burger_premium'] = 'burger',
    ['double_barreled_burger'] = 'burger',
    ['heart_stopper_burger'] = 'burger',
    ['murder_burger'] = 'burger',

    -- Cooked items - sides
    ['fries'] = 'fries',
    ['curly_fries'] = 'fries',
    ['onion_rings'] = 'fried',
    ['chicken_nuggets'] = 'fried',

    -- Pizza
    ['pizza_slice_cheese'] = 'pizza',
    ['pizza_slice_pepperoni'] = 'pizza',
    ['pizza_whole'] = 'pizza',

    -- Mexican
    ['taco'] = 'taco',
    ['burrito'] = 'wrap',
    ['nachos'] = 'fried',
    ['guacamole'] = 'sauce_fresh',
    ['salsa'] = 'sauce_fresh',

    -- Desserts
    ['ice_cream'] = 'dessert_ice_cream',
    ['donut'] = 'baked_pastry',
    ['cake'] = 'baked_cake',
    ['cookie'] = 'baked_cookie',

    -- Beverages
    ['coffee'] = 'beverage_coffee',
    ['espresso'] = 'beverage_coffee',
    ['latte'] = 'beverage_coffee',
    ['ecola'] = 'beverage_soda',
    ['sprunk'] = 'beverage_soda',
    ['water'] = 'beverage_water',
    ['beer'] = 'beverage_alcohol',
    ['whiskey'] = 'beverage_alcohol',
    ['cocktail_margarita'] = 'beverage_alcohol',
    ['energy_drink'] = 'beverage_soda',
    ['smoothie'] = 'beverage_smoothie',
    ['juice'] = 'beverage_juice',
}

-- ============================================================================
-- FREEZER/REFRIGERATOR COMPATIBILITY
-- ============================================================================

-- Items that should NOT be stored in freezer (texture/quality damage)
local FreezerIncompatible = {
    ['lettuce'] = true,
    ['tomato'] = true,
    ['eggs'] = true,           -- Shells crack
    ['milk'] = true,           -- Separates
    ['cream'] = true,          -- Texture ruined
    ['yogurt'] = true,
    ['avocado'] = true,
    ['cucumber'] = true,
    ['mayonnaise'] = true,
}

-- Items that benefit from refrigeration
local RefrigerationBenefits = {
    -- Dairy
    dairy_milk = true,
    dairy_cream = true,
    dairy_cheese_soft = true,
    dairy_cheese_hard = true,
    dairy_butter = true,
    dairy_yogurt = true,
    raw_eggs = true,
    -- Raw meats
    raw_meat = true,
    raw_poultry = true,
    raw_seafood = true,
    -- Produce
    produce_leafy = true,
    produce_tomato = true,
    produce_fruit = true,
    produce_berries = true,
    -- Cooked foods
    cooked_meat = true,
    cooked_seafood = true,
    cooked_poultry = true,
    -- Prepared foods
    burger = true,
    sandwich = true,
    pizza = true,
    taco = true,
    salad = true,
    -- Sauces
    sauce_dairy = true,
    sauce_fresh = true,
    -- Beverages
    beverage_juice = true,
    beverage_smoothie = true,
    dairy_coffee = true,
}

-- Items that benefit from freezing
local FreezerBenefits = {
    raw_meat = true,
    raw_poultry = true,
    raw_seafood = true,
    cooked_meat = true,
    cooked_poultry = true,
    cooked_seafood = true,
    dessert_ice_cream = true,
    baked_bread = true,        -- Bread freezes well
}

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

local function tableCount(tbl)
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
end

--- Get decay category for an item
---@param itemName string
---@return string category
local function getItemDecayCategory(itemName)
    return ItemDecayCategories[itemName] or 'default'
end

--- Get decay rate for an item
---@param itemName string
---@return number decayRate
local function getItemDecayRate(itemName)
    local category = getItemDecayCategory(itemName)
    return FoodCategoryDecayRates[category] or FoodCategoryDecayRates.default
end

--- Check if item is a food item that decays
---@param itemName string
---@return boolean isFood
local function isFoodItem(itemName)
    -- Check item effects config
    if Config.ItemEffects and Config.ItemEffects.Items and Config.ItemEffects.Items[itemName] then
        return true
    end

    -- Check if it has a decay category
    if ItemDecayCategories[itemName] then
        return true
    end

    -- Check decayable items list
    if decayableItems and decayableItems[itemName] then
        return true
    end

    return false
end

--- Check if storage provides refrigeration benefit for item
---@param itemName string
---@param storageType string
---@return boolean benefitsFromStorage
---@return number decayModifier
local function getStorageEffect(itemName, storageType)
    -- Non-food items don't benefit from refrigeration
    if not isFoodItem(itemName) then
        return false, 1.0
    end

    local category = getItemDecayCategory(itemName)

    if storageType == 'freezer' then
        -- Check if item should not be frozen
        if FreezerIncompatible[itemName] then
            -- Freezing damages these items - give penalty
            return false, 2.0  -- Faster decay (damage)
        end

        -- Check if item benefits from freezing
        if FreezerBenefits[category] then
            return true, DecayConfig.storageModifiers.freezer
        else
            -- Item doesn't really benefit but doesn't hurt
            return false, DecayConfig.storageModifiers.refrigerator
        end

    elseif storageType == 'refrigerator' or storageType == 'fridge' then
        -- Check if item benefits from refrigeration
        if RefrigerationBenefits[category] then
            return true, DecayConfig.storageModifiers.refrigerator
        else
            -- Neutral - some items don't need refrigeration
            return false, 1.0
        end

    elseif storageType == 'cooler' then
        -- Coolers help most perishables
        if RefrigerationBenefits[category] then
            return true, DecayConfig.storageModifiers.cooler
        end
    end

    -- Default storage modifier
    local modifier = DecayConfig.storageModifiers[storageType] or 1.0
    return false, modifier
end

-- Track which items should decay
local decayableItems = {}

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

--- Build list of decayable items from recipes and effects config
local function initializeDecayableItems()
    -- Add all food items from item effects config
    if Config.ItemEffects and Config.ItemEffects.Items then
        for itemName, config in pairs(Config.ItemEffects.Items) do
            local category = getItemDecayCategory(itemName)
            decayableItems[itemName] = {
                decayRate = getItemDecayRate(itemName),
                category = category,
            }
        end
    end

    -- Add all food items from recipes
    if Config.Recipes and Config.Recipes.Items then
        for recipeId, recipe in pairs(Config.Recipes.Items) do
            if recipe.isFoodItem or recipe.category == 'food' or recipe.category == 'drinks' then
                local resultItem = type(recipe.result) == 'table' and recipe.result.item or recipe.result
                if resultItem and not decayableItems[resultItem] then
                    local category = getItemDecayCategory(resultItem)
                    decayableItems[resultItem] = {
                        decayRate = recipe.decayRate or getItemDecayRate(resultItem),
                        category = category,
                        spoiledItem = recipe.spoiledItem,
                    }
                end
            end
        end
    end

    -- Add raw ingredients
    local ingredients = {
        'patty_raw', 'chicken_raw', 'fish_raw', 'lettuce', 'tomato',
        'cheese', 'milk', 'cream', 'eggs', 'butter', 'bacon_raw',
        'onion', 'potato', 'jalapeño', 'avocado', 'lime', 'lemon',
    }

    for _, item in ipairs(ingredients) do
        if not decayableItems[item] then
            local category = getItemDecayCategory(item)
            decayableItems[item] = {
                decayRate = getItemDecayRate(item),
                category = category,
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
---@param storageType string Type of storage
---@return table|nil updatedItem Updated item or nil if spoiled
local function processItemDecay(item, decayRate, timeElapsed, storageType)
    if not item.metadata then return item end

    local freshness = item.metadata.freshness
    if not freshness then return item end

    -- Check grace period for newly crafted items
    local craftedAt = item.metadata.craftedAt or 0
    local ageHours = (os.time() - craftedAt) / 3600
    if ageHours < DecayConfig.freshnesGracePeriod then
        return item -- Don't decay yet
    end

    -- Get storage-specific modifier for this item
    local _, storageModifier = getStorageEffect(item.name, storageType or 'player')

    -- Calculate total decay amount
    local totalDecayRate = DecayConfig.baseDecayRate * decayRate * storageModifier
    local decayAmount = totalDecayRate * timeElapsed
    local newFreshness = math.max(0, freshness - decayAmount)

    -- Update metadata
    item.metadata.freshness = newFreshness
    item.metadata.lastDecay = os.time()

    -- Also degrade quality proportionally
    if item.metadata.quality then
        local qualityLoss = (freshness - newFreshness) * 0.5 -- Quality degrades at half rate
        item.metadata.quality = math.max(0, item.metadata.quality - qualityLoss)
    end

    -- Check if spoiled
    if newFreshness <= DecayConfig.spoiledThreshold then
        item.metadata.spoiled = true
        item.metadata.spoiledAt = os.time()

        -- Update quality tier
        item.metadata.qualityLabel = 'Spoiled'
        item.metadata.qualityTier = 'spoiled'

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
                    decayConfig.decayRate,
                    timeElapsed,
                    'player' -- Player inventory
                )

                if updatedItem then
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

    -- Remove spoiled items (if configured)
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

--- Determine storage type from stash ID and config
---@param stashId string
---@param storageData table|nil
---@return string storageType
local function determineStorageType(stashId, storageData)
    -- Check explicit storage type in config
    if storageData and storageData.storageType then
        return storageData.storageType
    end

    -- Check by name patterns
    local lowerStashId = stashId:lower()

    if lowerStashId:match('freezer') or lowerStashId:match('frozen') then
        return 'freezer'
    elseif lowerStashId:match('fridge') or lowerStashId:match('refrigerat') or lowerStashId:match('cooler') then
        return 'refrigerator'
    elseif lowerStashId:match('heated') or lowerStashId:match('warmer') then
        return 'heated'
    elseif lowerStashId:match('counter') or lowerStashId:match('display') then
        return 'counter'
    end

    return 'stash' -- Default storage type
end

--- Process decay for a stash
---@param stashId string Stash identifier
---@param storageType? string Type of storage for modifier
---@param storageData? table Storage configuration data
local function processStashDecay(stashId, storageType, storageData)
    local items = exports.ox_inventory:GetInventoryItems(stashId)
    if not items then return end

    -- Determine storage type if not provided
    storageType = storageType or determineStorageType(stashId, storageData)

    local currentTime = os.time()
    local updates = {}
    local removals = {}

    for slot, item in pairs(items) do
        if item and item.name then
            -- Check if item is a food item that decays
            local decayConfig = decayableItems[item.name]

            if decayConfig then
                local lastDecay = item.metadata and item.metadata.lastDecay or currentTime
                local timeElapsed = (currentTime - lastDecay) / 3600

                if timeElapsed > 0 then
                    local updatedItem = processItemDecay(
                        item,
                        decayConfig.decayRate,
                        timeElapsed,
                        storageType
                    )

                    if updatedItem then
                        updates[slot] = updatedItem.metadata
                    else
                        table.insert(removals, { slot = slot, item = item })
                    end
                end
            end
            -- Non-food items are not affected by refrigeration and don't decay
        end
    end

    -- Apply updates
    for slot, metadata in pairs(updates) do
        exports.ox_inventory:SetMetadata(stashId, slot, metadata)
    end

    -- Remove spoiled items (if configured)
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
            if player and player.PlayerData then
                processPlayerDecay(player.PlayerData.source)
            end
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

                            -- Determine storage type from config or ID
                            local storageType = determineStorageType(storageId, storageData)

                            processStashDecay(stashId, storageType, storageData)
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
            if item.metadata then
                table.insert(freshnessList, {
                    slot = slot,
                    count = item.count,
                    freshness = item.metadata.freshness or 100,
                    quality = item.metadata.quality or 100,
                    spoiled = item.metadata.spoiled,
                    usesRemaining = item.metadata.usesRemaining,
                    depleted = item.metadata.depleted,
                })
            end
        end
    end

    return freshnessList
end)

--- Get item decay info
lib.callback.register('free-restaurants:server:getItemDecayInfo', function(source, itemName)
    local decayConfig = decayableItems[itemName]
    if not decayConfig then
        return nil
    end

    return {
        decayRate = decayConfig.decayRate,
        category = decayConfig.category,
        baseHoursToSpoil = 100 / (DecayConfig.baseDecayRate * decayConfig.decayRate),
    }
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
exports('GetItemDecayRate', getItemDecayRate)
exports('GetItemDecayCategory', getItemDecayCategory)
exports('IsFoodItem', isFoodItem)
exports('GetStorageEffect', getStorageEffect)

-- Configuration exports
exports('GetDecayConfig', function() return DecayConfig end)
exports('SetDecayConfig', function(key, value)
    if DecayConfig[key] ~= nil then
        DecayConfig[key] = value
        return true
    end
    return false
end)

print('[free-restaurants] server/decay.lua loaded')
