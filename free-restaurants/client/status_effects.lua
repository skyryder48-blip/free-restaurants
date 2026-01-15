--[[
    free-restaurants Client Status Effects

    Handles:
    - Alcohol intoxication effects (visual, movement impairment)
    - Food poisoning effects (nausea, health damage, vomiting)
    - Trash can disposal zones
    - Temperature warnings for storage
]]

print('[free-restaurants] client/status_effects.lua loading...')

-- ============================================================================
-- STATE VARIABLES
-- ============================================================================

local intoxicationLevel = 0         -- 0-100, accumulated alcohol
local foodPoisoningSeverity = nil   -- nil, 'mild', 'moderate', 'severe'
local foodPoisoningStartTime = 0
local isVomiting = false
local lastDrinkTime = 0

-- Screen effects handles
local drunkEffectHandle = nil

-- ============================================================================
-- INTOXICATION SYSTEM
-- ============================================================================

local IntoxicationConfig = {
    -- Thresholds for effects
    thresholds = {
        buzzed = 15,        -- Slight buzz, minimal effects
        tipsy = 30,         -- Noticeable impairment
        drunk = 50,         -- Significant impairment
        wasted = 75,        -- Severe impairment
        blackout = 95,      -- Near unconscious
    },

    -- Decay rate per minute
    decayRate = 5,          -- Loses 5 intoxication per minute

    -- Effect intensities by level
    effects = {
        buzzed = {
            screenEffect = 0.1,
            walkStyle = nil,
            speechSlur = false,
        },
        tipsy = {
            screenEffect = 0.3,
            walkStyle = 'move_m@drunk@slightlydrunk',
            speechSlur = true,
        },
        drunk = {
            screenEffect = 0.5,
            walkStyle = 'move_m@drunk@moderatedrunk',
            speechSlur = true,
            stumbleChance = 0.1,
        },
        wasted = {
            screenEffect = 0.8,
            walkStyle = 'move_m@drunk@verydrunk',
            speechSlur = true,
            stumbleChance = 0.3,
            vomitChance = 0.05,
        },
        blackout = {
            screenEffect = 1.0,
            walkStyle = 'move_m@drunk@verydrunk',
            speechSlur = true,
            stumbleChance = 0.5,
            vomitChance = 0.15,
            blackoutChance = 0.1,
        },
    },
}

--- Get current intoxication level name
---@return string|nil
local function getIntoxicationLevel()
    if intoxicationLevel >= IntoxicationConfig.thresholds.blackout then
        return 'blackout'
    elseif intoxicationLevel >= IntoxicationConfig.thresholds.wasted then
        return 'wasted'
    elseif intoxicationLevel >= IntoxicationConfig.thresholds.drunk then
        return 'drunk'
    elseif intoxicationLevel >= IntoxicationConfig.thresholds.tipsy then
        return 'tipsy'
    elseif intoxicationLevel >= IntoxicationConfig.thresholds.buzzed then
        return 'buzzed'
    end
    return nil
end

--- Add alcohol to intoxication level
---@param alcoholContent number Alcohol percentage (e.g., 5 for beer, 40 for whiskey)
---@param uses number Number of uses consumed
local function addIntoxication(alcoholContent, uses)
    if not alcoholContent or alcoholContent <= 0 then return end

    -- Calculate intoxication increase
    -- Each use adds (alcoholContent / 10) intoxication
    local increase = (alcoholContent / 10) * uses
    intoxicationLevel = math.min(100, intoxicationLevel + increase)
    lastDrinkTime = GetGameTimer()

    local level = getIntoxicationLevel()
    if level then
        print(('[free-restaurants] Intoxication: +%.1f, total: %.1f (%s)'):format(
            increase, intoxicationLevel, level
        ))
    end
end

