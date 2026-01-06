--[[
    free-restaurants Station Types Configuration

    Defines all station types and their properties for client-side rendering
    and interaction. This is separate from the server-side station management.

    STATION PROPERTIES:
        - capacity: Number of slots and concurrent usage settings
        - requirements: Grade/permission requirements
        - particles: Cooking visual effects
        - sounds: Audio effects during cooking
]]

Config = Config or {}
Config.Stations = Config.Stations or {}

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
    },

    -- Prep Counter (for assembly, no cooking)
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
    },

    -- Cutting Board
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
    },

    -- Mixer
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
    },

    -- Coffee Machine
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
    },

    -- Drink Mixer / Bar
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
    },

    -- Ice Cream Machine
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
    },

    -- Soda Fountain
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
    },

    -- Blender
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
    },

    -- Plating Station
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
    },

    -- Packaging Station (for takeout/delivery)
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
    },

    -- Taco Station (for taco restaurants)
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
    },

    -- Microwave (for heating items)
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
    },
}

-- Debug: Print to verify file loaded
local stationCount = 0
for _ in pairs(Config.Stations.Types) do stationCount = stationCount + 1 end
print(('[free-restaurants] config/station_types.lua loaded - %d station types defined'):format(stationCount))
