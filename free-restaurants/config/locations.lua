--[[
    free-restaurants Location Configuration
    
    This file defines all physical restaurant locations, their coordinates,
    station placements, zone boundaries, and MLO compatibility settings.
    
    LOCATION STRUCTURE:
        - Each location has a unique key matching its job name
        - Supports multiple locations per restaurant type
        - Configurable for both default GTA interiors and custom MLOs
        - Station positions tie into the station types defined in stations.lua
    
    MLO COMPATIBILITY:
        - Set mlo.required = true if using a custom MLO
        - Specify mlo.resource for the MLO resource name
        - Coordinates should match your specific MLO installation
    
    COORDINATE SOURCES:
        - Vespucci Canals Burger Shot: ~vec3(-1200.0, -900.0, 14.0)
        - Del Perro Pier Burger Shot: ~vec3(-1530.0, -890.0, 10.0)
        - Bean Machine West Vinewood: ~vec3(-634.0, -227.0, 38.0)
        - Tequi-la-la: ~vec3(-565.0, 276.0, 83.0)
        - Pizza This (Mirror Park): ~vec3(1169.0, -323.0, 69.0)
    
    NOTE: These coordinates are defaults and should be adjusted
          to match your specific MLO installations.
]]

Config = Config or {}
Config.Locations = Config.Locations or {}

-- ============================================================================
-- GLOBAL LOCATION SETTINGS
-- ============================================================================

Config.Locations.Settings = {
    -- Zone Detection
    zoneDetection = {
        method = 'polyzone',            -- 'polyzone', 'distance', 'both'
        updateInterval = 1000,          -- MS between zone checks
        debugZones = false,             -- Show zone boundaries (debug only)
    },
    
    -- Blip Settings
    blips = {
        enabled = true,
        showOnMap = true,
        showOnMinimap = true,
        scale = 0.8,
        shortRange = true,
    },
    
    -- Default blip sprites for restaurant types
    blipSprites = {
        fastfood = 106,                 -- Burger icon
        pizzeria = 93,                  -- Knife and fork
        coffeeshop = 52,                -- Coffee cup (goblet)
        bar = 93,                       -- Knife and fork (or 614 for bar)
    },
    
    -- Default blip colors for restaurant types
    blipColors = {
        fastfood = 46,                  -- Orange
        pizzeria = 1,                   -- Red
        coffeeshop = 54,                -- Brown
        bar = 27,                       -- Pink/Purple
    },
}

-- ============================================================================
-- BURGER SHOT LOCATIONS
-- ============================================================================

