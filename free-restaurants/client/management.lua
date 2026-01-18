--[[
    free-restaurants Client Management System
    
    Handles:
    - Boss menu interface
    - Employee management (hire, fire, promote)
    - Payroll and wages
    - Business finances
    - Stock/inventory ordering
    - Menu pricing
    
    DEPENDENCIES:
    - client/main.lua (state management)
    - ox_lib (UI components)
]]

-- ============================================================================
-- LOCAL STATE
-- ============================================================================

local managementTargets = {}
local storageTargets = {}
local cachedGradeData = nil  -- Cache the grade data for permission checks

-- Forward declarations for functions used before definition
local openManagementMenu
local openEmployeeMenu
local openEmployeeActions
local hireEmployee
local promoteEmployee
local demoteEmployee
local setEmployeeGrade
local fireEmployee
local openFinancesMenu
local withdrawFunds
local depositFunds
local viewTransactions
local openStockMenu
local orderStock
local openPricingMenu
local setItemPrice
local openPayrollMenu
local setWage
local openBusinessStorage

--- Local helper to check permissions directly from Config (bypasses hasPermission)
---@param permission string Permission key
---@return boolean
local function hasPermission(permission)
    local job = FreeRestaurants.Client.GetPlayerState('job')
    local grade = FreeRestaurants.Client.GetPlayerState('grade') or 0

    if not job then return false end

    local jobConfig = Config.Jobs[job]
    if not jobConfig then return false end

    -- Find grade data with fallback
    local gradeData = jobConfig.grades[grade]
    if not gradeData then
        local maxGrade = -1
        for g, _ in pairs(jobConfig.grades) do
            if type(g) == 'number' and g > maxGrade then
                maxGrade = g
            end
        end
        if maxGrade >= 0 then
            gradeData = jobConfig.grades[maxGrade]
        end
    end

    if not gradeData or not gradeData.permissions then
        return false
    end

    -- Owner has all permissions
    if gradeData.permissions.all == true then
        return true
    end

    return gradeData.permissions[permission] == true
end

-- ============================================================================
-- STORAGE SYSTEM
-- ============================================================================

--- Open a storage inventory
---@param storageKey string Storage identifier
---@param storageData table Storage configuration
---@param locationKey string Location identifier
local function openStorage(storageKey, storageData, locationKey)
    local stashId = ('restaurant_%s_%s'):format(locationKey, storageKey)

    -- Request server to open/create the stash
    TriggerServerEvent('free-restaurants:server:openStorage', stashId, {
        label = storageData.label or 'Storage',
        slots = storageData.slots or 50,
        weight = storageData.weight or 100000,
        groups = storageData.groups,
    })
end

--- Setup storage targets for all locations
local function setupStorageTargets()
    -- Remove existing targets
    for targetId in pairs(storageTargets) do
        exports.ox_target:removeZone(targetId)
    end
    storageTargets = {}

    for restaurantType, locations in pairs(Config.Locations) do
        if type(locations) == 'table' and restaurantType ~= 'Settings'
           and restaurantType ~= 'CateringDestinations'
           and restaurantType ~= 'DeliveryDestinations' then
            for locationId, locationData in pairs(locations) do
                if type(locationData) == 'table' and locationData.enabled and locationData.storage then
                    local locationKey = ('%s_%s'):format(restaurantType, locationId)

                    for storageKey, storageData in pairs(locationData.storage) do
                        local targetId = ('%s_storage_%s'):format(locationKey, storageKey)

                        exports.ox_target:addBoxZone({
                            name = targetId,
                            coords = storageData.coords,
                            size = storageData.targetSize or vec3(1.5, 1.5, 2.0),
                            rotation = storageData.heading or 0,
                            debug = Config.Debug,
                            options = {
                                {
                                    name = 'open_storage_' .. storageKey,
                                    label = storageData.label or 'Storage',
                                    icon = 'fa-solid fa-box',
                                    groups = storageData.groups or { [locationData.job] = 0 },
                                    canInteract = function()
                                        return FreeRestaurants.Client.IsOnDuty()
                                    end,
                                    onSelect = function()
                                        openStorage(storageKey, storageData, locationKey)
                                    end,
                                },
                            },
                        })

                        storageTargets[targetId] = true
                        FreeRestaurants.Utils.Debug(('Created storage target: %s'):format(targetId))
                    end
                end
            end
        end
    end

    local count = 0
    for _ in pairs(storageTargets) do count = count + 1 end
    FreeRestaurants.Utils.Debug(('Initialized %d storage targets'):format(count))
