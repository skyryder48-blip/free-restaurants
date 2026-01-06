--[[
    free-restaurants Job Configuration
    
    This file defines all restaurant jobs, their grades, permissions, and uniforms.
    Each restaurant location has its own job with configurable roles.
    
    INTEGRATION: Uses illenium-appearance for uniform management
    
    Grade Structure (default):
        0 = Trainee      - Basic duties, learning the ropes
        1 = Cook         - Full cooking access
        2 = Chef         - Cooking + order management
        3 = Manager      - Staff management + finances
        4 = Owner        - Full business control
]]

Config = Config or {}
Config.Jobs = Config.Jobs or {}

-- ============================================================================
-- JOB DEFINITIONS
-- Each restaurant location gets its own job entry
-- ============================================================================

Config.Jobs = {
    --[[
        BURGER SHOT
        Fast food restaurant - simpler menu, faster service
    ]]
    ['burgershot'] = {
        label = 'Burger Shot',
        type = 'fastfood',                  -- Restaurant type for recipe filtering
        defaultDuty = false,
        offDutyPay = false,
        
        -- Grade Configuration
        grades = {
            [0] = {
                name = 'trainee',
                label = 'Trainee',
                payment = 50,
                permissions = {
                    canCook = true,
                    canServe = true,
                    canClean = true,
                    canAccessStorage = false,
                    canManageOrders = false,
                    canHire = false,
                    canFire = false,
                    canSetWages = false,
                    canAccessFinances = false,
                    canEditMenu = false,
                    canOrderStock = false,
                },
            },
            [1] = {
                name = 'cook',
                label = 'Cook',
                payment = 75,
                permissions = {
                    canCook = true,
                    canServe = true,
                    canClean = true,
                    canAccessStorage = true,
                    canManageOrders = false,
                    canHire = false,
                    canFire = false,
                    canSetWages = false,
                    canAccessFinances = false,
                    canEditMenu = false,
                    canOrderStock = false,
                },
            },
            [2] = {
                name = 'chef',
                label = 'Head Cook',
                payment = 100,
                permissions = {
                    canCook = true,
                    canServe = true,
                    canClean = true,
                    canAccessStorage = true,
                    canManageOrders = true,
                    canHire = false,
                    canFire = false,
                    canSetWages = false,
                    canAccessFinances = false,
                    canEditMenu = false,
                    canOrderStock = true,
                },
            },
            [3] = {
                name = 'manager',
                label = 'Manager',
                payment = 150,
                isboss = true,
                permissions = {
                    canCook = true,
                    canServe = true,
                    canClean = true,
                    canAccessStorage = true,
                    canManageOrders = true,
                    canHire = true,
                    canFire = true,
                    canSetWages = true,
                    canAccessFinances = true,
                    canEditMenu = true,
                    canOrderStock = true,
                },
            },
            [4] = {
                name = 'owner',
                label = 'Owner',
                payment = 0,                -- Owners take from profits
                isboss = true,
                permissions = {
                    all = true,             -- Full access
                },
            },
        },
    },
    
    --[[
        PIZZA THIS
        Pizzeria - medium complexity, delivery focus
    ]]
    ['pizzathis'] = {
        label = 'Pizza This',
        type = 'pizzeria',
        defaultDuty = false,
        offDutyPay = false,
        
        grades = {
            [0] = {
                name = 'trainee',
                label = 'Trainee',
                payment = 50,
                permissions = {
                    canCook = true,
                    canServe = true,
                    canClean = true,
                    canAccessStorage = false,
                    canManageOrders = false,
                    canHire = false,
                    canFire = false,
                    canSetWages = false,
                    canAccessFinances = false,
                    canEditMenu = false,
                    canOrderStock = false,
                },
            },
            [1] = {
                name = 'cook',
                label = 'Pizza Maker',
                payment = 75,
                permissions = {
                    canCook = true,
                    canServe = true,
                    canClean = true,
                    canAccessStorage = true,
                    canManageOrders = false,
                    canHire = false,
                    canFire = false,
                    canSetWages = false,
                    canAccessFinances = false,
                    canEditMenu = false,
                    canOrderStock = false,
                },
            },
            [2] = {
                name = 'chef',
                label = 'Head Chef',
                payment = 100,
                permissions = {
                    canCook = true,
                    canServe = true,
                    canClean = true,
                    canAccessStorage = true,
                    canManageOrders = true,
                    canHire = false,
                    canFire = false,
                    canSetWages = false,
                    canAccessFinances = false,
                    canEditMenu = false,
                    canOrderStock = true,
                },
            },
            [3] = {
                name = 'manager',
                label = 'Manager',
                payment = 150,
                isboss = true,
                permissions = {
                    canCook = true,
                    canServe = true,
                    canClean = true,
                    canAccessStorage = true,
                    canManageOrders = true,
                    canHire = true,
                    canFire = true,
                    canSetWages = true,
                    canAccessFinances = true,
                    canEditMenu = true,
                    canOrderStock = true,
                },
            },
            [4] = {
                name = 'owner',
                label = 'Owner',
                payment = 0,
                isboss = true,
                permissions = {
                    all = true,
                },
            },
        },
    },
    
    --[[
        BEAN MACHINE
        Coffee shop - drinks focus, quick service
    ]]
    ['beanmachine'] = {
        label = 'Bean Machine',
        type = 'coffeeshop',
        defaultDuty = false,
        offDutyPay = false,
        
        -- Simplified grade structure for coffee shop
        grades = {
            [0] = {
                name = 'barista',
                label = 'Barista',
                payment = 60,
                permissions = {
                    canCook = true,
                    canServe = true,
                    canClean = true,
                    canAccessStorage = true,
                    canManageOrders = false,
                    canHire = false,
                    canFire = false,
                    canSetWages = false,
                    canAccessFinances = false,
                    canEditMenu = false,
                    canOrderStock = false,
                },
            },
            [1] = {
                name = 'senior_barista',
                label = 'Senior Barista',
                payment = 85,
                permissions = {
                    canCook = true,
                    canServe = true,
                    canClean = true,
                    canAccessStorage = true,
                    canManageOrders = true,
                    canHire = false,
                    canFire = false,
                    canSetWages = false,
                    canAccessFinances = false,
                    canEditMenu = false,
                    canOrderStock = true,
                },
            },
            [2] = {
                name = 'manager',
                label = 'Manager',
                payment = 120,
                isboss = true,
                permissions = {
                    canCook = true,
                    canServe = true,
                    canClean = true,
                    canAccessStorage = true,
                    canManageOrders = true,
                    canHire = true,
                    canFire = true,
                    canSetWages = true,
                    canAccessFinances = true,
                    canEditMenu = true,
                    canOrderStock = true,
                },
            },
            [3] = {
                name = 'owner',
                label = 'Owner',
                payment = 0,
                isboss = true,
                permissions = {
                    all = true,
                },
            },
        },
    },
    
    --[[
        TEQUI-LA-LA
        Bar/Restaurant - alcohol focus, evening hours
    ]]
    ['tequilala'] = {
        label = 'Tequi-la-la',
        type = 'bar',
        defaultDuty = false,
        offDutyPay = false,
        
        grades = {
            [0] = {
                name = 'barback',
                label = 'Barback',
                payment = 55,
                permissions = {
                    canCook = false,
                    canServe = true,
                    canClean = true,
                    canAccessStorage = false,
                    canManageOrders = false,
                    canHire = false,
                    canFire = false,
                    canSetWages = false,
                    canAccessFinances = false,
                    canEditMenu = false,
                    canOrderStock = false,
                },
            },
            [1] = {
                name = 'bartender',
                label = 'Bartender',
                payment = 80,
                permissions = {
                    canCook = true,          -- Mix drinks
                    canServe = true,
                    canClean = true,
                    canAccessStorage = true,
                    canManageOrders = false,
                    canHire = false,
                    canFire = false,
                    canSetWages = false,
                    canAccessFinances = false,
                    canEditMenu = false,
                    canOrderStock = false,
                },
            },
            [2] = {
                name = 'head_bartender',
                label = 'Head Bartender',
                payment = 110,
                permissions = {
                    canCook = true,
                    canServe = true,
                    canClean = true,
                    canAccessStorage = true,
                    canManageOrders = true,
                    canHire = false,
                    canFire = false,
                    canSetWages = false,
                    canAccessFinances = false,
                    canEditMenu = false,
                    canOrderStock = true,
                },
            },
            [3] = {
                name = 'manager',
                label = 'Manager',
                payment = 160,
                isboss = true,
                permissions = {
                    canCook = true,
                    canServe = true,
                    canClean = true,
                    canAccessStorage = true,
                    canManageOrders = true,
                    canHire = true,
                    canFire = true,
                    canSetWages = true,
                    canAccessFinances = true,
                    canEditMenu = true,
                    canOrderStock = true,
                },
            },
            [4] = {
                name = 'owner',
                label = 'Owner',
                payment = 0,
                isboss = true,
                permissions = {
                    all = true,
                },
            },
        },
    },
    
    --[[
        TEMPLATE: Use this as a base for adding new restaurants
        Copy and modify as needed
    ]]
    --[[
    ['restaurant_name'] = {
        label = 'Restaurant Display Name',
        type = 'restaurant_type',           -- For recipe/menu filtering
        defaultDuty = false,
        offDutyPay = false,
        
        grades = {
            [0] = {
                name = 'grade_name',
                label = 'Display Label',
                payment = 50,
                isboss = false,             -- Optional, defaults to false
                permissions = {
                    canCook = true,
                    canServe = true,
                    canClean = true,
                    canAccessStorage = false,
                    canManageOrders = false,
                    canHire = false,
                    canFire = false,
                    canSetWages = false,
                    canAccessFinances = false,
                    canEditMenu = false,
                    canOrderStock = false,
                },
            },
            -- Add more grades as needed
        },
    },
    ]]
}

