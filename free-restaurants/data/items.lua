--[[
    free-restaurants Item Definitions for ox_inventory

    Add these items to your ox_inventory items.lua file:

    ['restaurant_receipt'] = {
        label = 'Restaurant Receipt',
        weight = 0,
        stack = true,
        close = true,
        description = 'A receipt from a restaurant order',
        client = {
            usetime = 1000,
        }
    },
]]

-- This file provides the item definitions that should be added to ox_inventory
-- Copy the item definition above to your ox_inventory/data/items.lua

return {
    ['restaurant_receipt'] = {
        label = 'Restaurant Receipt',
        weight = 0,
        stack = true,
        close = true,
        description = 'A receipt from a restaurant order',
        client = {
            usetime = 1000,
        }
    },
}