Config.Locations['burgershot'] = {
    --[[
        MAIN LOCATION: Vespucci Canals
        The primary Burger Shot location at San Andreas Ave & Prosperity St
        Compatible with multiple popular MLOs (Uniqx, Smallo, etc.)
    ]]
    ['vespucci'] = {
        -- Basic Info
        label = 'Burger Shot - Vespucci',
        shortName = 'BS Vespucci',
        description = 'The original Burger Shot location in Vespucci Canals',
        
        -- Job Assignment
        job = 'burgershot',
        restaurantType = 'fastfood',
        
        -- Enable/Disable this location
        enabled = true,
        
        -- MLO Configuration
        mlo = {
            required = true,            -- Set false for vanilla exterior only
            resource = 'uniqx_burgershot',  -- MLO resource name
            interiorId = nil,           -- Set if using specific interior ID
        },
        
        -- Main Entrance Position
        entrance = {
            coords = vec3(-1196.26, -897.20, 13.98),
            heading = 35.0,
            teleport = nil,             -- Set vec3 if using interior teleport
        },
        
        -- Map Blip
        blip = {
            enabled = true,
            coords = vec3(-1196.26, -897.20, 13.98),
            sprite = 106,               -- Burger
            color = 46,                 -- Orange
            scale = 0.8,
            label = 'Burger Shot',
        },
        
        -- Zone Boundary (PolyZone points)
        zone = {
            type = 'poly',
            points = {
                vec2(-1216.0, -923.0),
                vec2(-1180.0, -923.0),
                vec2(-1180.0, -880.0),
                vec2(-1216.0, -880.0),
            },
            minZ = 12.0,
            maxZ = 20.0,
            -- Alternative: simple radius zone
            -- type = 'circle',
            -- center = vec3(-1196.26, -897.20, 13.98),
            -- radius = 30.0,
        },
        
        -- Duty/Clock-in Points
        duty = {
            clockIn = {
                coords = vec3(-1200.50, -902.27, 14.75),
                heading = 35.0,
                label = 'Clock In/Out',
                targetSize = vec3(1.0, 1.0, 2.0),
            },
            locker = {
                coords = vec3(-1198.15, -904.62, 14.75),
                heading = 124.0,
                label = 'Employee Locker',
                targetSize = vec3(1.5, 0.5, 2.0),
            },
        },
        
        -- Cooking Stations
        stations = {
            -- Grill Station
            ['grill_1'] = {
                type = 'grill',
                label = 'Flat Top Grill',
                coords = vec3(-1203.87, -900.03, 14.75),
                heading = 35.0,
                targetSize = vec3(1.5, 1.0, 1.0),
                prop = nil,             -- Uses existing MLO prop
            },
            
            -- Deep Fryer Stations
            ['fryer_1'] = {
                type = 'fryer',
                label = 'Deep Fryer #1',
                coords = vec3(-1201.45, -897.68, 14.75),
                heading = 125.0,
                targetSize = vec3(0.8, 0.6, 1.0),
            },
            ['fryer_2'] = {
                type = 'fryer',
                label = 'Deep Fryer #2',
                coords = vec3(-1200.63, -896.95, 14.75),
                heading = 125.0,
                targetSize = vec3(0.8, 0.6, 1.0),
            },
            
            -- Prep Counter
            ['prep_1'] = {
                type = 'prep_counter',
                label = 'Prep Counter',
                coords = vec3(-1198.52, -899.41, 14.75),
                heading = 305.0,
                targetSize = vec3(2.0, 1.0, 1.0),
            },
            
            -- Burger Assembly
            ['assembly_1'] = {
                type = 'prep_counter',
                label = 'Burger Assembly',
                coords = vec3(-1199.89, -901.05, 14.75),
                heading = 35.0,
                targetSize = vec3(1.5, 0.8, 1.0),
            },
            
            -- Soda Fountain
            ['soda_1'] = {
                type = 'soda_fountain',
                label = 'Soda Fountain',
                coords = vec3(-1196.30, -901.82, 14.75),
                heading = 215.0,
                targetSize = vec3(1.0, 0.5, 1.5),
            },
            
            -- Blender/Milkshake Station
            ['blender_1'] = {
                type = 'blender',
                label = 'Milkshake Station',
                coords = vec3(-1195.25, -900.98, 14.75),
                heading = 305.0,
                targetSize = vec3(0.6, 0.6, 1.0),
            },
            
            -- Packaging/Tray Station
            ['packaging_1'] = {
                type = 'packaging_station',
                label = 'Order Pickup',
                coords = vec3(-1194.67, -899.71, 14.75),
                heading = 215.0,
                targetSize = vec3(1.5, 0.8, 1.0),
            },
        },
        
        -- Storage Areas
        storage = {
            ['main_storage'] = {
                label = 'Ingredient Storage',
                coords = vec3(-1207.38, -898.85, 14.75),
                heading = 35.0,
                targetSize = vec3(1.5, 1.5, 2.0),
                inventoryType = 'storage',      -- ox_inventory type
                slots = 50,
                weight = 100000,
                groups = { burgershot = 1 },    -- Job access
            },
            ['freezer'] = {
                label = 'Walk-in Freezer',
                coords = vec3(-1210.13, -896.52, 14.75),
                heading = 35.0,
                targetSize = vec3(2.0, 2.0, 2.5),
                inventoryType = 'storage',
                slots = 75,
                weight = 150000,
                groups = { burgershot = 1 },
                decayMultiplier = 0.1,          -- Slows decay significantly
            },
        },
        
        -- Customer Interaction Points
        customer = {
            -- Order Counter
            counter = {
                coords = vec3(-1195.89, -897.22, 14.75),
                heading = 35.0,
                targetSize = vec3(3.0, 1.0, 1.5),
                label = 'Order Here',
            },
            -- Seating Areas (for NPC spawns and customer zones)
            seating = {
                { coords = vec3(-1189.54, -893.89, 14.75), heading = 90.0 },
                { coords = vec3(-1191.23, -891.34, 14.75), heading = 180.0 },
                { coords = vec3(-1187.65, -896.78, 14.75), heading = 270.0 },
                { coords = vec3(-1190.12, -899.23, 14.75), heading = 0.0 },
            },
        },
        
        -- Drive-Through (if MLO supports it)
        driveThru = {
            enabled = true,
            window = {
                coords = vec3(-1202.34, -908.67, 14.75),
                heading = 125.0,
                targetSize = vec3(1.5, 0.5, 2.0),
            },
            orderPoint = {
                coords = vec3(-1215.89, -912.45, 13.98),
                heading = 35.0,
            },
            exitPoint = {
                coords = vec3(-1195.23, -912.89, 13.98),
            },
        },
        
        -- Boss/Management Office
        office = {
            coords = vec3(-1205.67, -891.23, 14.75),
            heading = 35.0,
            safe = {
                coords = vec3(-1206.45, -890.56, 14.75),
                heading = 305.0,
                targetSize = vec3(0.6, 0.6, 1.0),
            },
            computer = {
                coords = vec3(-1204.89, -892.12, 14.75),
                heading = 125.0,
                targetSize = vec3(0.8, 0.6, 0.8),
            },
        },
        
        -- Cleaning Spots (for immersion)
        cleaning = {
            { type = 'counter', coords = vec3(-1197.56, -898.23, 14.75) },
            { type = 'floor', coords = vec3(-1193.45, -895.67, 14.75) },
            { type = 'grill', coords = vec3(-1203.87, -900.03, 14.75) },
            { type = 'dishes', coords = vec3(-1198.89, -903.45, 14.75) },
        },
        
        -- Delivery Spawn Points
        delivery = {
            vehicleSpawn = {
                coords = vec3(-1185.67, -907.89, 13.98),
                heading = 305.0,
            },
            returnPoint = {
                coords = vec3(-1196.26, -897.20, 13.98),
            },
        },
        
        -- Break Room (if MLO supports it)
        breakRoom = {
            enabled = true,
            coords = vec3(-1208.34, -893.67, 14.75),
            zone = {
                type = 'circle',
                radius = 3.0,
            },
        },
        
        -- Restrooms
        restrooms = {
            { label = 'Restroom', coords = vec3(-1192.67, -907.34, 14.75), heading = 215.0 },
        },
    },
    
    --[[
        SECONDARY LOCATION: Del Perro Pier
        Smaller location on the Pleasure Pier
    ]]
    ['delperro'] = {
        label = 'Burger Shot - Del Perro Pier',
        shortName = 'BS Pier',
        description = 'Beachside Burger Shot on Del Perro Pier',
        
        job = 'burgershot',
        restaurantType = 'fastfood',
        enabled = true,
        
        mlo = {
            required = true,
            resource = 'bs_delperro',   -- Your MLO resource
            interiorId = nil,
        },
        
        entrance = {
            coords = vec3(-1530.89, -893.45, 10.21),
            heading = 220.0,
            teleport = nil,
        },
        
        blip = {
            enabled = true,
            coords = vec3(-1530.89, -893.45, 10.21),
            sprite = 106,
            color = 46,
            scale = 0.7,
            label = 'Burger Shot (Pier)',
        },
        
        zone = {
            type = 'circle',
            center = vec3(-1530.89, -893.45, 10.21),
            radius = 20.0,
            minZ = 8.0,
            maxZ = 15.0,
        },
        
        duty = {
            clockIn = {
                coords = vec3(-1528.45, -890.67, 10.21),
                heading = 40.0,
                label = 'Clock In/Out',
                targetSize = vec3(1.0, 1.0, 2.0),
            },
            locker = {
                coords = vec3(-1526.78, -891.23, 10.21),
                heading = 130.0,
                label = 'Employee Locker',
                targetSize = vec3(1.5, 0.5, 2.0),
            },
        },
        
        -- Smaller station setup for pier location
        stations = {
            ['grill_1'] = {
                type = 'grill',
                label = 'Flat Top Grill',
                coords = vec3(-1533.45, -896.78, 10.21),
                heading = 220.0,
                targetSize = vec3(1.5, 1.0, 1.0),
            },
            ['fryer_1'] = {
                type = 'fryer',
                label = 'Deep Fryer',
                coords = vec3(-1531.23, -895.45, 10.21),
                heading = 310.0,
                targetSize = vec3(0.8, 0.6, 1.0),
            },
            ['prep_1'] = {
                type = 'prep_counter',
                label = 'Prep Area',
                coords = vec3(-1529.67, -893.89, 10.21),
                heading = 40.0,
                targetSize = vec3(2.0, 1.0, 1.0),
            },
            ['soda_1'] = {
                type = 'soda_fountain',
                label = 'Drinks',
                coords = vec3(-1527.34, -892.56, 10.21),
                heading = 130.0,
                targetSize = vec3(1.0, 0.5, 1.5),
            },
            ['packaging_1'] = {
                type = 'packaging_station',
                label = 'Order Pickup',
                coords = vec3(-1526.89, -894.12, 10.21),
                heading = 220.0,
                targetSize = vec3(1.5, 0.8, 1.0),
            },
        },
        
        storage = {
            ['main_storage'] = {
                label = 'Storage',
                coords = vec3(-1535.67, -898.34, 10.21),
                heading = 220.0,
                targetSize = vec3(1.5, 1.5, 2.0),
                inventoryType = 'storage',
                slots = 40,
                weight = 80000,
                groups = { burgershot = 1 },
            },
        },
        
        customer = {
            counter = {
                coords = vec3(-1528.45, -890.34, 10.21),
                heading = 220.0,
                targetSize = vec3(2.5, 1.0, 1.5),
                label = 'Order Here',
            },
            seating = {
                { coords = vec3(-1522.34, -888.67, 10.21), heading = 0.0 },
                { coords = vec3(-1524.56, -886.89, 10.21), heading = 90.0 },
            },
        },
        
        driveThru = {
            enabled = false,            -- No drive-through at pier location
        },
        
        office = nil,                   -- No office at this smaller location
        
        cleaning = {
            { type = 'counter', coords = vec3(-1529.12, -892.45, 10.21) },
            { type = 'floor', coords = vec3(-1527.89, -889.67, 10.21) },
        },
        
        delivery = {
            vehicleSpawn = {
                coords = vec3(-1515.67, -879.34, 10.21),
                heading = 130.0,
            },
            returnPoint = {
                coords = vec3(-1530.89, -893.45, 10.21),
            },
        },
        
        breakRoom = {
            enabled = false,
        },
        
        restrooms = {},
    },
}