end

-- ============================================================================
-- PERMISSION CHECKS
-- ============================================================================

--- Check if player can access management menu
---@return boolean canAccess
---@return string|nil reason Reason for denial if canAccess is false
local function canAccessManagement()
    local isOnDuty = FreeRestaurants.Client.IsOnDuty()
    local job = FreeRestaurants.Client.GetPlayerState('job')
    local grade = FreeRestaurants.Client.GetPlayerState('grade') or 0

    print(('[free-restaurants] canAccessManagement check: onDuty=%s, job=%s, grade=%s'):format(
        tostring(isOnDuty), tostring(job), tostring(grade)
    ))

    if not isOnDuty then
        print('[free-restaurants] Access denied: not on duty')
        return false, 'not_on_duty'
    end

    -- Direct permission check (bypasses hasPermission issue)
    local jobConfig = Config.Jobs[job]
    if not jobConfig then
        print('[free-restaurants] Access denied: job not in Config.Jobs')
        return false, 'invalid_job'
    end

    -- Find the grade data, with fallback to highest grade
    local gradeData = jobConfig.grades[grade]
    if not gradeData then
        local maxGrade = -1
        for g, _ in pairs(jobConfig.grades) do
            if type(g) == 'number' and g > maxGrade then
                maxGrade = g
            end
        end
        if maxGrade >= 0 then
            gradeData = jobConfig.grades[maxGrade]
            print(('[free-restaurants] Using fallback grade %d instead of %d'):format(maxGrade, grade))
        end
    end

    if not gradeData or not gradeData.permissions then
        print('[free-restaurants] Access denied: no grade permissions found')
        return false, 'no_permissions'
    end

    -- Check for all=true (owner access)
    if gradeData.permissions.all == true then
        print('[free-restaurants] Access granted: owner has all permissions')
        return true, nil
    end

    local hasFinances = gradeData.permissions.canAccessFinances == true
    local hasHire = gradeData.permissions.canHire == true
    local hasFire = gradeData.permissions.canFire == true

    print(('[free-restaurants] Permissions: finances=%s, hire=%s, fire=%s'):format(
        tostring(hasFinances), tostring(hasHire), tostring(hasFire)
    ))

    if hasFinances or hasHire or hasFire then
        return true, nil
    end

    return false, 'insufficient_rank'
end

-- ============================================================================
-- MANAGEMENT MENU
-- ============================================================================

