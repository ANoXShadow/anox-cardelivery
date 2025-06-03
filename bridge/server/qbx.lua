local Bridge = {}
local QBX = nil

function Bridge.Init()
    local success, core = pcall(function()
        return exports['qb-core']:GetCoreObject()
    end)
    if success and core then
        QBX = core
        print('[Bridge] Successfully loaded QBX Core object via bridge')
        return true
    end
    print('[Bridge] Failed to get QBX Core object via qb-core bridge')
    return false
end

function Bridge.GetPlayer(source)
    if not QBX then
        print('[Bridge] QBX not initialized in GetPlayer')
        return nil
    end
    local qbxPlayer = QBX.Functions.GetPlayer(source)
    if not qbxPlayer then
        return nil
    end
    return {
        source = source,
        identifier = qbxPlayer.PlayerData.citizenid,
        name = qbxPlayer.PlayerData.charinfo.firstname .. ' ' .. qbxPlayer.PlayerData.charinfo.lastname,
        job = Bridge.ConvertJobData(qbxPlayer.PlayerData.job),
        getMoney = function()
            return qbxPlayer.Functions.GetMoney('cash')
        end,
        addMoney = function(amount)
            return qbxPlayer.Functions.AddMoney('cash', amount, 'bridge-transfer')
        end,
        removeMoney = function(amount)
            return qbxPlayer.Functions.RemoveMoney('cash', amount, 'bridge-transfer')
        end,
        getAccount = function(accountName)
            if accountName == 'bank' then
                return qbxPlayer.Functions.GetMoney('bank')
            elseif accountName == 'money' or accountName == 'cash' then
                return qbxPlayer.Functions.GetMoney('cash')
            else
                return qbxPlayer.Functions.GetMoney(accountName) or 0
            end
        end,
        addAccountMoney = function(accountName, amount)
            local accountMap = {
                money = 'cash',
                bank = 'bank',
                crypto = 'crypto'
            }
            local mappedAccount = accountMap[accountName] or accountName
            return qbxPlayer.Functions.AddMoney(mappedAccount, amount, 'bridge-transfer')
        end,
        removeAccountMoney = function(accountName, amount)
            local accountMap = {
                money = 'cash',
                bank = 'bank',
                crypto = 'crypto'
            }
            local mappedAccount = accountMap[accountName] or accountName
            return qbxPlayer.Functions.RemoveMoney(mappedAccount, amount, 'bridge-transfer')
        end,
    }
end

function Bridge.GetPlayers()
    if not QBX then
        return {}
    end
    local players = {}
    local qbxPlayers = QBX.Functions.GetPlayers()
    for _, playerId in ipairs(qbxPlayers) do
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