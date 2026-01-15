--[[
    free-restaurants Ordering System Configuration

    Defines:
    - Self-service kiosk locations
    - Employee register locations
    - KDS monitor placements
    - Order flow settings
    - Receipt configuration
]]

Config = Config or {}
Config.Ordering = Config.Ordering or {}

-- ============================================================================
-- GENERAL ORDERING SETTINGS
-- ============================================================================

Config.Ordering.Settings = {
    -- Order numbering
    orderPrefix = '',                   -- Prefix for order numbers (e.g., 'BS-' for BurgerShot)
    orderNumberLength = 4,              -- Digits in order number

    -- Receipt settings
    receipt = {
        printSound = true,              -- Play sound when receipt prints
        showOnKDS = true,               -- Show new orders on KDS
        notifyStaff = true,             -- Notify on-duty staff
        expiryMinutes = 30,             -- Order expires after this time
    },

    -- Kiosk settings
    kiosk = {
        idleTimeout = 60,               -- Seconds before kiosk returns to idle
        maxItemsPerOrder = 20,          -- Maximum items in one order
        allowCustomizations = true,     -- Allow item customizations
        paymentMethods = {'cash', 'card'},
    },

    -- Register settings (employee-operated)
    register = {
        requireDuty = true,             -- Must be on duty to use
        minGrade = 0,                   -- Minimum job grade
        canTakePayment = true,          -- Can process payments
        canCreateTabs = false,          -- Can create customer tabs (future)
    },

    -- KDS settings
    kds = {
        autoRefresh = 5,                -- Seconds between auto-refresh
        soundOnNew = true,              -- Play sound on new order
        flashUrgent = true,             -- Flash urgent orders
        urgentThreshold = 300,          -- Seconds until order is urgent
        maxDisplayed = 12,              -- Max orders shown at once
        colorCoding = {
            pending = '#3B82F6',         -- Blue
            in_progress = '#F59E0B',     -- Amber/Orange
            ready = '#22C55E',           -- Green
            urgent = '#EF4444',          -- Red
        },
    },
}

-- ============================================================================
-- KDS MONITOR PROPS
-- GTA V prop models that can be used for KDS displays
-- ============================================================================

Config.Ordering.KDSProps = {
    -- Computer monitors
    'prop_monitor_02',                  -- Standard office monitor
    'prop_monitor_03b',                 -- Another office monitor
    'prop_tv_flat_01',                  -- Flat screen TV
    'prop_tv_flat_02',                  -- Another flat TV
    'prop_tv_flat_02b',                 -- Flat TV variant
    'prop_tv_flat_03',                  -- Large flat TV
    'prop_tv_flat_03b',                 -- Large flat TV variant
    'prop_cs_tv',                       -- CS TV prop
    'des_tvsmash_start',                -- Damaged TV (for humor)
    'prop_trev_tv_01',                  -- Trevor's TV
    'prop_tv_06',                       -- TV variant
    'hei_prop_dlc_tablet',              -- Heist tablet
    'prop_cs_tablet',                   -- Tablet prop
}

-- ============================================================================
-- DEFAULT ORDERING POINTS TEMPLATE
-- Use this as a template when adding ordering to locations
-- ============================================================================

Config.Ordering.DefaultTemplate = {
    -- Self-service kiosks (for customers)
    kiosks = {
        --[[
        ['kiosk_1'] = {
            coords = vec3(0, 0, 0),
            heading = 0.0,
            label = 'Self-Order Kiosk',
            targetSize = vec3(0.8, 0.3, 1.5),
            prop = 'prop_cs_tablet',     -- Optional: spawn this prop
            enabled = true,
        },
        ]]
    },

    -- Employee registers (for staff taking orders)
    registers = {
        --[[
        ['register_1'] = {
            coords = vec3(0, 0, 0),
            heading = 0.0,
            label = 'Register',
            targetSize = vec3(0.6, 0.4, 0.5),
            minGrade = 0,
            enabled = true,
        },
        ]]
    },

    -- KDS monitors (for kitchen staff)
    kdsMonitors = {
        --[[
        ['kds_1'] = {
            coords = vec3(0, 0, 0),
            heading = 0.0,
            label = 'Kitchen Display',
            targetSize = vec3(0.8, 0.1, 0.6),
            prop = 'prop_tv_flat_01',    -- Monitor prop model
            renderTarget = true,          -- Use render target for live display
            minGrade = 0,
            enabled = true,
        },
        ]]
    },

    -- Order pickup counter
    pickupCounter = {
        --[[
        coords = vec3(0, 0, 0),
        heading = 0.0,
        label = 'Order Pickup',
        targetSize = vec3(2.0, 1.0, 1.5),
        enabled = true,
        ]]
    },
}

