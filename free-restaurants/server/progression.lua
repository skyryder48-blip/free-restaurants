--[[
    free-restaurants Server Progression System
    
    Handles:
    - XP tracking and persistence
    - Level calculations
    - Skill management
    - Recipe unlocking
    - Achievement tracking
    
    DEPENDENCIES:
    - server/main.lua
    - oxmysql
]]

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

--- Check if table contains value
---@param tbl table
---@param value any
---@return boolean
local function tableContains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then return true end
    end
    return false
end

-- ============================================================================
-- LEVEL CONFIGURATION
-- ============================================================================

local LevelConfig = {
    -- XP required for each level (cumulative)
    -- Formula: level * 100 * level (quadratic curve)
    xpPerLevel = function(level)
        return level * 100 * level
    end,
    
    -- Maximum level
    maxLevel = 50,
    
    -- Bonuses per level
    bonuses = {
        qualityBonus = 0.01,      -- +1% quality per level
        speedBonus = 0.005,       -- +0.5% speed per level
        xpBonus = 0.02,           -- +2% XP per level
    },
}

-- ============================================================================
-- LEVEL CALCULATIONS
-- ============================================================================

--- Calculate level from total XP
---@param xp number Total XP
---@return number level Current level
---@return number currentLevelXp XP into current level
---@return number nextLevelXp XP needed for next level
local function calculateLevelFromXP(xp)
    local level = 1
    local totalRequired = 0
    
    while level < LevelConfig.maxLevel do
        local required = LevelConfig.xpPerLevel(level)
        if totalRequired + required > xp then
            break
        end
        totalRequired = totalRequired + required
        level = level + 1
    end
    
    local currentLevelXp = xp - totalRequired
    local nextLevelXp = LevelConfig.xpPerLevel(level)
    
    return level, currentLevelXp, nextLevelXp
end

--- Calculate total XP required for a level
---@param targetLevel number
---@return number totalXp
local function getXPForLevel(targetLevel)
    local total = 0
    for lvl = 1, targetLevel - 1 do
        total = total + LevelConfig.xpPerLevel(lvl)
    end
    return total
end

--- Get level bonuses
---@param level number
---@return table bonuses
local function getLevelBonuses(level)
    return {
        qualityBonus = level * LevelConfig.bonuses.qualityBonus,
        speedBonus = level * LevelConfig.bonuses.speedBonus,
        xpBonus = level * LevelConfig.bonuses.xpBonus,
    }
end

-- ============================================================================
-- RECIPE UNLOCKS
-- ============================================================================

--- Check and unlock recipes for level
---@param source number
---@param citizenid string
---@param level number
local function checkRecipeUnlocks(source, citizenid, level)
    local data = exports['free-restaurants']:GetPlayerRestaurantData(citizenid)
    data.unlockedRecipes = data.unlockedRecipes or {}

    local newUnlocks = {}

    for recipeId, recipe in pairs(Config.Recipes) do
        -- Check if recipe unlocks at this level
        if recipe.unlockAtLevel and recipe.unlockAtLevel == level then
            if not tableContains(data.unlockedRecipes, recipeId) then
                table.insert(data.unlockedRecipes, recipeId)
                table.insert(newUnlocks, {
                    id = recipeId,
                    label = recipe.label,
                })
            end
        end
    end

    if #newUnlocks > 0 then
        exports['free-restaurants']:SavePlayerRestaurantData(citizenid, data)

        TriggerClientEvent('free-restaurants:client:recipesUnlocked', source, newUnlocks)
    end
end

-- ============================================================================
-- XP AWARDING
-- ============================================================================