--- Apply visual effects based on intoxication
local function applyIntoxicationEffects()
    local level = getIntoxicationLevel()

    if not level then
        -- Sober - remove effects
        if drunkEffectHandle then
            StopScreenEffect('DrugsMichaelAliensFight')
            AnimpostfxStop('DrugsMichaelAliensFight')
            drunkEffectHandle = nil
        end
        ResetPedMovementClipset(PlayerPedId(), 0.0)
        return
    end

    local effects = IntoxicationConfig.effects[level]
    if not effects then return end

    -- Screen effect (blurry/wavey vision)
    if effects.screenEffect > 0 then
        if not drunkEffectHandle then
            StartScreenEffect('DrugsMichaelAliensFight', 0, true)
            drunkEffectHandle = true
        end
        -- Intensity varies with level
        SetTimecycleModifier('drug_flying_base')
        SetTimecycleModifierStrength(effects.screenEffect * 0.3)
    end

    -- Walk style
    if effects.walkStyle then
        local ped = PlayerPedId()
        RequestAnimSet(effects.walkStyle)
        local timeout = 0
        while not HasAnimSetLoaded(effects.walkStyle) and timeout < 1000 do
            Wait(10)
            timeout = timeout + 10
        end
        if HasAnimSetLoaded(effects.walkStyle) then
            SetPedMovementClipset(ped, effects.walkStyle, 1.0)
        end
    end

    -- Random stumble
    if effects.stumbleChance and math.random() < effects.stumbleChance then
        local ped = PlayerPedId()
        if IsPedOnFoot(ped) and not IsPedRagdoll(ped) then
            SetPedToRagdoll(ped, 1000, 1000, 0, false, false, false)
        end
    end

    -- Random vomit
    if effects.vomitChance and math.random() < effects.vomitChance then
        TriggerVomit()
    end

    -- Blackout (ragdoll + screen fade)
    if effects.blackoutChance and math.random() < effects.blackoutChance then
        TriggerBlackout()
    end
end

--- Trigger vomiting animation
function TriggerVomit()
    if isVomiting then return end
    isVomiting = true

    local ped = PlayerPedId()

    CreateThread(function()
        -- Play vomit animation
        lib.requestAnimDict('oddjobs@assassinate@multi@')
        TaskPlayAnim(ped, 'oddjobs@assassinate@multi@', 'vomit', 8.0, -8.0, 5000, 49, 0, false, false, false)

        Wait(5000)

        -- Reduce intoxication slightly from vomiting
        intoxicationLevel = math.max(0, intoxicationLevel - 10)

        isVomiting = false
    end)
end

--- Trigger blackout
function TriggerBlackout()
    local ped = PlayerPedId()

    CreateThread(function()
        DoScreenFadeOut(1000)
        Wait(1000)

        SetPedToRagdoll(ped, 10000, 10000, 0, false, false, false)

        Wait(8000)

        DoScreenFadeIn(2000)
        intoxicationLevel = math.max(0, intoxicationLevel - 20)
    end)
end

-- ============================================================================
-- FOOD POISONING SYSTEM
-- ============================================================================

local FoodPoisoningConfig = {
    -- Duration by severity (milliseconds)
    duration = {
        mild = 60000,       -- 1 minute
        moderate = 180000,  -- 3 minutes
        severe = 300000,    -- 5 minutes
    },

    -- Effects by severity
    effects = {
        mild = {
            healthDrain = 1,        -- Health lost per tick
            nauseaIntensity = 0.2,
            vomitChance = 0.02,
            tickInterval = 10000,   -- Every 10 seconds
        },
        moderate = {
            healthDrain = 2,
            nauseaIntensity = 0.5,
            vomitChance = 0.08,
            tickInterval = 8000,
        },
        severe = {
            healthDrain = 5,
            nauseaIntensity = 0.8,
            vomitChance = 0.15,
            speedReduction = 0.7,   -- 70% speed
            tickInterval = 5000,
        },
    },
}

--- Check for food poisoning based on item quality
---@param itemConfig table Item configuration
---@param quality number Item quality 0-100
---@param spoiled boolean Whether item was spoiled
---@return boolean poisoned Whether player got food poisoning
local function checkFoodPoisoning(itemConfig, quality, spoiled)
    local risk = 0

    -- Base risk from spoiled status
    if spoiled then
        risk = Config.ItemEffects.Defaults.foodPoisoningRisk.spoiled
    elseif quality < 10 then
        risk = Config.ItemEffects.Defaults.foodPoisoningRisk.veryLow
    elseif quality < 25 then
        risk = Config.ItemEffects.Defaults.foodPoisoningRisk.low
    end

    -- Additional risk from item-specific setting
    if itemConfig and itemConfig.foodPoisoningRisk then
        risk = math.max(risk, itemConfig.foodPoisoningRisk)
    end

    -- Roll for food poisoning
    if risk > 0 and math.random() < risk then
        -- Determine severity
        local severity = 'mild'
        if spoiled and quality < 10 then
            severity = 'severe'
        elseif spoiled or quality < 25 then
            severity = 'moderate'
        end

        startFoodPoisoning(severity)
        return true
    end

    return false
end