--- Open main management menu
---@param locationKey string
---@param locationData table
openManagementMenu = function(locationKey, locationData)
    local canAccess, reason = canAccessManagement()
    if not canAccess then
        local messages = {
            not_on_duty = 'You must be on duty to access management.',
            invalid_job = 'You don\'t work at a restaurant.',
            no_permissions = 'Your position has no management permissions.',
            insufficient_rank = 'You need to be a Manager or Owner to access this.',
        }
        lib.notify({
            title = 'Access Denied',
            description = messages[reason] or 'You don\'t have permission to access management.',
            type = 'error',
        })
        return
    end
    
    local options = {}
    
    -- Header
    table.insert(options, {
        title = locationData.label .. ' Management',
        description = 'Business administration panel',
        icon = 'building',
        disabled = true,
    })
    
    -- Employee Management
    if hasPermission('canHire') or 
       hasPermission('canFire') then
        table.insert(options, {
            title = 'Employee Management',
            description = 'Hire, fire, and manage staff',
            icon = 'users',
            onSelect = function()
                openEmployeeMenu(locationKey, locationData)
            end,
        })
    end
    
    -- Finances
    if hasPermission('canAccessFinances') then
        table.insert(options, {
            title = 'Finances',
            description = 'View and manage business funds',
            icon = 'chart-line',
            onSelect = function()
                openFinancesMenu(locationKey, locationData)
            end,
        })
    end
    
    -- Stock Management
    if hasPermission('canOrderStock') then
        table.insert(options, {
            title = 'Stock Orders',
            description = 'Order supplies and ingredients',
            icon = 'boxes-stacked',
            onSelect = function()
                openStockMenu(locationKey, locationData)
            end,
        })
    end
    
    -- Menu Pricing
    if hasPermission('canEditMenu') then
        table.insert(options, {
            title = 'Menu Pricing',
            description = 'Adjust menu prices',
            icon = 'tags',
            onSelect = function()
                openPricingMenu(locationKey, locationData)
            end,
        })
    end
    
    -- Payroll
    if hasPermission('canSetWages') then
        table.insert(options, {
            title = 'Payroll Settings',
            description = 'Configure employee wages',
            icon = 'money-check-dollar',
            onSelect = function()
                openPayrollMenu(locationKey, locationData)
            end,
        })
    end
    
    -- Business Storage
    table.insert(options, {
        title = 'Business Storage',
        description = 'Access shared storage',
        icon = 'warehouse',
        onSelect = function()
            openBusinessStorage(locationKey, locationData)
        end,
    })
    
    lib.registerContext({
        id = 'management_menu',
        title = 'Management',
        options = options,
    })
    
    lib.showContext('management_menu')
end

-- ============================================================================
-- EMPLOYEE MANAGEMENT
-- ============================================================================

--- Open employee management menu
---@param locationKey string
---@param locationData table
openEmployeeMenu = function(locationKey, locationData)
    local options = {}
    
    -- Get employee list from server
    local employees = lib.callback.await('free-restaurants:server:getEmployees', false, locationData.job)
    
    if not employees or #employees == 0 then
        table.insert(options, {
            title = 'No Employees',
            description = 'Hire staff to get started',
            icon = 'user-slash',
            disabled = true,
        })
    else
        -- Group by grade
        local byGrade = {}
        for _, emp in ipairs(employees) do
            local grade = emp.grade or 0
            if not byGrade[grade] then
                byGrade[grade] = {}
            end
            table.insert(byGrade[grade], emp)
        end
        
        -- Display by grade (highest first)
        local grades = {}
        for grade in pairs(byGrade) do
            table.insert(grades, grade)
        end
        table.sort(grades, function(a, b) return a > b end)
        
        for _, grade in ipairs(grades) do
            local gradeData = Config.Jobs[locationData.job].grades[grade]
            local gradeName = gradeData and gradeData.label or ('Grade %d'):format(grade)
            
            table.insert(options, {
                title = ('--- %s ---'):format(gradeName),
                disabled = true,
            })
            
            for _, emp in ipairs(byGrade[grade]) do
                local isOnDuty = emp.onDuty and 'ðŸŸ¢' or 'ðŸ”´'
                
                table.insert(options, {
                    title = ('%s %s %s'):format(isOnDuty, emp.firstname, emp.lastname),
                    description = gradeName,
                    icon = 'user',
                    onSelect = function()
                        openEmployeeActions(emp, locationKey, locationData)
                    end,
                })
            end
        end
    end
    
    -- Hire option
    if hasPermission('canHire') then
        table.insert(options, {
            title = 'Hire New Employee',
            description = 'Hire a nearby player',
            icon = 'user-plus',
            onSelect = function()
                hireEmployee(locationKey, locationData)
            end,
        })
    end
    
    lib.registerContext({
        id = 'employee_menu',
        title = 'Employees',
        menu = 'management_menu',
        options = options,
    })
    
    lib.showContext('employee_menu')
end