-- ============================================================================
-- UNIFORM CONFIGURATION (illenium-appearance integration)
-- ============================================================================

Config.Uniforms = {
    enabled = true,
    
    -- Integration settings
    integration = {
        resource = 'illenium-appearance',
        
        -- Events to trigger
        events = {
            openWardrobe = 'illenium-appearance:client:openOutfitMenu',
            changeOutfit = 'illenium-appearance:client:changeOutfit',
            getOutfits = 'illenium-appearance:server:getManagementOutfits',
        },
        
        -- Exports to use
        exports = {
            setPedAppearance = 'setPedAppearance',
            getPedAppearance = 'getPedAppearance',
        },
    },
    
    -- Per-job uniform definitions
    -- These outfits can be managed via illenium-appearance's boss menu
    -- OR defined here as fallback/defaults
    jobs = {
        ['burgershot'] = {
            enabled = true,
            required = true,                -- Must wear uniform on duty
            
            -- Use illenium-appearance's built-in job outfit system
            useBuiltInSystem = true,
            
            -- Fallback outfits if not using built-in system
            -- These are component/drawable/texture definitions
            outfits = {
                male = {
                    -- Standard uniform components
                    components = {
                        [1] = { drawable = 0, texture = 0 },    -- Mask
                        [3] = { drawable = 0, texture = 0 },    -- Arms
                        [4] = { drawable = 35, texture = 0 },   -- Pants
                        [5] = { drawable = 0, texture = 0 },    -- Bag
                        [6] = { drawable = 25, texture = 0 },   -- Shoes
                        [7] = { drawable = 0, texture = 0 },    -- Accessory
                        [8] = { drawable = 15, texture = 0 },   -- Undershirt
                        [9] = { drawable = 0, texture = 0 },    -- Armor
                        [10] = { drawable = 0, texture = 0 },   -- Decals
                        [11] = { drawable = 230, texture = 0 }, -- Torso
                    },
                    props = {
                        [0] = { drawable = 46, texture = 0 },   -- Hat
                    },
                },
                female = {
                    components = {
                        [1] = { drawable = 0, texture = 0 },
                        [3] = { drawable = 0, texture = 0 },
                        [4] = { drawable = 34, texture = 0 },
                        [5] = { drawable = 0, texture = 0 },
                        [6] = { drawable = 27, texture = 0 },
                        [7] = { drawable = 0, texture = 0 },
                        [8] = { drawable = 14, texture = 0 },
                        [9] = { drawable = 0, texture = 0 },
                        [10] = { drawable = 0, texture = 0 },
                        [11] = { drawable = 232, texture = 0 },
                    },
                    props = {
                        [0] = { drawable = 45, texture = 0 },
                    },
                },
            },
            
            -- Grade-specific variations (optional)
            gradeVariations = {
                [3] = {                     -- Manager gets different color
                    male = {
                        components = {
                            [11] = { drawable = 230, texture = 1 },
                        },
                    },
                    female = {
                        components = {
                            [11] = { drawable = 232, texture = 1 },
                        },
                    },
                },
            },
        },
        
        ['pizzathis'] = {
            enabled = true,
            required = true,
            useBuiltInSystem = true,
            
            outfits = {
                male = {
                    components = {
                        [3] = { drawable = 0, texture = 0 },
                        [4] = { drawable = 24, texture = 0 },
                        [6] = { drawable = 12, texture = 0 },
                        [8] = { drawable = 15, texture = 0 },
                        [11] = { drawable = 146, texture = 0 },
                    },
                    props = {
                        [0] = { drawable = 121, texture = 0 },
                    },
                },
                female = {
                    components = {
                        [3] = { drawable = 0, texture = 0 },
                        [4] = { drawable = 25, texture = 0 },
                        [6] = { drawable = 12, texture = 0 },
                        [8] = { drawable = 6, texture = 0 },
                        [11] = { drawable = 150, texture = 0 },
                    },
                    props = {
                        [0] = { drawable = 120, texture = 0 },
                    },
                },
            },
        },
        
        ['beanmachine'] = {
            enabled = true,
            required = true,
            useBuiltInSystem = true,
            
            outfits = {
                male = {
                    components = {
                        [3] = { drawable = 4, texture = 0 },
                        [4] = { drawable = 24, texture = 0 },
                        [6] = { drawable = 10, texture = 0 },
                        [8] = { drawable = 31, texture = 0 },
                        [11] = { drawable = 43, texture = 0 },
                    },
                    props = {},
                },
                female = {
                    components = {
                        [3] = { drawable = 3, texture = 0 },
                        [4] = { drawable = 25, texture = 0 },
                        [6] = { drawable = 10, texture = 0 },
                        [8] = { drawable = 32, texture = 0 },
                        [11] = { drawable = 41, texture = 0 },
                    },
                    props = {},
                },
            },
        },
        
        ['tequilala'] = {
            enabled = true,
            required = true,
            useBuiltInSystem = true,
            
            outfits = {
                male = {
                    components = {
                        [3] = { drawable = 4, texture = 0 },
                        [4] = { drawable = 28, texture = 0 },
                        [6] = { drawable = 10, texture = 0 },
                        [7] = { drawable = 21, texture = 0 },    -- Vest/Tie
                        [8] = { drawable = 31, texture = 0 },
                        [11] = { drawable = 29, texture = 0 },
                    },
                    props = {},
                },
                female = {
                    components = {
                        [3] = { drawable = 3, texture = 0 },
                        [4] = { drawable = 30, texture = 0 },
                        [6] = { drawable = 29, texture = 0 },
                        [7] = { drawable = 3, texture = 0 },
                        [8] = { drawable = 35, texture = 0 },
                        [11] = { drawable = 31, texture = 0 },
                    },
                    props = {},
                },
            },
        },
    },
}