-- ============================================================================
-- BURGER SHOT ORDERING POINTS
-- ============================================================================

Config.Ordering['burgershot'] = {
    ['vespucci'] = {
        -- Self-service kiosks
        kiosks = {
            ['kiosk_1'] = {
                coords = vec3(-1192.45, -894.32, 14.0),
                heading = 35.0,
                label = 'Self-Order Kiosk #1',
                targetSize = vec3(0.8, 0.3, 1.5),
                enabled = true,
            },
            ['kiosk_2'] = {
                coords = vec3(-1191.12, -893.45, 14.0),
                heading = 35.0,
                label = 'Self-Order Kiosk #2',
                targetSize = vec3(0.8, 0.3, 1.5),
                enabled = true,
            },
        },

        -- Employee registers
        registers = {
            ['register_1'] = {
                coords = vec3(-1195.67, -897.89, 14.0),
                heading = 215.0,
                label = 'Register #1',
                targetSize = vec3(0.6, 0.4, 0.5),
                minGrade = 0,
                enabled = true,
            },
            ['register_2'] = {
                coords = vec3(-1194.23, -898.56, 14.0),
                heading = 215.0,
                label = 'Register #2',
                targetSize = vec3(0.6, 0.4, 0.5),
                minGrade = 0,
                enabled = true,
            },
        },

        -- KDS monitors
        kdsMonitors = {
            ['kds_main'] = {
                coords = vec3(-1201.34, -899.23, 15.2),
                heading = 35.0,
                label = 'Kitchen Display',
                targetSize = vec3(0.8, 0.1, 0.6),
                prop = 'prop_tv_flat_01',
                renderTarget = true,
                minGrade = 0,
                enabled = true,
            },
            ['kds_expedite'] = {
                coords = vec3(-1197.89, -900.45, 15.2),
                heading = 215.0,
                label = 'Expedite Display',
                targetSize = vec3(0.8, 0.1, 0.6),
                prop = 'prop_tv_flat_02',
                renderTarget = true,
                minGrade = 1,
                enabled = true,
            },
        },

        -- Pickup counter
        pickupCounter = {
            coords = vec3(-1194.67, -899.71, 14.0),
            heading = 215.0,
            label = 'Order Pickup',
            targetSize = vec3(2.0, 1.0, 1.5),
            enabled = true,
        },

        -- Drive-thru window for order entry
        driveThruRegister = {
            coords = vec3(-1202.34, -908.67, 14.0),
            heading = 125.0,
            label = 'Drive-Thru Window',
            targetSize = vec3(1.0, 0.5, 1.5),
            minGrade = 0,
            enabled = true,
        },
    },

    ['delperro'] = {
        kiosks = {
            ['kiosk_1'] = {
                coords = vec3(-1527.45, -889.67, 10.21),
                heading = 40.0,
                label = 'Self-Order Kiosk',
                targetSize = vec3(0.8, 0.3, 1.5),
                enabled = true,
            },
        },

        registers = {
            ['register_1'] = {
                coords = vec3(-1528.89, -891.23, 10.21),
                heading = 220.0,
                label = 'Register',
                targetSize = vec3(0.6, 0.4, 0.5),
                minGrade = 0,
                enabled = true,
            },
        },

        kdsMonitors = {
            ['kds_main'] = {
                coords = vec3(-1532.45, -894.67, 11.5),
                heading = 220.0,
                label = 'Kitchen Display',
                targetSize = vec3(0.8, 0.1, 0.6),
                prop = 'prop_tv_flat_02',
                renderTarget = true,
                minGrade = 0,
                enabled = true,
            },
        },

        pickupCounter = {
            coords = vec3(-1526.89, -894.12, 10.21),
            heading = 220.0,
            label = 'Order Pickup',
            targetSize = vec3(1.5, 0.8, 1.5),
            enabled = true,
        },
    },
}