--- Open actions for specific employee
---@param employee table
---@param locationKey string
---@param locationData table
openEmployeeActions = function(employee, locationKey, locationData)
    local options = {}
    local jobConfig = Config.Jobs[locationData.job]
    local maxGrade = 0
    for grade in pairs(jobConfig.grades) do
        if grade > maxGrade then maxGrade = grade end
    end
    
    -- Employee info
    table.insert(options, {
        title = ('%s %s'):format(employee.firstname, employee.lastname),
        description = ('CID: %s'):format(employee.citizenid),
        icon = 'id-card',
        disabled = true,
    })
    
    -- Promote
    if hasPermission('canHire') and employee.grade < maxGrade then
        table.insert(options, {
            title = 'Promote',
            description = 'Increase employee grade',
            icon = 'arrow-up',
            onSelect = function()
                promoteEmployee(employee, locationKey, locationData)
            end,
        })
    end
    
    -- Demote
    if hasPermission('canFire') and employee.grade > 0 then
        table.insert(options, {
            title = 'Demote',
            description = 'Decrease employee grade',
            icon = 'arrow-down',
            onSelect = function()
                demoteEmployee(employee, locationKey, locationData)
            end,
        })
    end
    
    -- Set specific grade
    if hasPermission('canHire') then
        table.insert(options, {
            title = 'Set Grade',
            description = 'Set specific grade level',
            icon = 'sliders',
            onSelect = function()
                setEmployeeGrade(employee, locationKey, locationData)
            end,
        })
    end
    
    -- Fire
    if hasPermission('canFire') then
        table.insert(options, {
            title = 'Fire Employee',
            description = 'Terminate employment',
            icon = 'user-minus',
            onSelect = function()
                fireEmployee(employee, locationKey, locationData)
            end,
        })
    end
    
    lib.registerContext({
        id = 'employee_actions',
        title = 'Employee Actions',
        menu = 'employee_menu',
        options = options,
    })
    
    lib.showContext('employee_actions')
end

--- Hire a new employee
---@param locationKey string
---@param locationData table
hireEmployee = function(locationKey, locationData)
    -- Get nearby players
    local nearbyPlayers = lib.callback.await('free-restaurants:server:getNearbyPlayers', false, 10.0)
    
    if not nearbyPlayers or #nearbyPlayers == 0 then
        lib.notify({
            title = 'No Players Nearby',
            description = 'There are no players nearby to hire.',
            type = 'error',
        })
        return
    end
    
    local options = {}
    
    for _, player in ipairs(nearbyPlayers) do
        table.insert(options, {
            title = player.name,
            description = ('Server ID: %d'):format(player.id),
            icon = 'user',
            onSelect = function()
                -- Select starting grade
                local jobConfig = Config.Jobs[locationData.job]
                local gradeOptions = {}
                
                for grade, gradeData in pairs(jobConfig.grades) do
                    table.insert(gradeOptions, {
                        value = grade,
                        label = gradeData.label,
                    })
                end
                
                table.sort(gradeOptions, function(a, b) return a.value < b.value end)
                
                local input = lib.inputDialog('Hire ' .. player.name, {
                    {
                        type = 'select',
                        label = 'Starting Position',
                        options = gradeOptions,
                        default = 0,
                    },
                })
                
                if input then
                    local success = lib.callback.await(
                        'free-restaurants:server:hireEmployee',
                        false,
                        player.id,
                        locationData.job,
                        input[1]
                    )
                    
                    if success then
                        lib.notify({
                            title = 'Employee Hired',
                            description = ('%s has been hired!'):format(player.name),
                            type = 'success',
                        })
                    else
                        lib.notify({
                            title = 'Hire Failed',
                            description = 'Could not hire this player.',
                            type = 'error',
                        })
                    end
                end
                
                openEmployeeMenu(locationKey, locationData)
            end,
        })
    end
    
    lib.registerContext({
        id = 'hire_menu',
        title = 'Hire Employee',
        menu = 'employee_menu',
        options = options,
    })
    
    lib.showContext('hire_menu')
end

--- Promote employee
promoteEmployee = function(employee, locationKey, locationData)
    local newGrade = employee.grade + 1
    local success = lib.callback.await(
        'free-restaurants:server:setEmployeeGrade',
        false,
        employee.citizenid,
        locationData.job,
        newGrade
    )
    
    if success then
        lib.notify({
            title = 'Employee Promoted',
            description = ('%s has been promoted!'):format(employee.firstname),
            type = 'success',
        })
    else
        lib.notify({
            title = 'Promotion Failed',
            type = 'error',
        })
    end
    
    openEmployeeMenu(locationKey, locationData)
