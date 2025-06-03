local Bridge = {}
local QBCore = nil

function Bridge.Init()
    QBCore = exports['qb-core']:GetCoreObject()
    if not QBCore then
        print('[Bridge] Failed to get QB-Core object')
        return false
    end
    return true
end

function Bridge.GetPlayer(source)
    local qbPlayer = QBCore.Functions.GetPlayer(source)
    if not qbPlayer then
        return nil
    end
    return {
        source = source,
        identifier = qbPlayer.PlayerData.citizenid,
        name = qbPlayer.PlayerData.charinfo.firstname .. ' ' .. qbPlayer.PlayerData.charinfo.lastname,
        job = Bridge.ConvertJobData(qbPlayer.PlayerData.job),
        getMoney = function()
            return qbPlayer.Functions.GetMoney('cash')
        end,
        addMoney = function(amount)
            return qbPlayer.Functions.AddMoney('cash', amount, 'bridge-transfer')
        end,
        removeMoney = function(amount)
            return qbPlayer.Functions.RemoveMoney('cash', amount, 'bridge-transfer')
        end,
        getAccount = function(accountName)
            if accountName == 'bank' then
                return qbPlayer.Functions.GetMoney('bank')
            elseif accountName == 'money' or accountName == 'cash' then
                return qbPlayer.Functions.GetMoney('cash')
            else
                return qbPlayer.Functions.GetMoney(accountName) or 0
            end
        end,
        addAccountMoney = function(accountName, amount)
            local accountMap = {
                money = 'cash',
                bank = 'bank',
                crypto = 'crypto'
            }
            local mappedAccount = accountMap[accountName] or accountName
            return qbPlayer.Functions.AddMoney(mappedAccount, amount, 'bridge-transfer')
        end,
        removeAccountMoney = function(accountName, amount)
            local accountMap = {
                money = 'cash',
                bank = 'bank',
                crypto = 'crypto'
            }
            local mappedAccount = accountMap[accountName] or accountName
            return qbPlayer.Functions.RemoveMoney(mappedAccount, amount, 'bridge-transfer')
        end,
    }
end

function Bridge.GetPlayers()
    local players = {}
    local qbPlayers = QBCore.Functions.GetPlayers()
    for _, playerId in ipairs(qbPlayers) do
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
        grade = data.grade.level,
        grade_name = data.grade.name,
        grade_label = data.grade.name,
    }
end

return Bridge