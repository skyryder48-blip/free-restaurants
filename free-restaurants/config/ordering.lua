--[[
    free-restaurants Ordering System Configuration - MINIMAL TEST VERSION
]]

print('[free-restaurants] *** ORDERING CONFIG LOADING - START ***')

Config = Config or {}
Config.Ordering = Config.Ordering or {}

-- Minimal settings
Config.Ordering.Settings = {
    orderPrefix = '',
    orderNumberLength = 4,
    receipt = { printSound = true, showOnKDS = true, notifyStaff = true, expiryMinutes = 30 },
    kiosk = { idleTimeout = 60, maxItemsPerOrder = 20, allowCustomizations = true, paymentMethods = {'cash', 'card'} },
    register = { requireDuty = true, minGrade = 0, canTakePayment = true, canCreateTabs = false },
    kds = { autoRefresh = 5, soundOnNew = true, flashUrgent = true, urgentThreshold = 300, maxDisplayed = 12 },
}

-- Minimal burgershot config for testing
Config.Ordering['burgershot'] = {
    ['vespucci'] = {
        kiosks = {
            ['kiosk_1'] = {
                coords = vec3(-1192.45, -894.32, 14.0),
                heading = 35.0,
                label = 'Self-Order Kiosk #1',
                targetSize = vec3(0.8, 0.3, 1.5),
                enabled = true,
            },
        },
        registers = {
            ['register_1'] = {
                coords = vec3(-1195.67, -897.89, 14.0),
                heading = 215.0,
                label = 'Register #1',
                targetSize = vec3(0.6, 0.4, 0.5),
                minGrade = 0,
                enabled = true,
            },
        },
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
        },
        pickupCounter = {
            coords = vec3(-1194.67, -899.71, 14.0),
            heading = 215.0,
            label = 'Order Pickup',
            targetSize = vec3(2.0, 1.0, 1.5),
            enabled = true,
        },
    },
}

-- Utility functions
function Config.GetOrderingConfig(jobName, locationKey)
    if not Config.Ordering[jobName] then return nil end
    return Config.Ordering[jobName][locationKey]
end

function Config.GetKiosks(jobName, locationKey)
    local orderingConfig = Config.GetOrderingConfig(jobName, locationKey)
    if not orderingConfig then return {} end
    return orderingConfig.kiosks or {}
end

function Config.GetRegisters(jobName, locationKey)
    local orderingConfig = Config.GetOrderingConfig(jobName, locationKey)
    if not orderingConfig then return {} end
    return orderingConfig.registers or {}
end

function Config.GetKDSMonitors(jobName, locationKey)
    local orderingConfig = Config.GetOrderingConfig(jobName, locationKey)
    if not orderingConfig then return {} end
    return orderingConfig.kdsMonitors or {}
end

function Config.GetPickupCounter(jobName, locationKey)
    local orderingConfig = Config.GetOrderingConfig(jobName, locationKey)
    if not orderingConfig then return nil end
    return orderingConfig.pickupCounter
end

print('[free-restaurants] *** ORDERING CONFIG LOADING - END ***')