end

--- Demote employee
demoteEmployee = function(employee, locationKey, locationData)
    local newGrade = math.max(0, employee.grade - 1)
    local success = lib.callback.await(
        'free-restaurants:server:setEmployeeGrade',
        false,
        employee.citizenid,
        locationData.job,
        newGrade
    )
    
    if success then
        lib.notify({
            title = 'Employee Demoted',
            description = ('%s has been demoted.'):format(employee.firstname),
            type = 'inform',
        })
    else
        lib.notify({
            title = 'Demotion Failed',
            type = 'error',
        })
    end
    
    openEmployeeMenu(locationKey, locationData)
end

--- Set specific grade
setEmployeeGrade = function(employee, locationKey, locationData)
    local jobConfig = Config.Jobs[locationData.job]
    local gradeOptions = {}
    
    for grade, gradeData in pairs(jobConfig.grades) do
        table.insert(gradeOptions, {
            value = grade,
            label = gradeData.label,
        })
    end
    
    table.sort(gradeOptions, function(a, b) return a.value < b.value end)
    
    local input = lib.inputDialog('Set Grade', {
        {
            type = 'select',
            label = 'Position',
            options = gradeOptions,
            default = employee.grade,
        },
    })
    
    if input then
        local success = lib.callback.await(
            'free-restaurants:server:setEmployeeGrade',
            false,
            employee.citizenid,
            locationData.job,
            input[1]
        )
        
        if success then
            lib.notify({
                title = 'Grade Updated',
                type = 'success',
            })
        else
            lib.notify({
                title = 'Update Failed',
                type = 'error',
            })
        end
    end
    
    openEmployeeMenu(locationKey, locationData)
end

--- Fire employee
fireEmployee = function(employee, locationKey, locationData)
    local confirm = lib.alertDialog({
        header = 'Fire Employee',
        content = ('Are you sure you want to fire %s %s?'):format(employee.firstname, employee.lastname),
        centered = true,
        cancel = true,
    })
    
    if confirm ~= 'confirm' then return end
    
    local success = lib.callback.await(
        'free-restaurants:server:fireEmployee',
        false,
        employee.citizenid,
        locationData.job
    )
    
    if success then
        lib.notify({
            title = 'Employee Fired',
            description = ('%s has been terminated.'):format(employee.firstname),
            type = 'success',
        })
    else
        lib.notify({
            title = 'Fire Failed',
            type = 'error',
        })
    end
    
    openEmployeeMenu(locationKey, locationData)
end

-- ============================================================================
-- FINANCES
-- ============================================================================

--- Open finances menu
---@param locationKey string
---@param locationData table
openFinancesMenu = function(locationKey, locationData)
    -- Get financial data from server
    local finances = lib.callback.await('free-restaurants:server:getFinances', false, locationData.job)
    
    local options = {}
    
    if finances then
        table.insert(options, {
            title = ('Balance: %s'):format(FreeRestaurants.Utils.FormatMoney(finances.balance)),
            icon = 'wallet',
            disabled = true,
        })
        
        table.insert(options, {
            title = ('Today\'s Sales: %s'):format(FreeRestaurants.Utils.FormatMoney(finances.todaySales)),
            icon = 'cash-register',
            disabled = true,
        })
        
        table.insert(options, {
            title = ('This Week: %s'):format(FreeRestaurants.Utils.FormatMoney(finances.weekSales)),
            icon = 'chart-simple',
            disabled = true,
        })
    end
    
    table.insert(options, {
        title = 'Withdraw Funds',
        description = 'Transfer to personal account',
        icon = 'money-bill-transfer',
        onSelect = function()
            withdrawFunds(locationKey, locationData, finances)
        end,
    })
    
    table.insert(options, {
        title = 'Deposit Funds',
        description = 'Add money to business',
        icon = 'money-bill-trend-up',
        onSelect = function()
            depositFunds(locationKey, locationData)
        end,
    })
    
    table.insert(options, {
        title = 'Transaction History',
        description = 'View recent transactions',
        icon = 'receipt',
        onSelect = function()
            viewTransactions(locationKey, locationData)
        end,
    })
    
    lib.registerContext({
        id = 'finances_menu',
        title = 'Finances',
        menu = 'management_menu',
        options = options,
    })
    
    lib.showContext('finances_menu')
