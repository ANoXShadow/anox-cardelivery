local Bridge = {}
local ESX = nil
local PlayerData = {}
local isInitialized = false

function Bridge.Init()
    ESX = exports["es_extended"]:getSharedObject()
    if not ESX then
        print('[Bridge] Failed to get ESX shared object')
        return false
    end
    PlayerData = ESX.GetPlayerData()
    isInitialized = true
    return true
end

function Bridge.RegisterEvents()
    RegisterNetEvent('esx:playerLoaded', function(xPlayer)
        PlayerData = xPlayer
        TriggerEvent('bridge:playerLoaded', Bridge.ConvertPlayerData(xPlayer))
    end)

    RegisterNetEvent('esx:setJob', function(job)
        PlayerData.job = job
        TriggerEvent('bridge:jobUpdated', Bridge.ConvertJobData(job))
    end)
end

function Bridge.GetPlayerData()
    if not isInitialized then
        local timeout = 0
        while not isInitialized and timeout < 5000 do
            Citizen.Wait(100)
            timeout = timeout + 100
        end
    end
    return Bridge.ConvertPlayerData(PlayerData)
end

function Bridge.GetPlayerJob()
    local playerData = Bridge.GetPlayerData()
    return playerData and playerData.job or nil
end

function Bridge.IsPlayerLoaded()
    return PlayerData ~= nil and PlayerData.job ~= nil
end

function Bridge.ConvertPlayerData(data)
    if not data then return nil end
    return {
        identifier = data.identifier,
        name = data.name,
        job = Bridge.ConvertJobData(data.job),
    }
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

function Bridge.WaitForPlayer()
    while not Bridge.IsPlayerLoaded() do
        Citizen.Wait(100)
    end
    return Bridge.GetPlayerData()
end

return Bridge