-- ============================================================================
-- PIZZA THIS ORDERING POINTS
-- ============================================================================

Config.Ordering['pizzathis'] = {
    ['mirrorpark'] = {
        kiosks = {
            ['kiosk_1'] = {
                coords = vec3(1179.45, -320.67, 69.21),
                heading = 280.0,
                label = 'Self-Order Kiosk',
                targetSize = vec3(0.8, 0.3, 1.5),
                enabled = true,
            },
        },

        registers = {
            ['register_1'] = {
                coords = vec3(1176.23, -323.45, 69.21),
                heading = 280.0,
                label = 'Register',
                targetSize = vec3(0.6, 0.4, 0.5),
                minGrade = 0,
                enabled = true,
            },
        },

        kdsMonitors = {
            ['kds_main'] = {
                coords = vec3(1167.89, -325.12, 70.5),
                heading = 280.0,
                label = 'Kitchen Display',
                targetSize = vec3(0.8, 0.1, 0.6),
                prop = 'prop_tv_flat_01',
                renderTarget = true,
                minGrade = 0,
                enabled = true,
            },
        },

        pickupCounter = {
            coords = vec3(1175.34, -321.23, 69.21),
            heading = 280.0,
            label = 'Order Pickup',
            targetSize = vec3(1.5, 0.8, 1.5),
            enabled = true,
        },
    },

    ['littleseoul'] = {
        kiosks = {
            ['kiosk_1'] = {
                coords = vec3(-755.67, -749.89, 26.33),
                heading = 0.0,
                label = 'Self-Order Kiosk',
                targetSize = vec3(0.8, 0.3, 1.5),
                enabled = true,
            },
        },

        registers = {
            ['register_1'] = {
                coords = vec3(-759.23, -752.45, 26.33),
                heading = 0.0,
                label = 'Register',
                targetSize = vec3(0.6, 0.4, 0.5),
                minGrade = 0,
                enabled = true,
            },
        },

        kdsMonitors = {
            ['kds_main'] = {
                coords = vec3(-764.45, -758.67, 27.6),
                heading = 90.0,
                label = 'Kitchen Display',
                targetSize = vec3(0.8, 0.1, 0.6),
                prop = 'prop_tv_flat_02',
                renderTarget = true,
                minGrade = 0,
                enabled = true,
            },
        },

        pickupCounter = {
            coords = vec3(-758.45, -754.89, 26.33),
            heading = 0.0,
            label = 'Order Pickup',
            targetSize = vec3(1.5, 0.8, 1.5),
            enabled = true,
        },
    },
}

-- ============================================================================
-- BEAN MACHINE ORDERING POINTS
-- ============================================================================

Config.Ordering['beanmachine'] = {
    ['vinewood'] = {
        kiosks = {
            ['kiosk_1'] = {
                coords = vec3(-628.45, -224.67, 38.06),
                heading = 30.0,
                label = 'Self-Order Kiosk',
                targetSize = vec3(0.8, 0.3, 1.5),
                enabled = true,
            },
        },

        registers = {
            ['register_1'] = {
                coords = vec3(-631.67, -226.89, 38.06),
                heading = 120.0,
                label = 'Register',
                targetSize = vec3(0.6, 0.4, 0.5),
                minGrade = 0,
                enabled = true,
            },
        },

        kdsMonitors = {
            ['kds_main'] = {
                coords = vec3(-637.89, -225.45, 39.3),
                heading = 300.0,
                label = 'Order Display',
                targetSize = vec3(0.8, 0.1, 0.6),
                prop = 'prop_tv_flat_02',
                renderTarget = true,
                minGrade = 0,
                enabled = true,
            },
        },

        pickupCounter = {
            coords = vec3(-633.34, -225.67, 38.06),
            heading = 120.0,
            label = 'Order Pickup',
            targetSize = vec3(1.5, 0.8, 1.5),
            enabled = true,
        },
    },

    ['delperro'] = {
        kiosks = {},  -- No kiosk at this smaller location

        registers = {
            ['register_1'] = {
                coords = vec3(-1705.45, -285.67, 46.95),
                heading = 140.0,
                label = 'Register',
                targetSize = vec3(0.6, 0.4, 0.5),
                minGrade = 0,
                enabled = true,
            },
        },

        kdsMonitors = {
            ['kds_main'] = {
                coords = vec3(-1709.67, -289.23, 48.2),
                heading = 320.0,
                label = 'Order Display',
                targetSize = vec3(0.8, 0.1, 0.6),
                prop = 'prop_tv_flat_02',
                renderTarget = true,
                minGrade = 0,
                enabled = true,
            },
        },

        pickupCounter = {
            coords = vec3(-1705.12, -287.89, 46.95),
            heading = 140.0,
            label = 'Order Pickup',
            targetSize = vec3(1.5, 0.8, 1.5),
            enabled = true,
        },
    },
}