end

--- Withdraw funds
withdrawFunds = function(locationKey, locationData, finances)
    local maxWithdraw = finances and finances.balance or 0
    
    local input = lib.inputDialog('Withdraw Funds', {
        {
            type = 'number',
            label = 'Amount',
            description = ('Max: %s'):format(FreeRestaurants.Utils.FormatMoney(maxWithdraw)),
            min = 1,
            max = maxWithdraw,
        },
    })
    
    if input and input[1] then
        local success = lib.callback.await(
            'free-restaurants:server:withdrawFunds',
            false,
            locationData.job,
            input[1]
        )
        
        if success then
            lib.notify({
                title = 'Withdrawal Complete',
                description = FreeRestaurants.Utils.FormatMoney(input[1]),
                type = 'success',
            })
        else
            lib.notify({
                title = 'Withdrawal Failed',
                type = 'error',
            })
        end
    end
    
    openFinancesMenu(locationKey, locationData)
end

--- Deposit funds
depositFunds = function(locationKey, locationData)
    local input = lib.inputDialog('Deposit Funds', {
        {
            type = 'number',
            label = 'Amount',
            min = 1,
        },
    })
    
    if input and input[1] then
        local success = lib.callback.await(
            'free-restaurants:server:depositFunds',
            false,
            locationData.job,
            input[1]
        )
        
        if success then
            lib.notify({
                title = 'Deposit Complete',
                description = FreeRestaurants.Utils.FormatMoney(input[1]),
                type = 'success',
            })
        else
            lib.notify({
                title = 'Deposit Failed',
                type = 'error',
            })
        end
    end
    
    openFinancesMenu(locationKey, locationData)
end

--- View transaction history
viewTransactions = function(locationKey, locationData)
    local transactions = lib.callback.await('free-restaurants:server:getTransactions', false, locationData.job)
    
    local options = {}
    
    if transactions and #transactions > 0 then
        for _, tx in ipairs(transactions) do
            local icon = tx.type == 'deposit' and 'arrow-up' or 'arrow-down'
            local color = tx.type == 'deposit' and '#22c55e' or '#ef4444'
            
            table.insert(options, {
                title = ('%s%s'):format(tx.type == 'deposit' and '+' or '-', 
                    FreeRestaurants.Utils.FormatMoney(tx.amount)),
                description = tx.description or tx.type,
                icon = icon,
                iconColor = color,
                metadata = {
                    { label = 'Date', value = tx.date },
                    { label = 'By', value = tx.by or 'System' },
                },
            })
        end
    else
        table.insert(options, {
            title = 'No Transactions',
            disabled = true,
        })
    end
    
    lib.registerContext({
        id = 'transactions_menu',
        title = 'Transaction History',
        menu = 'finances_menu',
        options = options,
    })
    
    lib.showContext('transactions_menu')
end

-- ============================================================================
-- STOCK MANAGEMENT
-- ============================================================================

--- Open stock ordering menu
---@param locationKey string
---@param locationData table
openStockMenu = function(locationKey, locationData)
    -- Get available stock items
    local stockItems = lib.callback.await('free-restaurants:server:getStockItems', false, locationData.job)
    
    local options = {}
    
    if stockItems and #stockItems > 0 then
        for _, item in ipairs(stockItems) do
            table.insert(options, {
                title = item.label,
                description = ('%s each'):format(FreeRestaurants.Utils.FormatMoney(item.price)),
                icon = 'box',
                onSelect = function()
                    orderStock(item, locationKey, locationData)
                end,
            })
        end
    else
        table.insert(options, {
            title = 'No Items Available',
            disabled = true,
        })
    end
    
    lib.registerContext({
        id = 'stock_menu',
        title = 'Order Stock',
        menu = 'management_menu',
        options = options,
    })
    
    lib.showContext('stock_menu')