--- Award XP to player
---@param source number
---@param amount number Base XP amount
---@param reason string Reason for XP
---@param category? string Skill category
---@return number actualXp XP awarded after bonuses
---@return boolean leveledUp Whether player leveled up
local function awardXP(source, amount, reason, category)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return 0, false end
    
    local citizenid = player.PlayerData.citizenid
    local data = exports['free-restaurants']:GetPlayerRestaurantData(citizenid)
    
    -- Apply level bonus
    local bonuses = getLevelBonuses(data.cookingLevel)
    local actualXp = math.floor(amount * (1 + bonuses.xpBonus))
    
    -- Store old level for comparison
    local oldLevel = data.cookingLevel
    
    -- Update XP
    data.cookingXp = data.cookingXp + actualXp
    
    -- Update category skill if provided
    if category then
        data.skills = data.skills or {}
        data.skills[category] = (data.skills[category] or 0) + 1
    end
    
    -- Calculate new level
    local newLevel, currentLevelXp, nextLevelXp = calculateLevelFromXP(data.cookingXp)
    data.cookingLevel = newLevel
    
    -- Check for level up
    local leveledUp = newLevel > oldLevel
    
    -- Save data
    exports['free-restaurants']:SavePlayerRestaurantData(citizenid, data)
    
    -- Notify player
    TriggerClientEvent('free-restaurants:client:xpGained', source, {
        amount = actualXp,
        reason = reason,
        totalXp = data.cookingXp,
        level = newLevel,
        currentLevelXp = currentLevelXp,
        nextLevelXp = nextLevelXp,
    })
    
    if leveledUp then
        TriggerClientEvent('free-restaurants:client:levelUp', source, {
            oldLevel = oldLevel,
            newLevel = newLevel,
            bonuses = getLevelBonuses(newLevel),
        })
        
        -- Check for recipe unlocks
        checkRecipeUnlocks(source, citizenid, newLevel)
    end
    
    return actualXp, leveledUp
end

-- ============================================================================
-- MANUAL RECIPE UNLOCKS
-- ============================================================================

--- Manually unlock a recipe
---@param citizenid string
---@param recipeId string
---@return boolean success
local function unlockRecipe(citizenid, recipeId)
    local data = exports['free-restaurants']:GetPlayerRestaurantData(citizenid)
    data.unlockedRecipes = data.unlockedRecipes or {}
    
    if tableContains(data.unlockedRecipes, recipeId) then
        return false -- Already unlocked
    end
    
    table.insert(data.unlockedRecipes, recipeId)
    exports['free-restaurants']:SavePlayerRestaurantData(citizenid, data)
    
    return true
end

-- ============================================================================
-- SKILL SYSTEM
-- ============================================================================

--- Get skill level for category
---@param citizenid string
---@param category string
---@return number skillLevel
local function getSkillLevel(citizenid, category)
    local data = exports['free-restaurants']:GetPlayerRestaurantData(citizenid)
    
    if data.skills and data.skills[category] then
        -- Convert raw skill points to level
        local points = data.skills[category]
        return math.floor(points / 10) + 1 -- 10 actions per skill level
    end
    
    return 1
end

--- Get all skills
---@param citizenid string
---@return table skills
local function getAllSkills(citizenid)
    local data = exports['free-restaurants']:GetPlayerRestaurantData(citizenid)
    local skills = {}
    
    for category, points in pairs(data.skills or {}) do
        skills[category] = {
            points = points,
            level = math.floor(points / 10) + 1,
        }
    end
    
    return skills
end

-- ============================================================================
-- CALLBACKS
-- ============================================================================

--- Get player progression data
lib.callback.register('free-restaurants:server:getProgression', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return nil end
    
    local data = exports['free-restaurants']:GetPlayerRestaurantData(player.PlayerData.citizenid)
    local level, currentLevelXp, nextLevelXp = calculateLevelFromXP(data.cookingXp)
    local bonuses = getLevelBonuses(level)
    
    return {
        level = level,
        totalXp = data.cookingXp,
        currentLevelXp = currentLevelXp,
        nextLevelXp = nextLevelXp,
        progress = (currentLevelXp / nextLevelXp) * 100,
        totalCrafts = data.totalCrafts,
        totalOrders = data.totalOrders,
        totalTips = data.totalTips,
        skills = getAllSkills(player.PlayerData.citizenid),
        unlockedRecipes = data.unlockedRecipes or {},
        bonuses = bonuses,
    }
end)

--- Get skill level callback (used by cooking system)
lib.callback.register('free-restaurants:server:getSkillLevel', function(source, category)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return 1 end
    
    if category then
        return getSkillLevel(player.PlayerData.citizenid, category)
    end
    
    local data = exports['free-restaurants']:GetPlayerRestaurantData(player.PlayerData.citizenid)
    return data.cookingLevel or 1
end)

--- Get level bonuses
lib.callback.register('free-restaurants:server:getLevelBonuses', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return {} end
    
    local data = exports['free-restaurants']:GetPlayerRestaurantData(player.PlayerData.citizenid)
    return getLevelBonuses(data.cookingLevel)
end)