--- Start food poisoning effects
---@param severity string 'mild', 'moderate', 'severe'
function startFoodPoisoning(severity)
    if foodPoisoningSeverity then
        -- Already poisoned - upgrade severity if worse
        local severityLevels = { mild = 1, moderate = 2, severe = 3 }
        if severityLevels[severity] <= severityLevels[foodPoisoningSeverity] then
            return -- Already at same or worse severity
        end
    end

    foodPoisoningSeverity = severity
    foodPoisoningStartTime = GetGameTimer()

    lib.notify({
        title = 'Food Poisoning',
        description = ('You don\'t feel so good... (%s)'):format(severity),
        type = 'error',
        duration = 5000,
    })

    print(('[free-restaurants] Player got food poisoning: %s'):format(severity))
end

--- Cure food poisoning
---@param medicineLevel string Medicine level that can cure ('mild', 'moderate', 'severe')
function cureFoodPoisoning(medicineLevel)
    if not foodPoisoningSeverity then return false end

    local severityLevels = { mild = 1, moderate = 2, severe = 3 }
    local currentLevel = severityLevels[foodPoisoningSeverity] or 0
    local medicineStrength = severityLevels[medicineLevel] or 0

    if medicineStrength >= currentLevel then
        foodPoisoningSeverity = nil
        foodPoisoningStartTime = 0

        -- Clear effects
        ClearTimecycleModifier()

        lib.notify({
            title = 'Feeling Better',
            description = 'The medication is working.',
            type = 'success',
        })

        return true
    else
        -- Reduce severity by one level
        if foodPoisoningSeverity == 'severe' then
            foodPoisoningSeverity = 'moderate'
        elseif foodPoisoningSeverity == 'moderate' then
            foodPoisoningSeverity = 'mild'
        end

        lib.notify({
            title = 'Partial Relief',
            description = 'Symptoms reduced but not cured.',
            type = 'inform',
        })

        return false
    end
end

--- Apply food poisoning effects
local function applyFoodPoisoningEffects()
    if not foodPoisoningSeverity then return end

    local config = FoodPoisoningConfig.effects[foodPoisoningSeverity]
    if not config then return end

    -- Check if duration expired
    local elapsed = GetGameTimer() - foodPoisoningStartTime
    local duration = FoodPoisoningConfig.duration[foodPoisoningSeverity] or 60000

    if elapsed >= duration then
        foodPoisoningSeverity = nil
        foodPoisoningStartTime = 0
        ClearTimecycleModifier()
        lib.notify({
            title = 'Recovered',
            description = 'You\'re feeling better now.',
            type = 'success',
        })
        return
    end

    -- Nausea visual effect
    if config.nauseaIntensity > 0 then
        SetTimecycleModifier('drug_wobbly')
        SetTimecycleModifierStrength(config.nauseaIntensity * 0.5)
    end

    -- Health drain
    if config.healthDrain > 0 then
        local ped = PlayerPedId()
        local health = GetEntityHealth(ped)
        SetEntityHealth(ped, math.max(100, health - config.healthDrain))
    end

    -- Vomit chance
    if config.vomitChance and math.random() < config.vomitChance then
        TriggerVomit()
    end

    -- Speed reduction
    if config.speedReduction then
        SetPlayerSprint(PlayerId(), false)
    end
end

-- ============================================================================
-- TRASH CAN DISPOSAL SYSTEM
-- ============================================================================

local TrashCanConfig = {
    -- Models that are trash cans
    models = {
        'prop_bin_01a',
        'prop_bin_02a',
        'prop_bin_03a',
        'prop_bin_04a',
        'prop_bin_05a',
        'prop_bin_06a',
        'prop_bin_07a',
        'prop_bin_07b',
        'prop_bin_07c',
        'prop_bin_07d',
        'prop_bin_08a',
        'prop_bin_08open',
        'prop_bin_09a',
        'prop_bin_10a',
        'prop_bin_10b',
        'prop_bin_11a',
        'prop_bin_11b',
        'prop_bin_12a',
        'prop_bin_13a',
        'prop_bin_14a',
        'prop_bin_14b',
        'prop_bin_beach_01a',
        'prop_bin_beach_01d',
        'prop_bin_delpiero',
        'prop_bin_delpiero_b',
        'prop_cs_bin_01',
        'prop_cs_bin_01_skinned',
        'prop_recyclebin_01a',
        'prop_recyclebin_02a',
        'prop_recyclebin_02b',
        'prop_recyclebin_02_c',
        'prop_recyclebin_02_d',
        'prop_recyclebin_03_a',
        'prop_recyclebin_04_a',
        'prop_recyclebin_04_b',
        'prop_recyclebin_05_a',
        'prop_dumpster_01a',
        'prop_dumpster_02a',
        'prop_dumpster_02b',
        'prop_dumpster_3a',
        'prop_dumpster_4a',
        'prop_dumpster_4b',
    },
}