end

--- Order specific stock item
orderStock = function(item, locationKey, locationData)
    local input = lib.inputDialog('Order ' .. item.label, {
        {
            type = 'number',
            label = 'Quantity',
            default = 10,
            min = 1,
            max = 100,
        },
    })
    
    if input and input[1] then
        local total = item.price * input[1]
        
        local confirm = lib.alertDialog({
            header = 'Confirm Order',
            content = ('Order %dx %s for %s?'):format(input[1], item.label, 
                FreeRestaurants.Utils.FormatMoney(total)),
            centered = true,
            cancel = true,
        })
        
        if confirm == 'confirm' then
            local success = lib.callback.await(
                'free-restaurants:server:orderStock',
                false,
                locationData.job,
                item.name,
                input[1]
            )
            
            if success then
                lib.notify({
                    title = 'Order Placed',
                    description = ('Ordered %dx %s'):format(input[1], item.label),
                    type = 'success',
                })
            else
                lib.notify({
                    title = 'Order Failed',
                    type = 'error',
                })
            end
        end
    end
    
    openStockMenu(locationKey, locationData)
end

-- ============================================================================
-- MENU PRICING
-- ============================================================================

--- Open pricing menu
---@param locationKey string
---@param locationData table
openPricingMenu = function(locationKey, locationData)
    -- Get current pricing
    local pricing = lib.callback.await('free-restaurants:server:getPricing', false, locationData.job)
    
    local options = {}
    
    if pricing then
        for itemId, data in pairs(pricing) do
            local recipe = Config.Recipes[itemId]
            if recipe then
                table.insert(options, {
                    title = recipe.label,
                    description = ('Current: %s (Base: %s)'):format(
                        FreeRestaurants.Utils.FormatMoney(data.price),
                        FreeRestaurants.Utils.FormatMoney(recipe.price)
                    ),
                    icon = 'tag',
                    onSelect = function()
                        setItemPrice(itemId, recipe, data, locationKey, locationData)
                    end,
                })
            end
        end
    end
    
    lib.registerContext({
        id = 'pricing_menu',
        title = 'Menu Pricing',
        menu = 'management_menu',
        options = options,
    })
    
    lib.showContext('pricing_menu')
end

--- Set price for item
setItemPrice = function(itemId, recipe, currentData, locationKey, locationData)
    local basePrice = recipe.price
    local priceFloor = Config.Economy and Config.Economy.Pricing and Config.Economy.Pricing.priceFloor or 0.5
    local priceCeiling = Config.Economy and Config.Economy.Pricing and Config.Economy.Pricing.priceCeiling or 2.0
    local minPrice = math.floor(basePrice * priceFloor)
    local maxPrice = math.floor(basePrice * priceCeiling)
    
    local input = lib.inputDialog('Set Price: ' .. recipe.label, {
        {
            type = 'number',
            label = 'New Price',
            description = ('Range: %s - %s'):format(
                FreeRestaurants.Utils.FormatMoney(minPrice),
                FreeRestaurants.Utils.FormatMoney(maxPrice)
            ),
            default = currentData.price,
            min = minPrice,
            max = maxPrice,
        },
    })
    
    if input and input[1] then
        local success = lib.callback.await(
            'free-restaurants:server:setPrice',
            false,
            locationData.job,
            itemId,
            input[1]
        )
        
        if success then
            lib.notify({
                title = 'Price Updated',
                type = 'success',
            })
        else
            lib.notify({
                title = 'Update Failed',
                type = 'error',
            })
        end
    end
    
    openPricingMenu(locationKey, locationData)
end

-- ============================================================================
-- PAYROLL
-- ============================================================================