-- ============================================================================
-- LEADERBOARD
-- ============================================================================

--- Get top players by level/XP
lib.callback.register('free-restaurants:server:getLeaderboard', function(source, limit)
    limit = limit or 10
    
    local results = MySQL.query.await([[
        SELECT citizenid, cooking_level, cooking_xp, total_crafts
        FROM restaurant_player_data
        ORDER BY cooking_xp DESC
        LIMIT ?
    ]], { limit })
    
    local leaderboard = {}
    
    if results then
        for i, row in ipairs(results) do
            -- Try to get player name
            local playerData = MySQL.single.await([[
                SELECT charinfo FROM players WHERE citizenid = ?
            ]], { row.citizenid })
            
            local name = 'Unknown'
            if playerData and playerData.charinfo then
                local charinfo = json.decode(playerData.charinfo)
                name = ('%s %s'):format(charinfo.firstname, charinfo.lastname)
            end
            
            table.insert(leaderboard, {
                rank = i,
                name = name,
                level = row.cooking_level,
                xp = row.cooking_xp,
                crafts = row.total_crafts,
            })
        end
    end
    
    return leaderboard
end)

-- ============================================================================
-- COMMANDS
-- ============================================================================

--- /kitchenskills - Display player's cooking skills and progression
RegisterCommand('kitchenskills', function(source, args)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return end

    local citizenid = player.PlayerData.citizenid
    local data = exports['free-restaurants']:GetPlayerRestaurantData(citizenid)
    local level, currentLevelXp, nextLevelXp = calculateLevelFromXP(data.cookingXp)
    local bonuses = getLevelBonuses(level)
    local skills = getAllSkills(citizenid)

    -- Calculate progress percentage
    local progressPercent = math.floor((currentLevelXp / nextLevelXp) * 100)

    -- Build skills list
    local skillLines = {}
    local skillCategories = {
        cooking = 'Cooking',
        grilling = 'Grilling',
        frying = 'Frying',
        drinks = 'Drinks',
        desserts = 'Desserts',
        delivery = 'Delivery',
    }

    for category, label in pairs(skillCategories) do
        local skillData = skills[category]
        if skillData then
            table.insert(skillLines, ('  %s: Level %d (%d pts)'):format(label, skillData.level, skillData.points))
        end
    end

    -- Format message
    local message = ('\n=== Kitchen Skills ===\n' ..
        'Cooking Level: %d\n' ..
        'XP: %d / %d (%d%%)\n' ..
        'Total XP: %d\n' ..
        '\n--- Level Bonuses ---\n' ..
        '  Quality: +%d%%\n' ..
        '  Speed: +%.1f%%\n' ..
        '  XP Gain: +%d%%\n'):format(
            level,
            currentLevelXp, nextLevelXp, progressPercent,
            data.cookingXp,
            math.floor(bonuses.qualityBonus * 100),
            bonuses.speedBonus * 100,
            math.floor(bonuses.xpBonus * 100)
        )

    if #skillLines > 0 then
        message = message .. '\n--- Skill Categories ---\n' .. table.concat(skillLines, '\n')
    end

    -- Stats
    message = message .. ('\n\n--- Statistics ---\n' ..
        '  Total Crafts: %d\n' ..
        '  Total Orders: %d\n' ..
        '  Total Tips: $%d\n' ..
        '  Recipes Unlocked: %d\n'):format(
            data.totalCrafts or 0,
            data.totalOrders or 0,
            data.totalTips or 0,
            data.unlockedRecipes and #data.unlockedRecipes or 0
        )

    -- Send as chat message
    TriggerClientEvent('chat:addMessage', source, {
        color = { 255, 200, 100 },
        multiline = true,
        args = { 'Kitchen Skills', message }
    })

    -- Also show a notification summary
    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Kitchen Level ' .. level,
        description = ('XP: %d/%d (%d%%)'):format(currentLevelXp, nextLevelXp, progressPercent),
        type = 'inform',
        duration = 5000,
    })
end, false)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('AwardXP', awardXP)
exports('CalculateLevelFromXP', calculateLevelFromXP)
exports('GetLevelBonuses', getLevelBonuses)
exports('GetSkillLevel', getSkillLevel)
exports('GetAllSkills', getAllSkills)
exports('UnlockRecipe', unlockRecipe)

print('[free-restaurants] server/progression.lua loaded')