-- ============================================================================
-- PIZZA THIS LOCATIONS
-- ============================================================================

Config.Locations['pizzathis'] = {
    --[[
        MAIN LOCATION: Mirror Park
        Traditional Italian pizzeria
    ]]
    ['mirrorpark'] = {
        label = 'Pizza This - Mirror Park',
        shortName = 'Pizza MP',
        description = 'Family-owned pizzeria in Mirror Park',
        
        job = 'pizzathis',
        restaurantType = 'pizzeria',
        enabled = true,
        
        mlo = {
            required = true,
            resource = 'pizzathis_mlo',
            interiorId = nil,
        },
        
        entrance = {
            coords = vec3(1169.45, -323.67, 69.21),
            heading = 100.0,
            teleport = nil,
        },
        
        blip = {
            enabled = true,
            coords = vec3(1169.45, -323.67, 69.21),
            sprite = 93,
            color = 1,
            scale = 0.8,
            label = 'Pizza This',
        },
        
        zone = {
            type = 'poly',
            points = {
                vec2(1155.0, -340.0),
                vec2(1185.0, -340.0),
                vec2(1185.0, -310.0),
                vec2(1155.0, -310.0),
            },
            minZ = 67.0,
            maxZ = 75.0,
        },
        
        duty = {
            clockIn = {
                coords = vec3(1172.34, -320.56, 69.21),
                heading = 280.0,
                label = 'Clock In/Out',
                targetSize = vec3(1.0, 1.0, 2.0),
            },
            locker = {
                coords = vec3(1174.56, -318.89, 69.21),
                heading = 190.0,
                label = 'Employee Locker',
                targetSize = vec3(1.5, 0.5, 2.0),
            },
        },
        
        stations = {
            -- Pizza Oven (centerpiece)
            ['pizza_oven_1'] = {
                type = 'pizza_oven',
                label = 'Wood-Fired Pizza Oven',
                coords = vec3(1165.67, -326.34, 69.21),
                heading = 280.0,
                targetSize = vec3(2.0, 1.5, 1.5),
            },
            
            -- Prep Counter for dough and toppings
            ['prep_1'] = {
                type = 'prep_counter',
                label = 'Dough Station',
                coords = vec3(1168.23, -328.67, 69.21),
                heading = 10.0,
                targetSize = vec3(2.0, 1.0, 1.0),
            },
            ['prep_2'] = {
                type = 'prep_counter',
                label = 'Topping Station',
                coords = vec3(1170.89, -327.12, 69.21),
                heading = 100.0,
                targetSize = vec3(1.5, 0.8, 1.0),
            },
            
            -- Grill for wings and other items
            ['grill_1'] = {
                type = 'grill',
                label = 'Grill',
                coords = vec3(1163.45, -324.89, 69.21),
                heading = 280.0,
                targetSize = vec3(1.0, 1.0, 1.0),
            },
            
            -- Fryer for appetizers
            ['fryer_1'] = {
                type = 'fryer',
                label = 'Deep Fryer',
                coords = vec3(1164.78, -322.56, 69.21),
                heading = 190.0,
                targetSize = vec3(0.8, 0.6, 1.0),
            },
            
            -- Soda Fountain
            ['soda_1'] = {
                type = 'soda_fountain',
                label = 'Drinks',
                coords = vec3(1173.12, -319.34, 69.21),
                heading = 100.0,
                targetSize = vec3(1.0, 0.5, 1.5),
            },
            
            -- Plating/Packaging
            ['plating_1'] = {
                type = 'plating_station',
                label = 'Plating Station',
                coords = vec3(1171.56, -322.78, 69.21),
                heading = 280.0,
                targetSize = vec3(1.5, 0.8, 1.0),
            },
            ['packaging_1'] = {
                type = 'packaging_station',
                label = 'Pizza Boxes',
                coords = vec3(1175.34, -321.23, 69.21),
                heading = 10.0,
                targetSize = vec3(1.0, 1.0, 1.0),
            },
        },
        
        storage = {
            ['main_storage'] = {
                label = 'Ingredient Storage',
                coords = vec3(1160.89, -320.45, 69.21),
                heading = 280.0,
                targetSize = vec3(1.5, 1.5, 2.0),
                inventoryType = 'storage',
                slots = 50,
                weight = 100000,
                groups = { pizzathis = 1 },
            },
            ['freezer'] = {
                label = 'Walk-in Cooler',
                coords = vec3(1158.34, -318.67, 69.21),
                heading = 280.0,
                targetSize = vec3(2.0, 2.0, 2.5),
                inventoryType = 'storage',
                slots = 60,
                weight = 120000,
                groups = { pizzathis = 1 },
                decayMultiplier = 0.25,
            },
        },
        
        customer = {
            counter = {
                coords = vec3(1176.45, -323.89, 69.21),
                heading = 280.0,
                targetSize = vec3(2.5, 1.0, 1.5),
                label = 'Order Here',
            },
            seating = {
                { coords = vec3(1180.23, -326.56, 69.21), heading = 180.0 },
                { coords = vec3(1178.67, -330.12, 69.21), heading = 270.0 },
                { coords = vec3(1182.34, -328.78, 69.21), heading = 90.0 },
                { coords = vec3(1176.89, -334.45, 69.21), heading = 0.0 },
            },
        },
        
        driveThru = {
            enabled = false,
        },
        
        office = {
            coords = vec3(1162.45, -316.78, 69.21),
            heading = 100.0,
            safe = {
                coords = vec3(1161.67, -315.34, 69.21),
                heading = 10.0,
                targetSize = vec3(0.6, 0.6, 1.0),
            },
            computer = {
                coords = vec3(1163.23, -317.56, 69.21),
                heading = 190.0,
                targetSize = vec3(0.8, 0.6, 0.8),
            },
        },
        
        cleaning = {
            { type = 'counter', coords = vec3(1169.45, -325.34, 69.21) },
            { type = 'floor', coords = vec3(1177.89, -329.67, 69.21) },
            { type = 'oven', coords = vec3(1165.67, -326.34, 69.21) },
        },
        
        delivery = {
            vehicleSpawn = {
                coords = vec3(1155.67, -335.89, 69.21),
                heading = 280.0,
            },
            returnPoint = {
                coords = vec3(1169.45, -323.67, 69.21),
            },
        },
        
        breakRoom = {
            enabled = true,
            coords = vec3(1159.67, -314.23, 69.21),
            zone = {
                type = 'circle',
                radius = 2.5,
            },
        },
        
        restrooms = {
            { label = 'Restroom', coords = vec3(1183.45, -318.67, 69.21), heading = 10.0 },
        },
    },
    
    --[[
        SECONDARY LOCATION: Little Seoul
    ]]
    ['littleseoul'] = {
        label = 'Pizza This - Little Seoul',
        shortName = 'Pizza LS',
        description = 'Downtown pizzeria in Little Seoul',
        
        job = 'pizzathis',
        restaurantType = 'pizzeria',
        enabled = true,
        
        mlo = {
            required = true,
            resource = 'pizzathis_ls_mlo',
            interiorId = nil,
        },
        
        entrance = {
            coords = vec3(-761.45, -756.67, 26.33),
            heading = 0.0,
            teleport = nil,
        },
        
        blip = {
            enabled = true,
            coords = vec3(-761.45, -756.67, 26.33),
            sprite = 93,
            color = 1,
            scale = 0.7,
            label = 'Pizza This (Seoul)',
        },
        
        zone = {
            type = 'circle',
            center = vec3(-761.45, -756.67, 26.33),
            radius = 18.0,
            minZ = 24.0,
            maxZ = 32.0,
        },
        
        duty = {
            clockIn = {
                coords = vec3(-758.23, -753.45, 26.33),
                heading = 270.0,
                label = 'Clock In/Out',
                targetSize = vec3(1.0, 1.0, 2.0),
            },
            locker = {
                coords = vec3(-755.67, -754.89, 26.33),
                heading = 180.0,
                label = 'Employee Locker',
                targetSize = vec3(1.5, 0.5, 2.0),
            },
        },
        
        stations = {
            ['pizza_oven_1'] = {
                type = 'pizza_oven',
                label = 'Pizza Oven',
                coords = vec3(-765.34, -759.67, 26.33),
                heading = 90.0,
                targetSize = vec3(2.0, 1.5, 1.5),
            },
            ['prep_1'] = {
                type = 'prep_counter',
                label = 'Prep Station',
                coords = vec3(-762.89, -761.23, 26.33),
                heading = 0.0,
                targetSize = vec3(2.0, 1.0, 1.0),
            },
            ['fryer_1'] = {
                type = 'fryer',
                label = 'Fryer',
                coords = vec3(-767.12, -757.45, 26.33),
                heading = 180.0,
                targetSize = vec3(0.8, 0.6, 1.0),
            },
            ['soda_1'] = {
                type = 'soda_fountain',
                label = 'Drinks',
                coords = vec3(-756.78, -752.34, 26.33),
                heading = 270.0,
                targetSize = vec3(1.0, 0.5, 1.5),
            },
            ['packaging_1'] = {
                type = 'packaging_station',
                label = 'Packaging',
                coords = vec3(-758.45, -754.89, 26.33),
                heading = 0.0,
                targetSize = vec3(1.5, 0.8, 1.0),
            },
        },
        
        storage = {
            ['main_storage'] = {
                label = 'Storage',
                coords = vec3(-769.45, -755.23, 26.33),
                heading = 90.0,
                targetSize = vec3(1.5, 1.5, 2.0),
                inventoryType = 'storage',
                slots = 40,
                weight = 80000,
                groups = { pizzathis = 1 },
            },
        },
        
        customer = {
            counter = {
                coords = vec3(-759.67, -751.45, 26.33),
                heading = 0.0,
                targetSize = vec3(2.5, 1.0, 1.5),
                label = 'Order Here',
            },
            seating = {
                { coords = vec3(-754.23, -748.67, 26.33), heading = 90.0 },
                { coords = vec3(-752.89, -752.34, 26.33), heading = 180.0 },
            },
        },
        
        driveThru = { enabled = false },
        office = nil,
        
        cleaning = {
            { type = 'counter', coords = vec3(-760.34, -758.67, 26.33) },
            { type = 'floor', coords = vec3(-755.89, -750.23, 26.33) },
        },
        
        delivery = {
            vehicleSpawn = {
                coords = vec3(-750.67, -762.34, 26.33),
                heading = 90.0,
            },
            returnPoint = {
                coords = vec3(-761.45, -756.67, 26.33),
            },
        },
        
        breakRoom = { enabled = false },
        restrooms = {},
    },
}