--- Open payroll menu
---@param locationKey string
---@param locationData table
openPayrollMenu = function(locationKey, locationData)
    local jobConfig = Config.Jobs[locationData.job]
    local options = {}
    
    for grade, gradeData in pairs(jobConfig.grades) do
        table.insert(options, {
            title = gradeData.label,
            description = ('Current Wage: %s'):format(FreeRestaurants.Utils.FormatMoney(gradeData.payment)),
            icon = 'money-bill',
            onSelect = function()
                setWage(grade, gradeData, locationKey, locationData)
            end,
        })
    end
    
    lib.registerContext({
        id = 'payroll_menu',
        title = 'Payroll Settings',
        menu = 'management_menu',
        options = options,
    })
    
    lib.showContext('payroll_menu')
end

--- Set wage for grade
setWage = function(grade, gradeData, locationKey, locationData)
    local input = lib.inputDialog('Set Wage: ' .. gradeData.label, {
        {
            type = 'number',
            label = 'Wage per paycheck',
            default = gradeData.payment,
            min = 0,
        },
    })
    
    if input and input[1] then
        local success = lib.callback.await(
            'free-restaurants:server:setWage',
            false,
            locationData.job,
            grade,
            input[1]
        )
        
        if success then
            lib.notify({
                title = 'Wage Updated',
                type = 'success',
            })
        else
            lib.notify({
                title = 'Update Failed',
                type = 'error',
            })
        end
    end
    
    openPayrollMenu(locationKey, locationData)
end

-- ============================================================================
-- BUSINESS STORAGE
-- ============================================================================

--- Open business storage
---@param locationKey string
---@param locationData table
openBusinessStorage = function(locationKey, locationData)
    local stashId = ('restaurant_business_%s'):format(locationKey)
    exports.ox_inventory:openInventory('stash', stashId)
end

-- ============================================================================
-- TARGET SETUP
-- ============================================================================

--- Setup management targets
local function setupManagementTargets()
    for restaurantType, locations in pairs(Config.Locations) do
        if type(locations) == 'table' and restaurantType ~= 'Settings' then
            for locationId, locationData in pairs(locations) do
                if type(locationData) == 'table' and locationData.enabled then
                    local key = ('%s_%s'):format(restaurantType, locationId)
                    
                    -- Boss office/management point
                    if locationData.management then
                        local mgmtPoint = locationData.management
                        
                        exports.ox_target:addBoxZone({
                            name = ('%s_management'):format(key),
                            coords = mgmtPoint.coords,
                            size = mgmtPoint.targetSize or vec3(1.5, 1.5, 2),
                            rotation = mgmtPoint.heading or 0,
                            debug = Config.Debug,
                            options = {
                                {
                                    name = 'open_management',
                                    label = 'Management',
                                    icon = 'fa-solid fa-briefcase',
                                    groups = { [locationData.job] = 3 }, -- Grade 3+ (Manager/Owner)
                                    canInteract = function()
                                        return FreeRestaurants.Client.IsOnDuty() and canAccessManagement()
                                    end,
                                    onSelect = function()
                                        openManagementMenu(key, locationData)
                                    end,
                                },
                            },
                        })
                        
                        managementTargets[('%s_management'):format(key)] = true
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

-- Initialize on ready
RegisterNetEvent('free-restaurants:client:ready', function()
    setupManagementTargets()
    setupStorageTargets()
end)

-- Command fallback
RegisterCommand('management', function()
    local locationKey, locationData = FreeRestaurants.Client.GetCurrentLocation()
    if locationKey and locationData then
        openManagementMenu(locationKey, locationData)
    else
        lib.notify({
            title = 'Not in Restaurant',
            description = 'You must be in a restaurant to access management.',
            type = 'error',
        })
    end
end, false)

-- Clean up on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    -- Remove management targets
    for targetId in pairs(managementTargets) do
        exports.ox_target:removeZone(targetId)
    end
    managementTargets = {}

    -- Remove storage targets
    for targetId in pairs(storageTargets) do
        exports.ox_target:removeZone(targetId)
    end
    storageTargets = {}
end)

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('OpenManagementMenu', openManagementMenu)
exports('CanAccessManagement', canAccessManagement)
exports('OpenStorage', openStorage)

FreeRestaurants.Utils.Debug('client/management.lua loaded')