-- ============================================================================
-- DUTY SETTINGS
-- ============================================================================

Config.Duty = {
    -- Clock-in requirements
    clockIn = {
        requirePhysicalLocation = true,     -- Must be at clock-in point
        onlyEmployees = true,               -- Only non-boss grades use clock-in
        bossesAutoOnDuty = false,           -- Bosses must still clock in
    },
    
    -- Auto clock-out settings
    autoClockOut = {
        enabled = true,                     -- Auto clock-out when leaving
        
        -- Distance from restaurant boundary before triggering
        boundaryBuffer = 10.0,              -- Meters outside restaurant zone
        
        -- Grace period before auto clock-out
        gracePeriod = 30,                   -- Seconds to return before clock-out
        
        -- Warning notification
        warnBeforeClockOut = true,
        warningTime = 15,                   -- Seconds before clock-out to warn
        
        -- Exceptions
        exceptions = {
            duringDelivery = true,          -- Don't clock out during delivery
            duringCatering = true,          -- Don't clock out during catering
        },
    },
    
    -- Duty state tracking
    tracking = {
        saveSessionTime = true,             -- Track total time on duty
        trackTasks = true,                  -- Track completed tasks
        trackEarnings = true,               -- Track earnings per session
    },
}

-- ============================================================================
-- BOSS MENU SETTINGS
-- ============================================================================

