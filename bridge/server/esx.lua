local Bridge = {}
local ESX = nil

function Bridge.Init()
    ESX = exports["es_extended"]:getSharedObject()
    if not ESX then
        print('[Bridge] Failed to get ESX shared object')
        return false
    end
    return true
end

function Bridge.GetPlayer(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return nil
    end
    return {
        source = source,
        identifier = xPlayer.identifier,
        name = xPlayer.getName(),
        job = Bridge.ConvertJobData(xPlayer.job),
        getMoney = function()
            return xPlayer.getMoney()
        end,
        addMoney = function(amount)
            return xPlayer.addMoney(amount)
        end,
        removeMoney = function(amount)
            return xPlayer.removeMoney(amount)
        end,
        getAccount = function(accountName)
            local account = xPlayer.getAccount(accountName)
            return account and account.money or 0
        end,
        addAccountMoney = function(accountName, amount)
            return xPlayer.addAccountMoney(accountName, amount)
        end,
        removeAccountMoney = function(accountName, amount)
            return xPlayer.removeAccountMoney(accountName, amount)
        end,
    }
end

function Bridge.GetPlayers()
    local players = {}
    local xPlayers = ESX.GetPlayers()
    for _, playerId in ipairs(xPlayers) do
        local player = Bridge.GetPlayer(playerId)
        if player then
            table.insert(players, player)
        end
    end
    return players
end

function Bridge.ConvertJobData(data)
    if not data then return nil end
    return {
        name = data.name,
        label = data.label,
        grade = data.grade,
        grade_name = data.grade_name,
        grade_label = data.grade_label,
    }
end

return Bridge