-- ============================================================================
-- TEQUI-LA-LA ORDERING POINTS
-- ============================================================================

Config.Ordering['tequilala'] = {
    ['vinewood'] = {
        kiosks = {},  -- No self-service at a bar

        registers = {
            ['register_main'] = {
                coords = vec3(-567.45, 281.23, 83.12),
                heading = 265.0,
                label = 'Main Bar Register',
                targetSize = vec3(0.6, 0.4, 0.5),
                minGrade = 0,
                enabled = true,
            },
            ['register_side'] = {
                coords = vec3(-563.89, 275.45, 83.12),
                heading = 355.0,
                label = 'Side Bar Register',
                targetSize = vec3(0.6, 0.4, 0.5),
                minGrade = 0,
                enabled = true,
            },
        },

        kdsMonitors = {
            ['kds_bar'] = {
                coords = vec3(-569.67, 278.89, 84.4),
                heading = 175.0,
                label = 'Bar Orders',
                targetSize = vec3(0.8, 0.1, 0.6),
                prop = 'prop_tv_flat_02',
                renderTarget = true,
                minGrade = 0,
                enabled = true,
            },
            ['kds_kitchen'] = {
                coords = vec3(-572.45, 274.67, 84.4),
                heading = 265.0,
                label = 'Food Orders',
                targetSize = vec3(0.8, 0.1, 0.6),
                prop = 'prop_tv_flat_01',
                renderTarget = true,
                minGrade = 1,
                enabled = true,
            },
        },

        pickupCounter = {
            coords = vec3(-566.78, 282.34, 83.12),
            heading = 175.0,
            label = 'Order Pickup',
            targetSize = vec3(2.0, 1.0, 1.5),
            enabled = true,
        },
    },
}

-- ============================================================================
-- TACO FARMER ORDERING POINTS
-- ============================================================================

Config.Ordering['tacofarmer'] = {
    ['pilsen'] = {
        kiosks = {
            ['kiosk_1'] = {
                coords = vec3(15.0, -1598.0, 29.4),
                heading = 140.0,
                label = 'Self-Order Kiosk',
                targetSize = vec3(0.8, 0.3, 1.5),
                enabled = true,
            },
        },

        registers = {
            ['register_1'] = {
                coords = vec3(12.0, -1600.0, 29.4),
                heading = 140.0,
                label = 'Register',
                targetSize = vec3(0.6, 0.4, 0.5),
                minGrade = 0,
                enabled = true,
            },
        },

        kdsMonitors = {
            ['kds_main'] = {
                coords = vec3(6.0, -1607.0, 30.7),
                heading = 320.0,
                label = 'Kitchen Display',
                targetSize = vec3(0.8, 0.1, 0.6),
                prop = 'prop_tv_flat_01',
                renderTarget = true,
                minGrade = 0,
                enabled = true,
            },
        },

        pickupCounter = {
            coords = vec3(13.0, -1599.0, 29.4),
            heading = 50.0,
            label = 'Order Pickup',
            targetSize = vec3(1.5, 0.8, 1.5),
            enabled = true,
        },
    },
}

-- ============================================================================
-- SUSHI RESTAURANT (BENIHANA) ORDERING POINTS
-- ============================================================================