-- ============================================================================
-- BEAN MACHINE LOCATIONS
-- ============================================================================

Config.Locations['beanmachine'] = {
    --[[
        MAIN LOCATION: West Vinewood
        Premium coffee shop near Eclipse Boulevard
    ]]
    ['vinewood'] = {
        label = 'Bean Machine - Vinewood',
        shortName = 'BM Vinewood',
        description = 'Trendy coffee shop in West Vinewood',
        
        job = 'beanmachine',
        restaurantType = 'coffeeshop',
        enabled = true,
        
        mlo = {
            required = true,
            resource = 'rflx_beanmachine',
            interiorId = nil,
        },
        
        entrance = {
            coords = vec3(-634.23, -227.67, 38.06),
            heading = 120.0,
            teleport = nil,
        },
        
        blip = {
            enabled = true,
            coords = vec3(-634.23, -227.67, 38.06),
            sprite = 52,
            color = 54,
            scale = 0.8,
            label = 'Bean Machine',
        },
        
        zone = {
            type = 'poly',
            points = {
                vec2(-648.0, -242.0),
                vec2(-620.0, -242.0),
                vec2(-620.0, -215.0),
                vec2(-648.0, -215.0),
            },
            minZ = 36.0,
            maxZ = 44.0,
        },
        
        duty = {
            clockIn = {
                coords = vec3(-630.45, -230.34, 38.06),
                heading = 30.0,
                label = 'Clock In/Out',
                targetSize = vec3(1.0, 1.0, 2.0),
            },
            locker = {
                coords = vec3(-628.78, -231.67, 38.06),
                heading = 120.0,
                label = 'Employee Locker',
                targetSize = vec3(1.2, 0.5, 2.0),
            },
        },
        
        stations = {
            -- Espresso Machine (main coffee station)
            ['coffee_1'] = {
                type = 'coffee_machine',
                label = 'Espresso Machine',
                coords = vec3(-636.89, -224.56, 38.06),
                heading = 300.0,
                targetSize = vec3(1.2, 0.8, 1.0),
            },
            ['coffee_2'] = {
                type = 'coffee_machine',
                label = 'Espresso Machine #2',
                coords = vec3(-638.45, -225.23, 38.06),
                heading = 300.0,
                targetSize = vec3(1.2, 0.8, 1.0),
            },
            
            -- Blender for frappes and smoothies
            ['blender_1'] = {
                type = 'blender',
                label = 'Blender Station',
                coords = vec3(-635.12, -226.89, 38.06),
                heading = 210.0,
                targetSize = vec3(0.8, 0.6, 1.0),
            },
            
            -- Prep for pastries
            ['prep_1'] = {
                type = 'prep_counter',
                label = 'Pastry Display',
                coords = vec3(-632.67, -228.45, 38.06),
                heading = 30.0,
                targetSize = vec3(1.5, 0.8, 1.0),
            },
            
            -- Oven for warming pastries
            ['oven_1'] = {
                type = 'microwave',
                label = 'Pastry Warmer',
                coords = vec3(-639.78, -227.12, 38.06),
                heading = 300.0,
                targetSize = vec3(0.6, 0.6, 0.8),
            },
            
            -- Plating/Finishing
            ['plating_1'] = {
                type = 'plating_station',
                label = 'Order Pickup',
                coords = vec3(-633.34, -225.67, 38.06),
                heading = 120.0,
                targetSize = vec3(1.5, 0.8, 1.0),
            },
        },
        
        storage = {
            ['main_storage'] = {
                label = 'Supply Storage',
                coords = vec3(-641.23, -229.45, 38.06),
                heading = 300.0,
                targetSize = vec3(1.5, 1.5, 2.0),
                inventoryType = 'storage',
                slots = 40,
                weight = 60000,
                groups = { beanmachine = 0 },
            },
            ['beans_storage'] = {
                label = 'Coffee Bean Storage',
                coords = vec3(-640.56, -231.78, 38.06),
                heading = 300.0,
                targetSize = vec3(1.0, 1.0, 1.5),
                inventoryType = 'storage',
                slots = 20,
                weight = 30000,
                groups = { beanmachine = 0 },
            },
        },
        
        customer = {
            counter = {
                coords = vec3(-631.89, -227.34, 38.06),
                heading = 120.0,
                targetSize = vec3(2.5, 1.0, 1.5),
                label = 'Order Here',
            },
            seating = {
                { coords = vec3(-626.34, -223.67, 38.06), heading = 210.0 },
                { coords = vec3(-624.78, -226.45, 38.06), heading = 300.0 },
                { coords = vec3(-628.12, -231.23, 38.06), heading = 30.0 },
                { coords = vec3(-623.56, -229.89, 38.06), heading = 120.0 },
            },
        },
        
        driveThru = { enabled = false },
        
        office = {
            coords = vec3(-643.45, -232.67, 38.06),
            heading = 300.0,
            safe = {
                coords = vec3(-644.23, -233.45, 38.06),
                heading = 210.0,
                targetSize = vec3(0.5, 0.5, 0.8),
            },
            computer = {
                coords = vec3(-642.67, -231.89, 38.06),
                heading = 30.0,
                targetSize = vec3(0.6, 0.5, 0.6),
            },
        },
        
        cleaning = {
            { type = 'counter', coords = vec3(-635.67, -225.34, 38.06) },
            { type = 'floor', coords = vec3(-627.89, -228.67, 38.06) },
            { type = 'dishes', coords = vec3(-637.45, -228.23, 38.06) },
        },
        
        delivery = {
            vehicleSpawn = {
                coords = vec3(-620.67, -235.89, 38.06),
                heading = 120.0,
            },
            returnPoint = {
                coords = vec3(-634.23, -227.67, 38.06),
            },
        },
        
        breakRoom = {
            enabled = true,
            coords = vec3(-644.89, -230.23, 38.06),
            zone = {
                type = 'circle',
                radius = 2.0,
            },
        },
        
        restrooms = {
            { label = 'Restroom', coords = vec3(-646.23, -226.78, 38.06), heading = 300.0 },
        },
    },
    
    --[[
        SECONDARY LOCATION: Del Perro Plaza
    ]]
    ['delperro'] = {
        label = 'Bean Machine - Del Perro',
        shortName = 'BM Del Perro',
        description = 'Beachside coffee shop in Del Perro Plaza',
        
        job = 'beanmachine',
        restaurantType = 'coffeeshop',
        enabled = true,
        
        mlo = {
            required = true,
            resource = 'bm_delperro',
            interiorId = nil,
        },
        
        entrance = {
            coords = vec3(-1707.45, -287.67, 46.95),
            heading = 140.0,
            teleport = nil,
        },
        
        blip = {
            enabled = true,
            coords = vec3(-1707.45, -287.67, 46.95),
            sprite = 52,
            color = 54,
            scale = 0.7,
            label = 'Bean Machine (Del Perro)',
        },
        
        zone = {
            type = 'circle',
            center = vec3(-1707.45, -287.67, 46.95),
            radius = 15.0,
            minZ = 44.0,
            maxZ = 52.0,
        },
        
        duty = {
            clockIn = {
                coords = vec3(-1704.23, -284.56, 46.95),
                heading = 50.0,
                label = 'Clock In/Out',
                targetSize = vec3(1.0, 1.0, 2.0),
            },
            locker = {
                coords = vec3(-1702.67, -285.89, 46.95),
                heading = 140.0,
                label = 'Employee Locker',
                targetSize = vec3(1.2, 0.5, 2.0),
            },
        },
        
        stations = {
            ['coffee_1'] = {
                type = 'coffee_machine',
                label = 'Espresso Machine',
                coords = vec3(-1710.34, -290.23, 46.95),
                heading = 320.0,
                targetSize = vec3(1.2, 0.8, 1.0),
            },
            ['blender_1'] = {
                type = 'blender',
                label = 'Blender',
                coords = vec3(-1708.89, -288.67, 46.95),
                heading = 230.0,
                targetSize = vec3(0.8, 0.6, 1.0),
            },
            ['prep_1'] = {
                type = 'prep_counter',
                label = 'Pastry Case',
                coords = vec3(-1706.45, -286.34, 46.95),
                heading = 50.0,
                targetSize = vec3(1.5, 0.8, 1.0),
            },
            ['plating_1'] = {
                type = 'plating_station',
                label = 'Pickup',
                coords = vec3(-1705.12, -287.89, 46.95),
                heading = 140.0,
                targetSize = vec3(1.5, 0.8, 1.0),
            },
        },
        
        storage = {
            ['main_storage'] = {
                label = 'Storage',
                coords = vec3(-1712.67, -291.45, 46.95),
                heading = 320.0,
                targetSize = vec3(1.5, 1.5, 2.0),
                inventoryType = 'storage',
                slots = 30,
                weight = 50000,
                groups = { beanmachine = 0 },
            },
        },
        
        customer = {
            counter = {
                coords = vec3(-1705.78, -285.23, 46.95),
                heading = 140.0,
                targetSize = vec3(2.0, 1.0, 1.5),
                label = 'Order Here',
            },
            seating = {
                { coords = vec3(-1701.34, -282.67, 46.95), heading = 230.0 },
                { coords = vec3(-1699.78, -285.45, 46.95), heading = 320.0 },
            },
        },
        
        driveThru = { enabled = false },
        office = nil,
        
        cleaning = {
            { type = 'counter', coords = vec3(-1708.45, -289.34, 46.95) },
            { type = 'floor', coords = vec3(-1703.89, -284.67, 46.95) },
        },
        
        delivery = {
            vehicleSpawn = {
                coords = vec3(-1695.67, -280.89, 46.95),
                heading = 140.0,
            },
            returnPoint = {
                coords = vec3(-1707.45, -287.67, 46.95),
            },
        },
        
        breakRoom = { enabled = false },
        restrooms = {},
    },
}