--- Initialize trash can targets using ox_target
local function initializeTrashCanTargets()
    -- Convert models to hashes
    local modelHashes = {}
    for _, model in ipairs(TrashCanConfig.models) do
        table.insert(modelHashes, GetHashKey(model))
    end

    exports.ox_target:addModel(modelHashes, {
        {
            label = 'Dispose of Trash',
            icon = 'fa-solid fa-trash',
            onSelect = function(data)
                openDisposalMenu()
            end,
            distance = 2.0,
        },
        {
            label = 'Recycle',
            icon = 'fa-solid fa-recycle',
            onSelect = function(data)
                openRecyclingMenu()
            end,
            distance = 2.0,
        },
    })

    print('[free-restaurants] Trash can targets initialized')
end

--- Open disposal menu showing disposable items
function openDisposalMenu()
    local items = exports.ox_inventory:GetPlayerItems()
    if not items then return end

    local options = {}

    for slot, item in pairs(items) do
        if item then
            local canDispose, reason = exports['free-restaurants']:CanDisposeItem(item)

            -- Also check if it's a known container
            local isContainer = Config.ItemEffects.RecyclingValues and Config.ItemEffects.RecyclingValues[item.name]

            if canDispose or isContainer then
                local recycleValue = Config.ItemEffects.RecyclingValues and Config.ItemEffects.RecyclingValues[item.name]
                local label = item.label or item.name

                if recycleValue and recycleValue.money and recycleValue.money > 0 then
                    label = label .. ' (+$' .. recycleValue.money .. ')'
                end

                table.insert(options, {
                    title = label,
                    description = reason or 'Dispose of this item',
                    icon = 'fa-solid fa-trash',
                    onSelect = function()
                        exports['free-restaurants']:DisposeItem(slot, false)
                    end,
                })
            end
        end
    end

    if #options == 0 then
        lib.notify({
            title = 'No Trash',
            description = 'You have nothing to dispose of.',
            type = 'inform',
        })
        return
    end

    lib.registerContext({
        id = 'trash_disposal_menu',
        title = 'Dispose of Trash',
        options = options,
    })

    lib.showContext('trash_disposal_menu')
end

--- Open recycling-specific menu
function openRecyclingMenu()
    local items = exports.ox_inventory:GetPlayerItems()
    if not items then return end

    local options = {}
    local totalValue = 0

    for slot, item in pairs(items) do
        if item then
            local recycleValue = Config.ItemEffects.RecyclingValues and Config.ItemEffects.RecyclingValues[item.name]

            if recycleValue and recycleValue.money and recycleValue.money > 0 then
                local itemTotal = recycleValue.money * item.count
                totalValue = totalValue + itemTotal

                table.insert(options, {
                    title = ('%s x%d'):format(item.label or item.name, item.count),
                    description = ('$%d each ($%d total)'):format(recycleValue.money, itemTotal),
                    icon = 'fa-solid fa-recycle',
                    onSelect = function()
                        -- Recycle all of this item
                        for i = 1, item.count do
                            TriggerServerEvent('free-restaurants:server:disposeItem', {
                                slot = slot,
                                force = false,
                            })
                            Wait(100)
                        end
                    end,
                })
            end
        end
    end

    if #options == 0 then
        lib.notify({
            title = 'No Recyclables',
            description = 'You have no recyclable items.',
            type = 'inform',
        })
        return
    end

    -- Add "Recycle All" option
    table.insert(options, 1, {
        title = 'Recycle All',
        description = ('Total value: $%d'):format(totalValue),
        icon = 'fa-solid fa-recycle',
        onSelect = function()
            recycleAllItems()
        end,
    })

    lib.registerContext({
        id = 'recycling_menu',
        title = 'Recycling Center',
        options = options,
    })

    lib.showContext('recycling_menu')
end

