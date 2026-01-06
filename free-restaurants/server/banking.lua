--[[
    free-restaurants Server Banking Integration

    Provides banking integration layer supporting:
    - Internal restaurant business accounts (default)
    - rx_banking integration
    - Exports for external banking systems

    DEPENDENCIES:
    - server/main.lua (for internal business data)
    - rx_banking (optional, for external integration)
]]

-- ============================================================================
-- LOCAL STATE
-- ============================================================================

local bankingSystem = nil -- Will be set during initialization
local initialized = false

-- ============================================================================
-- BANKING SYSTEM DETECTION
-- ============================================================================

--- Detect available banking system
---@return string systemName
local function detectBankingSystem()
    local configSystem = Config.Integration and Config.Integration.Banking and Config.Integration.Banking.system or 'internal'

    if configSystem ~= 'auto' then
        return configSystem
    end

    -- Auto-detect: Check for rx_banking first (preferred)
    if GetResourceState('rx_banking') == 'started' then
        return 'rx_banking'
    end

    -- Fallback to internal system
    return 'internal'
end

-- ============================================================================
-- INTERNAL BANKING FUNCTIONS
-- ============================================================================

--- Get business account using internal system
---@param job string
---@return table|nil accountData
local function getInternalAccount(job)
    local businessData = exports['free-restaurants']:GetBusinessData(job)
    if not businessData then
        return nil
    end

    return {
        id = job,
        name = job,
        balance = businessData.balance or 0,
        type = 'business',
    }
end

--- Add money to internal business account
---@param job string
---@param amount number
---@param reason string|nil
---@param citizenid string|nil
---@return boolean success
local function addInternalMoney(job, amount, reason, citizenid)
    return exports['free-restaurants']:UpdateBusinessBalance(
        job,
        amount,
        'deposit',
        reason or 'Banking deposit',
        citizenid
    )
end

--- Remove money from internal business account
---@param job string
---@param amount number
---@param reason string|nil
---@param citizenid string|nil
---@return boolean success
local function removeInternalMoney(job, amount, reason, citizenid)
    local balance = exports['free-restaurants']:GetBusinessBalance(job)
    if balance < amount then
        return false
    end

    return exports['free-restaurants']:UpdateBusinessBalance(
        job,
        -amount,
        'withdrawal',
        reason or 'Banking withdrawal',
        citizenid
    )
end

-- ============================================================================
-- RX_BANKING INTEGRATION
-- ============================================================================

--- Get business account using rx_banking
---@param job string
---@return table|nil accountData
local function getRxBankingAccount(job)
    local accountName = ('restaurant_%s'):format(job)

    -- Try to get existing account
    local success, account = pcall(function()
        return exports['rx_banking']:getAccountByName(accountName)
    end)

    if success and account then
        return {
            id = account.id or accountName,
            name = accountName,
            balance = account.balance or 0,
            type = 'business',
        }
    end

    -- Account doesn't exist, return nil (will be created on first use)
    return nil
end

--- Ensure rx_banking account exists for job
---@param job string
---@return boolean success
local function ensureRxBankingAccount(job)
    local accountName = ('restaurant_%s'):format(job)

    -- Check if account exists
    local success, account = pcall(function()
        return exports['rx_banking']:getAccountByName(accountName)
    end)

    if success and account then
        return true
    end

    -- Create new account
    local jobConfig = Config.Jobs and Config.Jobs[job]
    local label = jobConfig and jobConfig.label or job

    local createSuccess = pcall(function()
        exports['rx_banking']:createAccount({
            name = accountName,
            label = ('%s Business'):format(label),
            type = 'business',
            balance = 0,
            owner = job,
        })
    end)

    return createSuccess
end

--- Add money using rx_banking
---@param job string
---@param amount number
---@param reason string|nil
---@return boolean success
local function addRxBankingMoney(job, amount, reason)
    local accountName = ('restaurant_%s'):format(job)

    ensureRxBankingAccount(job)

    local success = pcall(function()
        exports['rx_banking']:addAccountMoney(accountName, amount, reason or 'Restaurant deposit')
    end)

    return success
end

--- Remove money using rx_banking
---@param job string
---@param amount number
---@param reason string|nil
---@return boolean success
local function removeRxBankingMoney(job, amount, reason)
    local accountName = ('restaurant_%s'):format(job)

    -- Check balance first
    local account = getRxBankingAccount(job)
    if not account or account.balance < amount then
        return false
    end

    local success = pcall(function()
        exports['rx_banking']:removeAccountMoney(accountName, amount, reason or 'Restaurant withdrawal')
    end)

    return success
end

-- ============================================================================
-- UNIFIED BANKING INTERFACE
-- ============================================================================

local BankingInterface = {}

--- Get business account
---@param job string
---@return table|nil accountData
function BankingInterface.GetAccount(job)
    if not job then
        print('[free-restaurants] Banking error: job is required')
        return nil
    end

    if bankingSystem == 'rx_banking' then
        return getRxBankingAccount(job)
    end

    -- Default to internal
    return getInternalAccount(job)
end

--- Get business balance
---@param job string
---@return number balance
function BankingInterface.GetBalance(job)
    if not job then
        return 0
    end

    local account = BankingInterface.GetAccount(job)
    return account and account.balance or 0
end

--- Add money to business account
---@param job string
---@param amount number
---@param reason string|nil
---@param citizenid string|nil
---@return boolean success
function BankingInterface.AddMoney(job, amount, reason, citizenid)
    if not job or not amount or amount <= 0 then
        print('[free-restaurants] Banking error: invalid parameters for AddMoney')
        return false
    end

    if bankingSystem == 'rx_banking' then
        return addRxBankingMoney(job, amount, reason)
    end

    return addInternalMoney(job, amount, reason, citizenid)