-- ============================================================================
-- TEQUI-LA-LA LOCATIONS
-- ============================================================================

Config.Locations['tequilala'] = {
    --[[
        MAIN LOCATION: West Vinewood
        Iconic nightclub/bar on Eclipse Boulevard
    ]]
    ['vinewood'] = {
        label = 'Tequi-la-la',
        shortName = 'Tequi-la-la',
        description = 'Legendary rock bar in West Vinewood',
        
        job = 'tequilala',
        restaurantType = 'bar',
        enabled = true,
        
        mlo = {
            required = false,           -- Has vanilla interior
            resource = nil,
            interiorId = nil,
        },
        
        entrance = {
            coords = vec3(-565.34, 276.89, 83.12),
            heading = 175.0,
            teleport = nil,
        },
        
        blip = {
            enabled = true,
            coords = vec3(-565.34, 276.89, 83.12),
            sprite = 93,
            color = 27,
            scale = 0.8,
            label = 'Tequi-la-la',
        },
        
        zone = {
            type = 'poly',
            points = {
                vec2(-580.0, 260.0),
                vec2(-545.0, 260.0),
                vec2(-545.0, 295.0),
                vec2(-580.0, 295.0),
            },
            minZ = 80.0,
            maxZ = 95.0,
        },
        
        duty = {
            clockIn = {
                coords = vec3(-561.45, 279.67, 83.12),
                heading = 85.0,
                label = 'Clock In/Out',
                targetSize = vec3(1.0, 1.0, 2.0),
            },
            locker = {
                coords = vec3(-559.78, 278.23, 83.12),
                heading = 175.0,
                label = 'Employee Locker',
                targetSize = vec3(1.5, 0.5, 2.0),
            },
        },
        
        stations = {
            -- Main Bar Station
            ['bar_1'] = {
                type = 'drink_mixer',
                label = 'Main Bar',
                coords = vec3(-567.89, 280.45, 83.12),
                heading = 265.0,
                targetSize = vec3(3.0, 1.0, 1.2),
            },
            
            -- Secondary Bar
            ['bar_2'] = {
                type = 'drink_mixer',
                label = 'Side Bar',
                coords = vec3(-564.23, 274.67, 83.12),
                heading = 355.0,
                targetSize = vec3(2.0, 1.0, 1.2),
            },
            
            -- Draft Beer Taps
            ['taps_1'] = {
                type = 'soda_fountain',       -- Repurposed for beer taps
                label = 'Beer Taps',
                coords = vec3(-569.45, 279.12, 83.12),
                heading = 175.0,
                targetSize = vec3(1.5, 0.5, 1.5),
            },
            
            -- Blender for frozen drinks
            ['blender_1'] = {
                type = 'blender',
                label = 'Frozen Drinks',
                coords = vec3(-565.67, 277.89, 83.12),
                heading = 85.0,
                targetSize = vec3(0.8, 0.6, 1.0),
            },
            
            -- Bar Food Prep (simple items)
            ['prep_1'] = {
                type = 'prep_counter',
                label = 'Bar Food Prep',
                coords = vec3(-571.23, 275.34, 83.12),
                heading = 265.0,
                targetSize = vec3(1.5, 0.8, 1.0),
            },
            
            -- Grill for bar food
            ['grill_1'] = {
                type = 'grill',
                label = 'Bar Grill',
                coords = vec3(-573.56, 273.67, 83.12),
                heading = 175.0,
                targetSize = vec3(1.0, 1.0, 1.0),
            },
            
            -- Fryer
            ['fryer_1'] = {
                type = 'fryer',
                label = 'Fryer',
                coords = vec3(-572.89, 276.23, 83.12),
                heading = 85.0,
                targetSize = vec3(0.8, 0.6, 1.0),
            },
        },
        
        storage = {
            ['main_storage'] = {
                label = 'Liquor Storage',
                coords = vec3(-574.67, 271.89, 83.12),
                heading = 265.0,
                targetSize = vec3(2.0, 1.5, 2.0),
                inventoryType = 'storage',
                slots = 60,
                weight = 100000,
                groups = { tequilala = 1 },
            },
            ['keg_storage'] = {
                label = 'Keg Room',
                coords = vec3(-576.23, 269.45, 83.12),
                heading = 175.0,
                targetSize = vec3(2.0, 2.0, 2.5),
                inventoryType = 'storage',
                slots = 30,
                weight = 150000,
                groups = { tequilala = 1 },
            },
            ['food_storage'] = {
                label = 'Food Storage',
                coords = vec3(-575.45, 274.12, 83.12),
                heading = 355.0,
                targetSize = vec3(1.5, 1.5, 2.0),
                inventoryType = 'storage',
                slots = 40,
                weight = 80000,
                groups = { tequilala = 1 },
                decayMultiplier = 0.5,
            },
        },
        
        customer = {
            counter = {
                coords = vec3(-566.78, 282.34, 83.12),
                heading = 175.0,
                targetSize = vec3(4.0, 1.0, 1.5),
                label = 'Order Here',
            },
            seating = {
                -- Bar stools
                { coords = vec3(-568.34, 284.67, 83.12), heading = 175.0 },
                { coords = vec3(-566.12, 284.89, 83.12), heading = 175.0 },
                { coords = vec3(-563.89, 284.45, 83.12), heading = 175.0 },
                -- Tables
                { coords = vec3(-555.67, 278.23, 83.12), heading = 265.0 },
                { coords = vec3(-557.23, 273.89, 83.12), heading = 85.0 },
            },
        },
        
        driveThru = { enabled = false },
        
        office = {
            coords = vec3(-577.89, 266.45, 83.12),
            heading = 265.0,
            safe = {
                coords = vec3(-578.67, 265.23, 83.12),
                heading = 175.0,
                targetSize = vec3(0.6, 0.6, 1.0),
            },
            computer = {
                coords = vec3(-576.45, 267.67, 83.12),
                heading = 355.0,
                targetSize = vec3(0.8, 0.6, 0.8),
            },
        },
        
        cleaning = {
            { type = 'bar', coords = vec3(-567.34, 281.23, 83.12) },
            { type = 'floor', coords = vec3(-560.89, 276.67, 83.12) },
            { type = 'dishes', coords = vec3(-570.45, 277.89, 83.12) },
            { type = 'restroom', coords = vec3(-551.23, 270.34, 83.12) },
        },
        
        delivery = {
            vehicleSpawn = {
                coords = vec3(-545.67, 290.89, 83.12),
                heading = 265.0,
            },
            returnPoint = {
                coords = vec3(-565.34, 276.89, 83.12),
            },
        },
        
        breakRoom = {
            enabled = true,
            coords = vec3(-579.45, 263.67, 83.12),
            zone = {
                type = 'circle',
                radius = 3.0,
            },
        },
        
        restrooms = {
            { label = 'Restroom', coords = vec3(-551.23, 268.45, 83.12), heading = 85.0 },
        },
        
        -- Special: VIP Area
        vipArea = {
            enabled = true,
            coords = vec3(-560.67, 265.23, 87.45),   -- Second floor
            zone = {
                type = 'circle',
                radius = 8.0,
            },
            requiredGrade = 2,          -- Chef+ can access
        },
        
        -- Special: Stage Area
        stage = {
            coords = vec3(-553.89, 281.67, 83.12),
            heading = 265.0,
            zone = {
                type = 'box',
                size = vec3(6.0, 4.0, 2.0),
            },
        },
    },
}

