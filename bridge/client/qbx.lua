local Bridge = {}
local QBX = nil
local PlayerData = {}
local isInitialized = false

function Bridge.Init()
    local success, core = pcall(function()
        return exports['qb-core']:GetCoreObject()
    end)
    if success and core then
        QBX = core
        if LocalPlayer.state.isLoggedIn then
            PlayerData = QBX.Functions.GetPlayerData()
            isInitialized = true
        end
        print('[Bridge] Successfully loaded QBX Core object via bridge')
        return true
    end
    print('[Bridge] Failed to get QBX Core object via qb-core bridge')
    return false
end

function Bridge.RegisterEvents()
    RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
        PlayerData = QBX.Functions.GetPlayerData()
        isInitialized = true
        TriggerEvent('bridge:playerLoaded', Bridge.ConvertPlayerData(PlayerData))
    end)

    RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
        PlayerData.job = job
        TriggerEvent('bridge:jobUpdated', Bridge.ConvertJobData(job))
    end)
    
    RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
        PlayerData = {}
        isInitialized = false
    end)

    RegisterNetEvent('qbx_core:client:playerLoaded', function()
        PlayerData = QBX.Functions.GetPlayerData()
        isInitialized = true
        TriggerEvent('bridge:playerLoaded', Bridge.ConvertPlayerData(PlayerData))
    end)
    
    RegisterNetEvent('qbx_core:client:onJobUpdate', function(job)
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
    return isInitialized and PlayerData.job ~= nil
end

function Bridge.ConvertPlayerData(data)
    if not data then return nil end
    return {
        identifier = data.citizenid,
        name = data.charinfo and (data.charinfo.firstname .. ' ' .. data.charinfo.lastname) or 'Unknown',
        job = Bridge.ConvertJobData(data.job),
    }
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

function Bridge.WaitForPlayer()
    while not Bridge.IsPlayerLoaded() do
        Citizen.Wait(100)
    end
    return Bridge.GetPlayerData()
end

return Bridge