Config.Ordering['benihana'] = {
    ['downtown'] = {
        kiosks = {},  -- No self-service at upscale restaurant

        registers = {
            ['register_host'] = {
                coords = vec3(-500.0, 200.0, 35.0),  -- Adjust to actual MLO
                heading = 0.0,
                label = 'Host Stand',
                targetSize = vec3(0.8, 0.6, 1.2),
                minGrade = 0,  -- Host grade
                enabled = true,
            },
            ['register_bar'] = {
                coords = vec3(-505.0, 205.0, 35.0),  -- Adjust to actual MLO
                heading = 90.0,
                label = 'Sake Bar Register',
                targetSize = vec3(0.6, 0.4, 0.5),
                minGrade = 1,  -- Server grade
                enabled = true,
            },
        },

        kdsMonitors = {
            ['kds_sushi'] = {
                coords = vec3(-510.0, 210.0, 36.3),  -- Adjust to actual MLO
                heading = 180.0,
                label = 'Sushi Orders',
                targetSize = vec3(0.8, 0.1, 0.6),
                prop = 'prop_tv_flat_01',
                renderTarget = true,
                minGrade = 2,  -- Sushi chef
                enabled = true,
            },
            ['kds_teppanyaki'] = {
                coords = vec3(-515.0, 215.0, 36.3),  -- Adjust to actual MLO
                heading = 270.0,
                label = 'Teppanyaki Orders',
                targetSize = vec3(0.8, 0.1, 0.6),
                prop = 'prop_tv_flat_02',
                renderTarget = true,
                minGrade = 3,  -- Teppanyaki chef
                enabled = true,
            },
            ['kds_expedite'] = {
                coords = vec3(-508.0, 208.0, 36.3),  -- Adjust to actual MLO
                heading = 0.0,
                label = 'Expedite Display',
                targetSize = vec3(0.8, 0.1, 0.6),
                prop = 'prop_tv_flat_03',
                renderTarget = true,
                minGrade = 4,  -- Head chef
                enabled = true,
            },
        },

        pickupCounter = {
            coords = vec3(-502.0, 202.0, 35.0),  -- Adjust to actual MLO
            heading = 0.0,
            label = 'Server Station',
            targetSize = vec3(2.0, 1.0, 1.5),
            enabled = true,
        },
    },
}

-- ============================================================================
-- RECEIPT TEMPLATES
-- ============================================================================

Config.Ordering.ReceiptTemplate = {
    -- Header
    header = {
        showLogo = true,
        showDateTime = true,
        showLocation = true,
        showOrderNumber = true,
    },

    -- Body
    body = {
        showItems = true,
        showCustomizations = true,
        showSubtotal = true,
        showTax = true,
        showTotal = true,
        showPaymentMethod = true,
    },

    -- Footer
    footer = {
        message = 'Thank you for your order!',
        showEstimatedTime = true,
    },
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

--- Get ordering config for a specific location
---@param jobName string The job name (e.g., 'burgershot')
---@param locationKey string The location key (e.g., 'vespucci')
---@return table|nil Ordering configuration
function Config.GetOrderingConfig(jobName, locationKey)
    if not Config.Ordering[jobName] then return nil end
    return Config.Ordering[jobName][locationKey]
end

--- Get all kiosks for a location
---@param jobName string
---@param locationKey string
---@return table Kiosks table
function Config.GetKiosks(jobName, locationKey)
    local orderingConfig = Config.GetOrderingConfig(jobName, locationKey)
    if not orderingConfig then return {} end
    return orderingConfig.kiosks or {}
end

--- Get all registers for a location
---@param jobName string
---@param locationKey string
---@return table Registers table
function Config.GetRegisters(jobName, locationKey)
    local orderingConfig = Config.GetOrderingConfig(jobName, locationKey)
    if not orderingConfig then return {} end
    return orderingConfig.registers or {}
end

--- Get all KDS monitors for a location
---@param jobName string
---@param locationKey string
---@return table KDS monitors table
function Config.GetKDSMonitors(jobName, locationKey)
    local orderingConfig = Config.GetOrderingConfig(jobName, locationKey)
    if not orderingConfig then return {} end
    return orderingConfig.kdsMonitors or {}
end

--- Get pickup counter for a location
---@param jobName string
---@param locationKey string
---@return table|nil Pickup counter config
function Config.GetPickupCounter(jobName, locationKey)
    local orderingConfig = Config.GetOrderingConfig(jobName, locationKey)
    if not orderingConfig then return nil end
    return orderingConfig.pickupCounter
end

return Config
