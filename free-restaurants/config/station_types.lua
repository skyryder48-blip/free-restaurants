--[[
    free-restaurants Station Types Configuration

    Defines all station types and their properties for client-side rendering
    and interaction. This is separate from the server-side station management.

    STATION PROPERTIES:
        - capacity: Number of slots and concurrent usage settings
        - requirements: Grade/permission requirements
        - particles: Cooking visual effects
        - sounds: Audio effects during cooking
        - pickup: Item pickup timing and burn/spill behavior
        - fire: Fire behavior when items burn (for stations with canBurn = true)
            - type: 'regular' (orange flames) or 'gas' (blue flames, more dangerous)
            - maxChildren: 0-25, how aggressively fire spreads (0 = no spread)
            - autoExtinguish: seconds until fire auto-extinguishes (0 = never)
            - extinguisherEffective: seconds fire can be extinguished with handheld (0 = always)
]]

Config = Config or {}
Config.Stations = Config.Stations or {}

-- ============================================================================
-- GLOBAL FIRE SETTINGS
-- ============================================================================

Config.Stations.FireDefaults = {
    type = 'regular',           -- 'regular' or 'gas'
    maxChildren = 25,           -- Maximum fire spread (0-25)
    autoExtinguish = 300,       -- Auto-extinguish after 5 minutes (0 = never)
    extinguisherEffective = 60, -- Extinguisher works for first 60 seconds, then need fire dept
    escalationTime = 15,        -- Seconds between fire escalation stages
    spreadInterval = 10,        -- Seconds between spread attempts
}

-- ============================================================================
-- STATION TYPE DEFINITIONS
-- ============================================================================