end

--- Remove money from business account
---@param job string
---@param amount number
---@param reason string|nil
---@param citizenid string|nil
---@return boolean success
function BankingInterface.RemoveMoney(job, amount, reason, citizenid)
    if not job or not amount or amount <= 0 then
        print('[free-restaurants] Banking error: invalid parameters for RemoveMoney')
        return false
    end

    if bankingSystem == 'rx_banking' then
        return removeRxBankingMoney(job, amount, reason)
    end

    return removeInternalMoney(job, amount, reason, citizenid)
end

--- Transfer money between accounts
---@param fromJob string
---@param toJob string
---@param amount number
---@param reason string|nil
---@return boolean success
function BankingInterface.Transfer(fromJob, toJob, amount, reason)
    if not fromJob or not toJob or not amount or amount <= 0 then
        return false
    end

    -- Check source balance
    local balance = BankingInterface.GetBalance(fromJob)
    if balance < amount then
        return false
    end

    -- Remove from source
    local removeSuccess = BankingInterface.RemoveMoney(fromJob, amount, reason or ('Transfer to %s'):format(toJob))
    if not removeSuccess then
        return false
    end

    -- Add to destination
    local addSuccess = BankingInterface.AddMoney(toJob, amount, reason or ('Transfer from %s'):format(fromJob))
    if not addSuccess then
        -- Rollback
        BankingInterface.AddMoney(fromJob, amount, 'Transfer rollback')
        return false
    end

    return true
end

--- Get current banking system name
---@return string systemName
function BankingInterface.GetSystem()
    return bankingSystem or 'internal'
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

--- Initialize banking system
local function initializeBanking()
    if initialized then return end

    -- Detect banking system
    bankingSystem = detectBankingSystem()

    print(('[free-restaurants] Banking system initialized: %s'):format(bankingSystem))

    -- If using rx_banking, ensure accounts exist for all configured jobs
    if bankingSystem == 'rx_banking' then
        SetTimeout(2000, function()
            for jobName, _ in pairs(Config.Jobs or {}) do
                ensureRxBankingAccount(jobName)
            end
            print('[free-restaurants] rx_banking accounts initialized')
        end)
    end

    initialized = true
end

-- ============================================================================
-- EXPORTS FOR RX_BANKING COMPATIBILITY
-- ============================================================================

-- These exports allow rx_banking or other systems to interact with restaurant accounts

--- Get restaurant business account (rx_banking compatible export)
---@param job string Job/restaurant name
---@return table|nil account
exports('GetBusinessAccount', function(job)
    return BankingInterface.GetAccount(job)
end)

--- Get restaurant business balance (rx_banking compatible export)
---@param job string Job/restaurant name
---@return number balance
exports('GetBusinessAccountBalance', function(job)
    return BankingInterface.GetBalance(job)
end)

--- Add money to restaurant business (rx_banking compatible export)
---@param job string Job/restaurant name
---@param amount number Amount to add
---@param reason string|nil Transaction reason
---@return boolean success
exports('AddBusinessMoney', function(job, amount, reason)
    return BankingInterface.AddMoney(job, amount, reason)
end)

--- Remove money from restaurant business (rx_banking compatible export)
---@param job string Job/restaurant name
---@param amount number Amount to remove
---@param reason string|nil Transaction reason
---@return boolean success
exports('RemoveBusinessMoney', function(job, amount, reason)
    return BankingInterface.RemoveMoney(job, amount, reason)
end)

--- Get banking system in use
---@return string systemName
exports('GetBankingSystem', function()
    return BankingInterface.GetSystem()
end)

-- ============================================================================
-- CALLBACKS FOR CLIENT
-- ============================================================================

--- Get account info for UI
lib.callback.register('free-restaurants:server:getBankingAccount', function(source, job)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return nil end

    -- Verify player has access to this job's finances
    if player.PlayerData.job.name ~= job then return nil end

    return BankingInterface.GetAccount(job)
end)

--- Process banking transaction
lib.callback.register('free-restaurants:server:bankingTransaction', function(source, job, action, amount, reason)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end

    -- Verify permissions
    if player.PlayerData.job.name ~= job then return false end

    local gradeLevel = player.PlayerData.job.grade.level
    local jobConfig = Config.Jobs and Config.Jobs[job]
    if not jobConfig then return false end

    local gradePerms = jobConfig.grades[gradeLevel] and jobConfig.grades[gradeLevel].permissions
    if not gradePerms or not (gradePerms.canAccessFinances or gradePerms.all) then
        return false
    end

    local citizenid = player.PlayerData.citizenid
    local playerName = ('%s %s'):format(
        player.PlayerData.charinfo.firstname,
        player.PlayerData.charinfo.lastname
    )

    if action == 'deposit' then
        -- Check player has cash
        if player.PlayerData.money.cash < amount then
            return false
        end

        player.Functions.RemoveMoney('cash', amount, 'restaurant-deposit')
        return BankingInterface.AddMoney(job, amount, ('Deposit by %s'):format(playerName), citizenid)

    elseif action == 'withdraw' then
        local success = BankingInterface.RemoveMoney(job, amount, ('Withdrawal by %s'):format(playerName), citizenid)
        if success then
            player.Functions.AddMoney('cash', amount, 'restaurant-withdrawal')
        end
        return success
    end

    return false
end)

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    -- Wait for main.lua to initialize first
    SetTimeout(1500, function()
        initializeBanking()
    end)
end)

-- ============================================================================
-- GLOBAL ACCESS
-- ============================================================================

FreeRestaurants = FreeRestaurants or {}
FreeRestaurants.Banking = BankingInterface

print('[free-restaurants] server/banking.lua loaded')