-- ============================================================================
-- CATERING DELIVERY LOCATIONS
-- Random NPC catering order destinations
-- ============================================================================

Config.Locations.CateringDestinations = {
    -- Office Buildings
    {
        label = 'Maze Bank Tower',
        coords = vec3(-75.45, -819.67, 326.17),
        heading = 70.0,
        type = 'office',
        orderSizeMultiplier = 1.5,      -- Larger orders
    },
    {
        label = 'FIB Building',
        coords = vec3(136.23, -749.89, 45.75),
        heading = 160.0,
        type = 'office',
        orderSizeMultiplier = 1.3,
    },
    {
        label = 'Arcadius Business Center',
        coords = vec3(-141.67, -621.34, 168.82),
        heading = 250.0,
        type = 'office',
        orderSizeMultiplier = 1.4,
    },
    
    -- Event Venues
    {
        label = 'Diamond Casino',
        coords = vec3(925.34, 47.89, 81.10),
        heading = 330.0,
        type = 'event',
        orderSizeMultiplier = 2.0,      -- Large party orders
    },
    {
        label = 'Vinewood Bowl',
        coords = vec3(686.67, 577.23, 130.46),
        heading = 90.0,
        type = 'event',
        orderSizeMultiplier = 2.5,
    },
    
    -- Residential
    {
        label = 'Rockford Hills Mansion',
        coords = vec3(-1521.45, 142.67, 55.65),
        heading = 310.0,
        type = 'residential',
        orderSizeMultiplier = 1.0,
    },
    {
        label = 'Vinewood Hills Estate',
        coords = vec3(-173.23, 497.89, 137.67),
        heading = 200.0,
        type = 'residential',
        orderSizeMultiplier = 1.2,
    },
    
    -- Businesses
    {
        label = 'Vanilla Unicorn',
        coords = vec3(127.89, -1298.45, 29.24),
        heading = 120.0,
        type = 'business',
        orderSizeMultiplier = 1.3,
    },
    {
        label = 'Bahama Mamas',
        coords = vec3(-1387.67, -588.23, 30.32),
        heading = 30.0,
        type = 'business',
        orderSizeMultiplier = 1.4,
    },
    
    -- Beach/Parks
    {
        label = 'Vespucci Beach Party',
        coords = vec3(-1478.45, -953.67, 7.18),
        heading = 220.0,
        type = 'outdoor',
        orderSizeMultiplier = 1.8,
    },
    {
        label = 'Legion Square Event',
        coords = vec3(195.23, -934.89, 30.69),
        heading = 50.0,
        type = 'outdoor',
        orderSizeMultiplier = 1.5,
    },
}