Config.Stations.Types = {
    -- Grill Station (for burgers, steaks, etc.)
    ['grill'] = {
        label = 'Grill',
        icon = 'fa-solid fa-fire-burner',
        capacity = {
            slots = 4,
            simultaneousWork = true,
        },
        requirements = {
            minGrade = 0,
            permission = 'canCook',
        },
        particles = {
            cooking = { dict = 'core', name = 'ent_amb_smoke_foundry', scale = 0.5 },
            ready = { dict = 'core', name = 'ent_amb_smoke_foundry', scale = 0.3 },
            burning = { dict = 'core', name = 'ent_ray_prologue_fire_smoke', scale = 0.8 },
        },
        sounds = {
            cooking = { name = 'sizzle', volume = 0.3 },
        },
        slotSpacing = 0.4,
        -- Pickup configuration: items left on hot surfaces will burn
        pickup = {
            required = true,           -- Must pick up item from station
            timeout = 30,              -- Seconds before item burns (0 = no timeout)
            warningTime = 10,          -- Seconds before timeout to show warning
            canBurn = true,            -- Food can burn if left too long
            canSpill = false,          -- Drinks can spill
            burntItem = 'burnt_food',  -- Item given when burned (nil = item destroyed)
        },
        -- Fire configuration when items burn
        fire = {
            type = 'regular',          -- 'regular' or 'gas' - grill uses regular fire
            maxChildren = 25,          -- Aggressive spreading
            autoExtinguish = 300,      -- 5 minutes
            extinguisherEffective = 45,-- 45 seconds to use extinguisher before it's too big
        },
    },

    -- Deep Fryer
    ['fryer'] = {
        label = 'Deep Fryer',
        icon = 'fa-solid fa-french-fries',
        capacity = {
            slots = 2,
            simultaneousWork = true,
        },
        requirements = {
            minGrade = 0,
            permission = 'canCook',
        },
        particles = {
            cooking = { dict = 'core', name = 'ent_amb_smoke_foundry', scale = 0.3 },
            ready = { dict = 'core', name = 'ent_amb_smoke_foundry', scale = 0.2 },
            burning = { dict = 'core', name = 'ent_ray_prologue_fire_smoke', scale = 0.5 },
        },
        slotSpacing = 0.3,
        pickup = {
            required = true,
            timeout = 20,              -- Frying is faster to burn
            warningTime = 8,
            canBurn = true,
            canSpill = false,
            burntItem = 'burnt_food',
        },
        -- Fryer fires are VERY dangerous - oil fires
        fire = {
            type = 'gas',              -- Oil/grease fire - blue, spreads fast
            maxChildren = 25,          -- Very aggressive
            autoExtinguish = 0,        -- Oil fires don't go out on their own!
            extinguisherEffective = 30,-- Only 30 seconds before it's out of control
        },
    },

    -- Oven
    ['oven'] = {
        label = 'Oven',
        icon = 'fa-solid fa-oven',
        capacity = {
            slots = 2,
            simultaneousWork = true,
        },
        requirements = {
            minGrade = 0,
            permission = 'canCook',
        },
        particles = {
            cooking = { dict = 'core', name = 'ent_amb_smoke_foundry', scale = 0.4 },
            ready = { dict = 'core', name = 'ent_amb_smoke_foundry', scale = 0.2 },
        },
        slotSpacing = 0.5,
        pickup = {
            required = true,
            timeout = 45,              -- Oven stays warm longer
            warningTime = 15,
            canBurn = true,
            canSpill = false,
            burntItem = 'burnt_food',
        },
        -- Oven fires are contained initially
        fire = {
            type = 'regular',
            maxChildren = 15,          -- Moderate spreading (contained space)
            autoExtinguish = 240,      -- 4 minutes
            extinguisherEffective = 60,
        },
    },

    -- Stovetop
    ['stovetop'] = {
        label = 'Stovetop',
        icon = 'fa-solid fa-fire-burner',
        capacity = {
            slots = 4,
            simultaneousWork = true,
        },
        requirements = {
            minGrade = 0,
            permission = 'canCook',
        },
        particles = {
            cooking = { dict = 'core', name = 'ent_amb_smoke_foundry', scale = 0.3 },
        },
        slotSpacing = 0.35,
        pickup = {
            required = true,
            timeout = 25,
            warningTime = 10,
            canBurn = true,
            canSpill = false,
            burntItem = 'burnt_food',
        },
        fire = {
            type = 'regular',
            maxChildren = 20,
            autoExtinguish = 300,
            extinguisherEffective = 50,
        },
    },

    -- Prep Counter (for assembly, no cooking) - NO BURN/SPILL
    ['prep_counter'] = {
        label = 'Prep Counter',
        icon = 'fa-solid fa-utensils',
        capacity = {
            slots = 3,
            simultaneousWork = true,
        },
        requirements = {
            minGrade = 0,
            permission = 'canCook',
        },
        particles = {},
        slotSpacing = 0.5,
        pickup = {
            required = true,
            timeout = 0,               -- No timeout - items can stay indefinitely
            warningTime = 0,
            canBurn = false,
            canSpill = false,
        },
    },

    -- Cutting Board - NO BURN/SPILL
    ['cutting_board'] = {
        label = 'Cutting Board',
        icon = 'fa-solid fa-knife',
        capacity = {
            slots = 1,
            simultaneousWork = false,
        },
        requirements = {
            minGrade = 0,
            permission = 'canCook',
        },
        particles = {},
        slotSpacing = 0.3,
        pickup = {
            required = true,
            timeout = 0,
            warningTime = 0,
            canBurn = false,
            canSpill = false,
        },
    },

    -- Mixer - NO BURN/SPILL
    ['mixer'] = {
        label = 'Mixer',
        icon = 'fa-solid fa-blender',
        capacity = {
            slots = 1,
            simultaneousWork = false,
        },
        requirements = {
            minGrade = 0,
            permission = 'canCook',
        },
        particles = {},
        slotSpacing = 0.3,
        pickup = {
            required = true,
            timeout = 0,
            warningTime = 0,
            canBurn = false,
            canSpill = false,
        },
    },

    -- Coffee Machine - can spill if left
    ['coffee_machine'] = {
        label = 'Coffee Machine',
        icon = 'fa-solid fa-mug-hot',
        capacity = {
            slots = 2,
            simultaneousWork = true,
        },
        requirements = {
            minGrade = 0,
            permission = 'canCook',
        },
        particles = {
            cooking = { dict = 'core', name = 'ent_amb_smoke_foundry', scale = 0.2 },
        },
        slotSpacing = 0.25,
        pickup = {
            required = true,
            timeout = 60,              -- Coffee can sit a while
            warningTime = 15,
            canBurn = false,
            canSpill = true,           -- Overflow if left too long
            spilledItem = nil,         -- Destroyed when spilled
        },
    },

    -- Drink Mixer / Bar - can spill
    ['drink_mixer'] = {
        label = 'Drink Mixer',
        icon = 'fa-solid fa-martini-glass',
        capacity = {
            slots = 2,
            simultaneousWork = true,
        },
        requirements = {
            minGrade = 0,
            permission = 'canCook',
        },
        particles = {},
        slotSpacing = 0.3,
        pickup = {
            required = true,
            timeout = 45,
            warningTime = 15,
            canBurn = false,
            canSpill = true,
            spilledItem = nil,
        },
    },

    -- Pizza Oven
    ['pizza_oven'] = {
        label = 'Pizza Oven',
        icon = 'fa-solid fa-pizza-slice',
        capacity = {
            slots = 3,
            simultaneousWork = true,
        },
        requirements = {
            minGrade = 0,
            permission = 'canCook',
        },
        particles = {
            cooking = { dict = 'core', name = 'ent_amb_smoke_foundry', scale = 0.5 },
            ready = { dict = 'core', name = 'ent_amb_smoke_foundry', scale = 0.3 },
            burning = { dict = 'core', name = 'ent_ray_prologue_fire_smoke', scale = 0.7 },
        },
        slotSpacing = 0.6,
        pickup = {
            required = true,
            timeout = 35,
            warningTime = 12,
            canBurn = true,
            canSpill = false,
            burntItem = 'burnt_food',
        },
        -- Wood-fired pizza oven
        fire = {
            type = 'regular',
            maxChildren = 20,
            autoExtinguish = 360,      -- 6 minutes - brick retains heat
            extinguisherEffective = 90,-- Easier to contain in brick oven
        },
    },

    -- Ice Cream Machine - can melt (spill effect)
    ['ice_cream_machine'] = {
        label = 'Ice Cream Machine',
        icon = 'fa-solid fa-ice-cream',
        capacity = {
            slots = 1,
            simultaneousWork = false,
        },
        requirements = {
            minGrade = 0,
            permission = 'canCook',
        },
        particles = {},
        slotSpacing = 0.3,
        pickup = {
            required = true,
            timeout = 90,              -- Ice cream melts slowly
            warningTime = 30,
            canBurn = false,
            canSpill = true,           -- Melts
            spilledItem = nil,
        },
    },

    -- Soda Fountain - can overflow
    ['soda_fountain'] = {
        label = 'Soda Fountain',
        icon = 'fa-solid fa-cup-straw',
        capacity = {
            slots = 4,
            simultaneousWork = true,
        },
        requirements = {
            minGrade = 0,
            permission = 'canServe',
        },
        particles = {},
        slotSpacing = 0.2,
        pickup = {
            required = true,
            timeout = 0,               -- Soda fountain holds cup, no spill
            warningTime = 0,
            canBurn = false,
            canSpill = false,
        },
    },

    -- Blender - NO BURN/SPILL
    ['blender'] = {
        label = 'Blender',
        icon = 'fa-solid fa-blender',
        capacity = {
            slots = 1,
            simultaneousWork = false,
        },
        requirements = {
            minGrade = 0,
            permission = 'canCook',
        },
        particles = {},
        slotSpacing = 0.3,
        pickup = {
            required = true,
            timeout = 0,
            warningTime = 0,
            canBurn = false,
            canSpill = false,
        },
    },

    -- Plating Station - NO BURN/SPILL
    ['plating_station'] = {
        label = 'Plating Station',
        icon = 'fa-solid fa-plate-wheat',
        capacity = {
            slots = 2,
            simultaneousWork = true,
        },
        requirements = {
            minGrade = 0,
            permission = 'canCook',
        },
        particles = {},
        slotSpacing = 0.4,
        pickup = {
            required = true,
            timeout = 0,
            warningTime = 0,
            canBurn = false,
            canSpill = false,
        },
    },

    -- Packaging Station - NO BURN/SPILL
    ['packaging_station'] = {
        label = 'Packaging Station',
        icon = 'fa-solid fa-box',
        capacity = {
            slots = 2,
            simultaneousWork = true,
        },
        requirements = {
            minGrade = 0,
            permission = 'canServe',
        },
        particles = {},
        slotSpacing = 0.4,
        pickup = {
            required = true,
            timeout = 0,
            warningTime = 0,
            canBurn = false,
            canSpill = false,
        },
    },

    -- Taco Station
    ['taco_station'] = {
        label = 'Taco Station',
        icon = 'fa-solid fa-taco',
        capacity = {
            slots = 3,
            simultaneousWork = true,
        },
        requirements = {
            minGrade = 0,
            permission = 'canCook',
        },
        particles = {
            cooking = { dict = 'core', name = 'ent_amb_smoke_foundry', scale = 0.3 },
        },
        slotSpacing = 0.4,
        pickup = {
            required = true,
            timeout = 30,
            warningTime = 10,
            canBurn = true,
            canSpill = false,
            burntItem = 'burnt_food',
        },
    },

    -- Microwave
    ['microwave'] = {
        label = 'Microwave',
        icon = 'fa-solid fa-radiation',
        capacity = {
            slots = 1,
            simultaneousWork = false,
        },
        requirements = {
            minGrade = 0,
            permission = 'canCook',
        },
        particles = {},
        slotSpacing = 0.3,
        pickup = {
            required = true,
            timeout = 120,             -- Microwave keeps food warm
            warningTime = 30,
            canBurn = true,
            canSpill = false,
            burntItem = 'burnt_food',
        },
    },
}

-- Debug: Print to verify file loaded
local stationCount = 0
for _ in pairs(Config.Stations.Types) do stationCount = stationCount + 1 end
print(('[free-restaurants] config/station_types.lua loaded - %d station types defined'):format(stationCount))