--- Recycle all recyclable items
function recycleAllItems()
    local items = exports.ox_inventory:GetPlayerItems()
    if not items then return end

    local recycled = 0
    local totalValue = 0

    for slot, item in pairs(items) do
        if item then
            local recycleValue = Config.ItemEffects.RecyclingValues and Config.ItemEffects.RecyclingValues[item.name]

            if recycleValue and recycleValue.money and recycleValue.money > 0 then
                for i = 1, item.count do
                    TriggerServerEvent('free-restaurants:server:disposeItem', {
                        slot = slot,
                        force = false,
                    })
                    recycled = recycled + 1
                    totalValue = totalValue + recycleValue.money
                    Wait(50)
                end
            end
        end
    end

    if recycled > 0 then
        lib.notify({
            title = 'Recycled',
            description = ('Recycled %d items for $%d'):format(recycled, totalValue),
            type = 'success',
        })
    end
end

-- ============================================================================
-- TEMPERATURE WARNING SYSTEM
-- ============================================================================

--- Show warning when placing freezer-incompatible items in freezer
---@param itemName string
---@param storageType string
function checkStorageWarning(itemName, storageType)
    if storageType ~= 'freezer' then return end

    -- Check server-side decay system for incompatibility
    local incompatible = {
        ['lettuce'] = true,
        ['tomato'] = true,
        ['eggs'] = true,
        ['milk'] = true,
        ['cream'] = true,
        ['yogurt'] = true,
        ['avocado'] = true,
        ['cucumber'] = true,
        ['mayonnaise'] = true,
    }

    if incompatible[itemName] then
        lib.notify({
            title = 'Warning',
            description = 'This item should not be frozen - it may be damaged!',
            type = 'warning',
            duration = 5000,
        })
    end
end

-- ============================================================================
-- EFFECT THREADS
-- ============================================================================

-- Intoxication decay and effects thread
CreateThread(function()
    while true do
        Wait(60000) -- Every minute

        -- Decay intoxication over time
        if intoxicationLevel > 0 then
            local timeSinceDrink = (GetGameTimer() - lastDrinkTime) / 60000 -- Minutes
            if timeSinceDrink > 1 then
                intoxicationLevel = math.max(0, intoxicationLevel - IntoxicationConfig.decayRate)
            end
        end
    end
end)

-- Effects application thread
CreateThread(function()
    while true do
        local sleepTime = 1000

        -- Apply intoxication effects
        if intoxicationLevel > 0 then
            applyIntoxicationEffects()
            sleepTime = 5000
        else
            -- Clear drunk effects when sober
            if drunkEffectHandle then
                StopScreenEffect('DrugsMichaelAliensFight')
                AnimpostfxStop('DrugsMichaelAliensFight')
                ClearTimecycleModifier()
                ResetPedMovementClipset(PlayerPedId(), 0.0)
                drunkEffectHandle = nil
            end
        end

        -- Apply food poisoning effects
        if foodPoisoningSeverity then
            local config = FoodPoisoningConfig.effects[foodPoisoningSeverity]
            if config then
                sleepTime = math.min(sleepTime, config.tickInterval)
            end
            applyFoodPoisoningEffects()
        end

        Wait(sleepTime)
    end
end)

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

-- Handle consumption completion to check for effects
RegisterNetEvent('free-restaurants:client:applyConsumptionEffects', function(data)
    if not data then return end

    -- Check for alcohol content
    if data.alcoholContent and data.alcoholContent > 0 then
        addIntoxication(data.alcoholContent, data.usesConsumed or 1)
    end

    -- Check for food poisoning
    if data.checkFoodPoisoning then
        local itemConfig = Config.ItemEffects.GetItem(data.itemName)
        checkFoodPoisoning(itemConfig, data.quality or 100, data.spoiled or false)
    end

    -- Check for medicine effects
    if data.curesFoodPoisoning then
        cureFoodPoisoning(data.curesFoodPoisoning)
    end
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('GetIntoxicationLevel', function() return intoxicationLevel end)
exports('GetIntoxicationState', getIntoxicationLevel)
exports('AddIntoxication', addIntoxication)
exports('SetIntoxication', function(level) intoxicationLevel = math.max(0, math.min(100, level)) end)

exports('GetFoodPoisoning', function() return foodPoisoningSeverity end)
exports('StartFoodPoisoning', startFoodPoisoning)
exports('CureFoodPoisoning', cureFoodPoisoning)

exports('OpenDisposalMenu', openDisposalMenu)
exports('OpenRecyclingMenu', openRecyclingMenu)
exports('CheckStorageWarning', checkStorageWarning)

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

CreateThread(function()
    Wait(2000)
    initializeTrashCanTargets()
    print('[free-restaurants] client/status_effects.lua loaded')
end)