-- ============================================================================
-- DELIVERY ORDER DESTINATIONS
-- Random NPC delivery order drop-off points
-- ============================================================================

Config.Locations.DeliveryDestinations = {
    -- Apartments
    {
        label = 'Alta Street Apartments',
        coords = vec3(-271.45, -957.67, 31.22),
        heading = 70.0,
        tipMultiplier = 1.0,
    },
    {
        label = 'Integrity Way Apartments',
        coords = vec3(-47.23, -585.89, 37.78),
        heading = 160.0,
        tipMultiplier = 1.1,
    },
    {
        label = 'Del Perro Heights',
        coords = vec3(-1447.67, -538.34, 34.74),
        heading = 210.0,
        tipMultiplier = 1.2,
    },
    {
        label = 'Eclipse Towers',
        coords = vec3(-773.45, 312.67, 85.70),
        heading = 0.0,
        tipMultiplier = 1.5,            -- Rich area, better tips
    },
    {
        label = 'Weazel Plaza',
        coords = vec3(-903.23, -369.89, 113.08),
        heading = 300.0,
        tipMultiplier = 1.3,
    },
    
    -- Houses
    {
        label = 'Mirror Park House',
        coords = vec3(1259.67, -1732.45, 54.77),
        heading = 290.0,
        tipMultiplier = 0.9,
    },
    {
        label = 'Vinewood Hills House',
        coords = vec3(340.23, 437.89, 149.39),
        heading = 160.0,
        tipMultiplier = 1.4,
    },
    {
        label = 'Chumash House',
        coords = vec3(-3156.45, 1128.67, 20.86),
        heading = 260.0,
        tipMultiplier = 1.0,
    },
    
    -- Motels/Hotels
    {
        label = 'Pink Cage Motel',
        coords = vec3(327.67, -224.23, 54.22),
        heading = 160.0,
        tipMultiplier = 0.8,
    },
    {
        label = 'Gentry Manor Hotel',
        coords = vec3(-109.45, -620.67, 36.28),
        heading = 250.0,
        tipMultiplier = 1.3,
    },
    
    -- Workplaces
    {
        label = 'LS Customs',
        coords = vec3(-356.23, -132.89, 39.01),
        heading = 110.0,
        tipMultiplier = 1.0,
    },
    {
        label = 'Bennys Motorworks',
        coords = vec3(-211.67, -1324.45, 30.89),
        heading = 180.0,
        tipMultiplier = 1.0,
    },
    {
        label = 'Pillbox Hospital',
        coords = vec3(311.45, -591.67, 43.28),
        heading = 70.0,
        tipMultiplier = 1.2,
    },
    {
        label = 'Mission Row PD',
        coords = vec3(441.23, -981.89, 30.69),
        heading = 90.0,
        tipMultiplier = 1.1,
    },
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

--- Get all locations for a specific job
---@param jobName string The job name
---@return table All location configs for that job
function Config.GetJobLocations(jobName)
    return Config.Locations[jobName] or {}
end

--- Get a specific location by job and location key
---@param jobName string The job name
---@param locationKey string The location key
---@return table|nil Location config or nil
function Config.GetLocation(jobName, locationKey)
    local jobLocations = Config.Locations[jobName]
    if not jobLocations then return nil end
    return jobLocations[locationKey]
end

--- Get all enabled locations for a job
---@param jobName string The job name
---@return table Array of enabled location keys
function Config.GetEnabledLocations(jobName)
    local locations = {}
    local jobLocations = Config.Locations[jobName]
    if not jobLocations then return locations end
    
    for key, location in pairs(jobLocations) do
        if location.enabled then
            locations[#locations + 1] = key
        end
    end
    return locations
end

--- Get all station configs for a specific location
---@param jobName string The job name
---@param locationKey string The location key
---@return table Station configurations
function Config.GetLocationStations(jobName, locationKey)
    local location = Config.GetLocation(jobName, locationKey)
    if not location then return {} end
    return location.stations or {}
end

--- Get storage configs for a location
---@param jobName string The job name
---@param locationKey string The location key
---@return table Storage configurations
function Config.GetLocationStorages(jobName, locationKey)
    local location = Config.GetLocation(jobName, locationKey)
    if not location then return {} end
    return location.storage or {}
end

--- Check if a location requires a specific MLO
---@param jobName string The job name
---@param locationKey string The location key
---@return boolean, string|nil Whether MLO is required and resource name
function Config.LocationRequiresMlo(jobName, locationKey)
    local location = Config.GetLocation(jobName, locationKey)
    if not location or not location.mlo then
        return false, nil
    end
    return location.mlo.required, location.mlo.resource
end

--- Get blip config for a location
---@param jobName string The job name
---@param locationKey string The location key
---@return table|nil Blip configuration
function Config.GetLocationBlip(jobName, locationKey)
    local location = Config.GetLocation(jobName, locationKey)
    if not location then return nil end
    return location.blip
end

--- Get all locations with their full paths
---@return table Array of {job, key, config} tables
function Config.GetAllLocations()
    local all = {}
    for jobName, locations in pairs(Config.Locations) do
        if type(locations) == 'table' and jobName ~= 'Settings' 
           and jobName ~= 'CateringDestinations' and jobName ~= 'DeliveryDestinations' then
            for locationKey, config in pairs(locations) do
                all[#all + 1] = {
                    job = jobName,
                    key = locationKey,
                    config = config,
                }
            end
        end
    end
    return all
end

--- Get random catering destination
---@param excludeType? string Type to exclude (optional)
---@return table Catering destination
function Config.GetRandomCateringDestination(excludeType)
    local destinations = {}
    for _, dest in ipairs(Config.Locations.CateringDestinations) do
        if not excludeType or dest.type ~= excludeType then
            destinations[#destinations + 1] = dest
        end
    end
    
    if #destinations == 0 then
        return Config.Locations.CateringDestinations[1]
    end
    
    return destinations[math.random(1, #destinations)]
end

--- Get random delivery destination
---@return table Delivery destination
function Config.GetRandomDeliveryDestination()
    local destinations = Config.Locations.DeliveryDestinations
    return destinations[math.random(1, #destinations)]
end

--- Find nearest location to coordinates
---@param coords vector3 Player coordinates
---@param jobName? string Optional job filter
---@return table|nil Nearest location info {job, key, distance}
function Config.FindNearestLocation(coords, jobName)
    local nearest = nil
    local nearestDist = math.huge
    
    local allLocations = Config.GetAllLocations()
    
    for _, loc in ipairs(allLocations) do
        if not jobName or loc.job == jobName then
            if loc.config.entrance and loc.config.entrance.coords then
                local dist = #(coords - loc.config.entrance.coords)
                if dist < nearestDist then
                    nearestDist = dist
                    nearest = {
                        job = loc.job,
                        key = loc.key,
                        distance = dist,
                        config = loc.config,
                    }
                end
            end
        end
    end
    
    return nearest
end

--- Check if coordinates are within a location's zone
---@param coords vector3 Coordinates to check
---@param jobName string The job name
---@param locationKey string The location key
---@return boolean
function Config.IsInLocationZone(coords, jobName, locationKey)
    local location = Config.GetLocation(jobName, locationKey)
    if not location or not location.zone then return false end
    
    local zone = location.zone
    
    -- Check Z bounds
    if coords.z < (zone.minZ or -999) or coords.z > (zone.maxZ or 999) then
        return false
    end
    
    if zone.type == 'circle' then
        local center = zone.center or location.entrance.coords
        local dist = #(vec2(coords.x, coords.y) - vec2(center.x, center.y))
        return dist <= (zone.radius or 20.0)
    elseif zone.type == 'poly' then
        -- Simple point-in-polygon check
        return Config.Utils.PointInPolygon(vec2(coords.x, coords.y), zone.points)
    elseif zone.type == 'box' then
        -- Box check would go here
        return false
    end
    
    return false
end

-- Point-in-polygon utility
Config.Utils = Config.Utils or {}
function Config.Utils.PointInPolygon(point, polygon)
    local inside = false
    local j = #polygon
    
    for i = 1, #polygon do
        local xi, yi = polygon[i].x, polygon[i].y
        local xj, yj = polygon[j].x, polygon[j].y
        
        if ((yi > point.y) ~= (yj > point.y)) and
           (point.x < (xj - xi) * (point.y - yi) / (yj - yi) + xi) then
            inside = not inside
        end
        
        j = i
    end
    
    return inside
end

return Config