Config.BossMenu = {
    enabled = true,
    
    -- Access requirements
    access = {
        minGrade = 3,                       -- Minimum grade to access (manager)
        requireOnDuty = false,              -- Must be on duty to access
        requireInRestaurant = true,         -- Must be in restaurant to access
    },
    
    -- Available actions per permission
    actions = {
        -- Employee Management
        viewEmployees = true,
        hireEmployee = true,
        fireEmployee = true,
        promoteEmployee = true,
        demoteEmployee = true,
        setWage = true,
        
        -- Financial Management
        viewBalance = true,
        viewTransactions = true,
        withdraw = true,
        deposit = true,
        
        -- Menu Management
        editMenu = true,
        setPrices = true,
        toggleItems = true,
        
        -- Stock Management
        viewStock = true,
        orderStock = true,
        
        -- Business Settings
        viewStatistics = true,
        manageUpgrades = true,
    },
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

--- Get job configuration by name
---@param jobName string The job name to look up
---@return table|nil Job configuration or nil if not found
function Config.GetJobConfig(jobName)
    return Config.Jobs[jobName]
end

--- Get all restaurant job names
---@return table Array of job names
function Config.GetAllJobNames()
    local jobs = {}
    for jobName, _ in pairs(Config.Jobs) do
        jobs[#jobs + 1] = jobName
    end
    return jobs
end

--- Check if a job is a restaurant job
---@param jobName string The job name to check
---@return boolean
function Config.IsRestaurantJob(jobName)
    return Config.Jobs[jobName] ~= nil
end

--- Get grade configuration for a job
---@param jobName string The job name
---@param gradeLevel number The grade level
---@return table|nil Grade configuration or nil
function Config.GetGradeConfig(jobName, gradeLevel)
    local job = Config.Jobs[jobName]
    if not job then return nil end
    return job.grades[gradeLevel]
end

--- Check if a grade has a specific permission
---@param jobName string The job name
---@param gradeLevel number The grade level
---@param permission string The permission to check
---@return boolean
function Config.HasPermission(jobName, gradeLevel, permission)
    local grade = Config.GetGradeConfig(jobName, gradeLevel)
    if not grade then return false end
    
    -- Owner/all permissions
    if grade.permissions.all then return true end
    
    return grade.permissions[permission] == true
end

--- Get uniform configuration for a job
---@param jobName string The job name
---@return table|nil Uniform configuration or nil
function Config.GetUniformConfig(jobName)
    if not Config.Uniforms.enabled then return nil end
    return Config.Uniforms.jobs[jobName]
end

--- Get the highest grade level for a job
---@param jobName string The job name
---@return number|nil Highest grade level or nil
function Config.GetMaxGrade(jobName)
    local job = Config.Jobs[jobName]
    if not job then return nil end
    
    local maxGrade = 0
    for grade, _ in pairs(job.grades) do
        if grade > maxGrade then
            maxGrade = grade
        end
    end
    return maxGrade
end

--- Get boss grade level for a job (first grade with isboss = true)
---@param jobName string The job name
---@return number|nil Boss grade level or nil
function Config.GetBossGrade(jobName)
    local job = Config.Jobs[jobName]
    if not job then return nil end
    
    for grade, data in pairs(job.grades) do
        if data.isboss then
            return grade
        end
    end
    return nil
end

return Config
