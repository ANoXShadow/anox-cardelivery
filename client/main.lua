local Bridge = require('bridge/loader')
local Framework = Bridge.Load()
local PlayerData = {}
local isInitialized = false
local currentJob = nil
local deliveryVehicle = nil
local deliveryBlip = nil
local isInDelivery = false
local cooldownTime = 0
local activeUI = {
    pickup = false,
    dropoff = false,
    timer = false
}
local dialogOpen = false
local activeThreads = {
    pickup = nil,
    dropoff = nil,
    timer = nil,
    vehicleMonitor = nil
}
local vehicleExitState = {
    lastVehicle = nil,
    exitCheckEnabled = false,
    exitStartTime = 0
}

local function ValidateCoords(coords)
    if not coords then return false end
    if type(coords) == 'vector3' or type(coords) == 'vector4' then
        return true
    end
    if type(coords) == 'table' then
        return coords.x ~= nil and coords.y ~= nil and coords.z ~= nil
    end
    return false
end

local function ValidateJobData(jobData)
    if not jobData or type(jobData) ~= 'table' then
        return false
    end
    return ValidateCoords(jobData.pickup) and 
           ValidateCoords(jobData.dropoff) and
           jobData.carModel and 
           jobData.carName and 
           jobData.timeLimit
end

local function CalculateReward()
    if not currentJob then return 0 end
    local timeElapsed = (GetGameTimer() - currentJob.startTime) / 1000
    local baseReward = Config.Job.baseReward
    local bonus = 0
    if timeElapsed <= Config.Job.bonusTimeLimit then
        bonus = Config.Job.bonusReward
    end
    return baseReward + bonus
end

local function CalculateDamagePenalty(damage)
    if not Config.Job.damageSettings.penaltyEnabled or damage < Config.Job.damageSettings.minDamageThreshold then
        return 0
    end
    local penalty = math.floor(Config.Job.baseReward * damage * Config.Job.damageSettings.penaltyMultiplier)
    local maxPenalty = Config.Job.baseReward * Config.Job.damageSettings.maxPenaltyPercent
    return math.min(penalty, maxPenalty)
end

local StartPickupThread, StartDropoffThread, StartTimerThread, StartVehicleMonitorThread
local CreateBlip, CompleteDelivery
local TransitionToDelivery
local ShowPickupDialog, ShowDropoffDialog

local function ShowUI(text, options)
    Framework.ShowTextUI(text, options)
end

local function HideUI()
    Framework.HideTextUI()
end

local function CleanupAll()
    Framework.Debug('Starting cleanup process', 'info')
    HideUI()
    for key, thread in pairs(activeThreads) do
        if thread then
            activeThreads[key] = nil
        end
    end
    for key in pairs(activeUI) do
        activeUI[key] = false
    end
    vehicleExitState.lastVehicle = nil
    vehicleExitState.exitCheckEnabled = false
    vehicleExitState.exitStartTime = 0
    dialogOpen = false
    if deliveryBlip then
        RemoveBlip(deliveryBlip)
        deliveryBlip = nil
    end
    if deliveryVehicle and DoesEntityExist(deliveryVehicle) then
        SetEntityAsMissionEntity(deliveryVehicle, true, true)
        DeleteEntity(deliveryVehicle)
    end
    deliveryVehicle = nil
    currentJob = nil
    isInDelivery = false
    Framework.Debug('Cleanup completed', 'info')
end

local function FailDelivery(reason)
    if not currentJob then return end
    Framework.Debug('Delivery failed: ' .. reason, 'error')
    TriggerServerEvent('anox-cardelivery:server:failJob', reason)
    CleanupAll()
    Framework.Notify(nil, _L('delivery_failed'), reason, 'error', 5000)
end

local function StopUIThread(threadType)
    Framework.Debug('Stopping UI thread: ' .. threadType, 'info')
    if activeUI[threadType] then
        activeUI[threadType] = false
    end
    HideUI()
    if activeThreads[threadType] then
        activeThreads[threadType] = nil
    end
end

local function StartDeliveryJob()
    if currentJob then
        Framework.Notify(nil, _L('car_delivery'), _L('already_active'), 'error')
        return
    end
    if cooldownTime > 0 then
        Framework.Notify(nil, _L('car_delivery'), _L('on_cooldown', cooldownTime), 'error')
        return
    end
    TriggerServerEvent('anox-cardelivery:server:requestJob')
end

local function CreateDeliveryNPC()
    local npcCoords = Config.NPC.coords
    RequestModel(GetHashKey(Config.NPC.model))
    while not HasModelLoaded(GetHashKey(Config.NPC.model)) do
        Citizen.Wait(1)
    end
    local npc = CreatePed(4, GetHashKey(Config.NPC.model), 
        npcCoords.x, npcCoords.y, npcCoords.z - 1.0, npcCoords.w, false, true)
    SetEntityHeading(npc, npcCoords.w)
    FreezeEntityPosition(npc, true)
    SetEntityInvincible(npc, true)
    SetBlockingOfNonTemporaryEvents(npc, true)
    if Config.NPC.scenario then
        TaskStartScenarioInPlace(npc, Config.NPC.scenario, 0, true)
    end
    if Config.NPC.blip.enabled then
        local blip = AddBlipForCoord(npcCoords.x, npcCoords.y, npcCoords.z)
        SetBlipSprite(blip, Config.NPC.blip.sprite)
        SetBlipDisplay(blip, Config.NPC.blip.display)
        SetBlipScale(blip, Config.NPC.blip.scale)
        SetBlipColour(blip, Config.NPC.blip.color)
        SetBlipAsShortRange(blip, Config.NPC.blip.shortRange)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(_L('car_delivery_agent'))
        EndTextCommandSetBlipName(blip)
    end
    Framework.Target.AddLocalEntity(npc, {
        {
            name = 'cardelivery_npc',
            icon = Config.NPC.target.icon,
            label = _L('talk_to_manager'),
            distance = Config.NPC.target.distance,
            onSelect = StartDeliveryJob
        }
    })
end

local function StartCooldownTimer()
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(1000)
            if cooldownTime > 0 then
                cooldownTime = cooldownTime - 1
            end
        end
    end)
end

function TransitionToDelivery()
    StopUIThread('pickup')
    if deliveryBlip then
        RemoveBlip(deliveryBlip)
        deliveryBlip = nil
    end
    CreateBlip(currentJob.dropoff, 'dropoff')
    Citizen.SetTimeout(100, function()
        StartDropoffThread()
    end)
    if Config.Vehicles.exitMonitoring.enabled then
        vehicleExitState.exitCheckEnabled = true
        vehicleExitState.lastVehicle = deliveryVehicle
        vehicleExitState.exitGracePeriod = Config.Vehicles.exitMonitoring.gracePeriod
        StartVehicleMonitorThread()
    end
    Citizen.CreateThread(function()
        while currentJob and deliveryVehicle do
            local playerPed = PlayerPedId()
            local currentVehicle = GetVehiclePedIsIn(playerPed, false)
            if currentVehicle == deliveryVehicle then
                currentJob.startTime = GetGameTimer()
                StartTimerThread()
                break
            end
            Citizen.Wait(100)
        end
    end)
end

function CompleteDelivery()
    if not currentJob or not deliveryVehicle then return end
    StopUIThread('dropoff')
    StopUIThread('timer')
    StopUIThread('vehicleMonitor')
    local vehicleHealth = GetEntityHealth(deliveryVehicle)
    local damage = (1000 - vehicleHealth) / 1000
    if DoesEntityExist(deliveryVehicle) then
        SetEntityAsMissionEntity(deliveryVehicle, true, true)
        DeleteEntity(deliveryVehicle)
    end
    TriggerServerEvent('anox-cardelivery:server:completeJob', {
        plate = currentJob.vehiclePlate,
        damage = damage,
        timeElapsed = (GetGameTimer() - currentJob.startTime) / 1000
    })
end

function StartVehicleMonitorThread()
    if activeThreads.vehicleMonitor then return end
    activeThreads.vehicleMonitor = true
    Citizen.CreateThread(function()
        while currentJob and deliveryVehicle and DoesEntityExist(deliveryVehicle) and activeThreads.vehicleMonitor do
            local playerPed = PlayerPedId()
            local currentVehicle = GetVehiclePedIsIn(playerPed, false)
            if currentVehicle == deliveryVehicle then
                if vehicleExitState.exitStartTime > 0 then
                    vehicleExitState.exitStartTime = 0
                    if activeUI.timer then
                        activeUI.timer = false
                    end
                end
            else
                if vehicleExitState.exitCheckEnabled then
                    if vehicleExitState.exitStartTime == 0 then
                        vehicleExitState.exitStartTime = GetGameTimer()
                        if Config.Vehicles.exitMonitoring.warningEnabled then
                            Framework.Notify(nil, _L('warning'), _L('vehicle_exit_warning'), 'warning', 
                                Config.Vehicles.exitMonitoring.warningDuration)
                        end
                    else
                        local timeOutside = GetGameTimer() - vehicleExitState.exitStartTime
                        if timeOutside > vehicleExitState.exitGracePeriod and Config.Vehicles.exitMonitoring.autoFailEnabled then
                            FailDelivery(_L('vehicle_abandoned'))
                            break
                        end
                    end
                end
            end
            Citizen.Wait(Config.Vehicles.exitMonitoring.checkInterval)
        end
        activeThreads.vehicleMonitor = nil
    end)
end

function StartPickupThread()
    if activeThreads.pickup then 
        Framework.Debug('Pickup thread already running', 'info')
        return 
    end
    if not currentJob or deliveryVehicle then 
        Framework.Debug('Cannot start pickup thread - invalid state', 'info')
        return 
    end
    activeUI.pickup = false
    Framework.Debug('Starting pickup thread', 'info')
    activeThreads.pickup = true
    Citizen.CreateThread(function()
        while currentJob and not deliveryVehicle and activeThreads.pickup do
            local playerCoords = GetEntityCoords(PlayerPedId())
            local distance = #(playerCoords - vector3(currentJob.pickup.x, currentJob.pickup.y, currentJob.pickup.z))
            if distance < 5.0 then
                if not activeUI.pickup and not dialogOpen then
                    activeUI.pickup = true
                    ShowUI(_L('pickup_prompt', currentJob.carName), {
                        position = 'right-center',
                        icon = 'car',
                        iconColor = '#00ff00'
                    })
                    Framework.Debug('Showing pickup UI', 'info')
                end
            else
                if activeUI.pickup then
                    activeUI.pickup = false
                    HideUI()
                    Framework.Debug('Hiding pickup UI - too far', 'info')
                end
            end
            Citizen.Wait(100)
        end
        if activeUI.pickup then
            activeUI.pickup = false
            HideUI()
        end
        activeThreads.pickup = nil
        Framework.Debug('Pickup thread ended', 'info')
    end)
end

function StartDropoffThread()
    if activeThreads.dropoff then return end
    activeUI.dropoff = false
    activeThreads.dropoff = true
    Citizen.CreateThread(function()
        while currentJob and deliveryVehicle and DoesEntityExist(deliveryVehicle) and activeThreads.dropoff do
            local playerPed = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(playerPed, false)
            if vehicle == deliveryVehicle then
                local playerCoords = GetEntityCoords(playerPed)
                local distance = #(playerCoords - vector3(currentJob.dropoff.x, currentJob.dropoff.y, currentJob.dropoff.z))
                if distance < 5.0 and not dialogOpen then
                    if not activeUI.dropoff then
                        if activeUI.timer then
                            activeUI.timer = false
                            HideUI()
                        end
                        activeUI.dropoff = true
                        local reward = CalculateReward()
                        ShowUI(_L('dropoff_prompt', currentJob.carName, reward), {
                            position = 'right-center',
                            icon = 'hand-holding-dollar',
                            iconColor = '#00ff00'
                        })
                    end
                else
                    if activeUI.dropoff then
                        activeUI.dropoff = false
                        HideUI()
                        if not activeUI.timer and activeThreads.timer then
                            Citizen.SetTimeout(100, function()
                                if currentJob and not activeUI.dropoff and not dialogOpen then
                                    activeUI.timer = true
                                end
                            end)
                        end
                    end
                end
            else
                if activeUI.dropoff then
                    activeUI.dropoff = false
                    HideUI()
                    if not activeUI.timer and activeThreads.timer then
                        Citizen.SetTimeout(100, function()
                            if currentJob and not activeUI.dropoff and not dialogOpen then
                                activeUI.timer = true
                            end
                        end)
                    end
                end
            end
            Citizen.Wait(100)
        end
        if activeUI.dropoff then
            activeUI.dropoff = false
            HideUI()
        end
        activeThreads.dropoff = nil
    end)
end

function StartTimerThread()
    if activeThreads.timer then return end
    activeUI.timer = false
    activeThreads.timer = true
    Citizen.CreateThread(function()
        while currentJob and activeThreads.timer and deliveryVehicle and DoesEntityExist(deliveryVehicle) do
            local timeLeft = currentJob.timeLimit - math.floor((GetGameTimer() - currentJob.startTime) / 1000)
            if timeLeft <= 0 then
                TriggerServerEvent('anox-cardelivery:server:jobTimeout')
                break
            end
            local vehicleHealth = GetEntityHealth(deliveryVehicle)
            local healthPercent = math.floor(((vehicleHealth - 100) / 900) * 100)
            local timeElapsed = math.floor((GetGameTimer() - currentJob.startTime) / 1000)
            local isBonusActive = timeElapsed <= Config.Job.bonusTimeLimit
            local playerPed = PlayerPedId()
            local currentVehicle = GetVehiclePedIsIn(playerPed, false)
            local isOutsideVehicle = currentVehicle ~= deliveryVehicle
            if not activeUI.pickup and not activeUI.dropoff and not dialogOpen then
                if not activeUI.timer then
                    activeUI.timer = true
                end
                local displayText = ""
                local iconColor = '#ffffff'
                if isOutsideVehicle and vehicleExitState.exitStartTime > 0 then
                    local timeOutside = GetGameTimer() - vehicleExitState.exitStartTime
                    local exitTimeLeft = math.ceil((vehicleExitState.exitGracePeriod - timeOutside) / 1000)
                    if exitTimeLeft > 0 then
                        local exitMinutes = math.floor(exitTimeLeft / 60)
                        local exitSeconds = exitTimeLeft % 60
                        local exitTimeString = string.format("%02d:%02d", exitMinutes, exitSeconds)
                        local minutes = math.floor(timeLeft / 60)
                        local seconds = timeLeft % 60
                        local timeString = string.format("%02d:%02d", minutes, seconds)
                        displayText = _L('timer_display_exit', exitTimeString, timeString, healthPercent)
                        iconColor = '#ff0000'
                    end
                else
                    local bonusStatus = isBonusActive and _L('active') or _L('expired')
                    local minutes = math.floor(timeLeft / 60)
                    local seconds = timeLeft % 60
                    local timeString = string.format("%02d:%02d", minutes, seconds)
                    displayText = _L('timer_display', timeString, healthPercent, bonusStatus)
                    iconColor = timeLeft < 60 and '#ff0000' or '#ffffff'
                end
                ShowUI(displayText, {
                    position = "top-center",
                    icon = 'clock',
                    iconColor = iconColor
                })
            else
                if activeUI.timer then
                    activeUI.timer = false
                    HideUI()
                end
            end
            Citizen.Wait(1000)
        end
        if activeUI.timer then
            activeUI.timer = false
            HideUI()
        end
        activeThreads.timer = nil
    end)
end

function CreateBlip(coords, blipType)
    if deliveryBlip then
        RemoveBlip(deliveryBlip)
    end
    local blipConfig = Config.Blips[blipType]
    deliveryBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(deliveryBlip, blipConfig.sprite)
    SetBlipDisplay(deliveryBlip, blipConfig.display)
    SetBlipScale(deliveryBlip, blipConfig.scale)
    SetBlipColour(deliveryBlip, blipConfig.color)
    SetBlipAsShortRange(deliveryBlip, blipConfig.shortRange)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(_L(blipType == 'pickup' and 'vehicle_pickup' or 'vehicle_dropoff'))
    EndTextCommandSetBlipName(deliveryBlip)
    if blipConfig.route then
        SetBlipRoute(deliveryBlip, true)
        SetBlipRouteColour(deliveryBlip, blipConfig.color)
    end
    if blipConfig.flash then
        SetBlipFlashes(deliveryBlip, true)
    end
end

function ShowPickupDialog()
    if activeUI.pickup then
        activeUI.pickup = false
        HideUI()
    end
    dialogOpen = true
    Citizen.CreateThread(function()
        local alert = Framework.AlertDialog({
            header = _L('vehicle_pickup_header'),
            content = _L('vehicle_pickup_dialog', currentJob.carName),
            centered = true,
            cancel = true,
            labels = {
                confirm = _L('collect_vehicle'),
                cancel = _L('cancel')
            }
        })
        Citizen.Wait(100)
        dialogOpen = false
        if alert == 'confirm' then
            if currentJob then
                StopUIThread('pickup')
                TriggerServerEvent('anox-cardelivery:server:spawnVehicle')
            end
        else
            Citizen.Wait(300)
            if currentJob and not deliveryVehicle and not activeThreads.pickup then
                activeUI.pickup = false
                StartPickupThread()
            end
        end
    end)
end

function ShowDropoffDialog()
    if activeUI.dropoff then
        activeUI.dropoff = false
        HideUI()
    elseif activeUI.timer then
        activeUI.timer = false
        HideUI()
    end
    dialogOpen = true
    Citizen.CreateThread(function()
        local reward = CalculateReward()
        local vehicleHealth = GetEntityHealth(deliveryVehicle)
        local damage = (1000 - vehicleHealth) / 1000
        local timeElapsed = math.floor((GetGameTimer() - currentJob.startTime) / 1000)
        local isBonusActive = timeElapsed <= Config.Job.bonusTimeLimit
        local damageText = ""
        if damage > Config.Job.damageSettings.visualDamageWarning then
            damageText = "\n\n⚠️ **" .. _L('damage_warning', damage * 100) .. "**"
        end
        local damagePenalty = CalculateDamagePenalty(damage)
        if damagePenalty > 0 then
            damageText = damageText .. "\n" .. _L('damage_penalty', damagePenalty)
        end
        local bonusText = isBonusActive and _L('active') or _L('expired')
        local bonusColor = isBonusActive and '🟢' or '🔴'
        local alert = Framework.AlertDialog({
            header = _L('complete_delivery_header'),
            content = _L('complete_delivery_content', 
                currentJob.carName, 
                reward,
                bonusColor,
                bonusText,
                (1 - damage) * 100,
                timeElapsed,
                damageText
            ),
            centered = true,
            cancel = true,
            labels = {
                confirm = _L('complete_delivery_button'),
                cancel = _L('cancel')
            }
        })
        Citizen.Wait(100)
        dialogOpen = false
        if alert == 'confirm' then
            CompleteDelivery()
        else
            Citizen.Wait(300)
            if currentJob and deliveryVehicle then
                local playerPed = PlayerPedId()
                local vehicle = GetVehiclePedIsIn(playerPed, false)
                local playerCoords = GetEntityCoords(playerPed)
                local distanceToDropoff = #(playerCoords - vector3(currentJob.dropoff.x, currentJob.dropoff.y, currentJob.dropoff.z))
                if vehicle == deliveryVehicle and distanceToDropoff < 5.0 then
                    if not activeThreads.dropoff then
                        activeUI.dropoff = false
                        StartDropoffThread()
                    end
                else
                    if activeThreads.timer and not activeUI.timer then
                        activeUI.timer = true
                    end
                end
            end
        end
    end)
end

RegisterNetEvent('anox-cardelivery:client:vehicleSpawned', function(vehicleNetId, vehiclePlate)
    if not currentJob then return end
    Framework.Debug('Received vehicle spawn notification from server', 'info')
    local timeout = 0
    while not NetworkDoesEntityExistWithNetworkId(vehicleNetId) and timeout < 50 do
        Citizen.Wait(100)
        timeout = timeout + 1
    end
    if not NetworkDoesEntityExistWithNetworkId(vehicleNetId) then
        Framework.Debug('Failed to find spawned vehicle', 'error')
        return
    end
    deliveryVehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    currentJob.vehiclePlate = vehiclePlate
    currentJob.startTime = GetGameTimer()
    SetEntityAsMissionEntity(deliveryVehicle, true, true)
    SetVehicleHasBeenOwnedByPlayer(deliveryVehicle, true)
    SetVehicleNeedsToBeHotwired(deliveryVehicle, false)
    SetVehicleDoorsLocked(deliveryVehicle, Config.Vehicles.lockDoors and 2 or 1)
    SetVehicleDirtLevel(deliveryVehicle, Config.Vehicles.dirtLevel)
    SetVehicleEngineOn(deliveryVehicle, Config.Vehicles.engineOn, true, true)
    if Config.Vehicles.maxSpeed > 0 then
        SetVehicleMaxSpeed(deliveryVehicle, Config.Vehicles.maxSpeed)
    end
    if Config.Vehicles.teleportPlayer then
        TaskWarpPedIntoVehicle(PlayerPedId(), deliveryVehicle, -1)
    end
    Framework.Debug('Vehicle received and configured on client', 'success')
    Framework.Notify(nil, _L('vehicle_ready'), _L('vehicle_ready'), 'success', 3000)
    Framework.SetVehicleKeys(vehicleNetId, vehiclePlate)
    TransitionToDelivery()
end)

RegisterNetEvent('bridge:playerLoaded', function(playerData)
    PlayerData = playerData
end)

RegisterNetEvent('bridge:jobUpdated', function(job)
    PlayerData.job = job
end)

RegisterNetEvent('anox-cardelivery:client:startJob', function(jobData)
    Framework.Debug('Received startJob event', 'info')
    if not ValidateJobData(jobData) then 
        Framework.Debug('Invalid job data received', 'error')
        return 
    end
    if currentJob then 
        Framework.Debug('Job already active, ignoring new job', 'warning')
        return 
    end
    CleanupAll()
    Citizen.Wait(200)
    currentJob = jobData
    isInDelivery = true
    Framework.Debug('Job data set, creating blip', 'info')
    CreateBlip(jobData.pickup, 'pickup')
    Citizen.SetTimeout(500, function()
        if currentJob and not deliveryVehicle then
            Framework.Debug('Starting pickup thread for new job', 'info')
            StartPickupThread()
        end
    end)
    Framework.Notify(nil, _L('car_delivery'), _L('job_started', jobData.carName), 'success', 5000)
end)

RegisterNetEvent('anox-cardelivery:client:endJob', function(success, amount, bonus)
    if not currentJob then return end
    Framework.Debug('Job ended - success: ' .. tostring(success), 'info')
    CleanupAll()
    if success then
        local message = _L('job_completed', amount)
        if bonus and bonus > 0 then
            message = message .. '\n' .. _L('job_bonus', bonus)
        end
        Framework.Notify(nil, _L('delivery_complete'), message, 'success', 5000)
    else
        Framework.Notify(nil, _L('delivery_failed'), _L('job_failed', Config.Job.deposit), 'error', 5000)
    end
    cooldownTime = Config.Job.cooldown
end)

local function Initialize()
    while not Framework do
        Citizen.Wait(100)
    end
    PlayerData = Framework.WaitForPlayer()
    CreateDeliveryNPC()
    StartCooldownTimer()
    isInitialized = true
    Framework.Debug('Client initialized successfully', 'success')
end

Citizen.CreateThread(function()
    while true do
        local sleep = 1000
        if currentJob and not dialogOpen then
            sleep = 0
            if IsControlJustPressed(0, 38) then
                local playerCoords = GetEntityCoords(PlayerPedId())
                if not deliveryVehicle and activeUI.pickup then
                    local distance = #(playerCoords - vector3(currentJob.pickup.x, currentJob.pickup.y, currentJob.pickup.z))
                    if distance < 5.0 then
                        Framework.Debug('E pressed - showing pickup dialog', 'info')
                        ShowPickupDialog()
                    end
                elseif deliveryVehicle and activeUI.dropoff then
                    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
                    if vehicle == deliveryVehicle then
                        local distance = #(playerCoords - vector3(currentJob.dropoff.x, currentJob.dropoff.y, currentJob.dropoff.z))
                        if distance < 5.0 then
                            ShowDropoffDialog()
                        end
                    end
                end
            end
        end
        Citizen.Wait(sleep)
    end
end)

Citizen.CreateThread(function()
    while true do
        if deliveryVehicle and DoesEntityExist(deliveryVehicle) then
            local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
            if vehicle == deliveryVehicle then
                local currentPlate = GetVehicleNumberPlateText(vehicle)
                if currentPlate ~= currentJob.vehiclePlate then
                    SetVehicleNumberPlateText(vehicle, currentJob.vehiclePlate)
                end
            end
        end
        Citizen.Wait(1000)
    end
end)

Citizen.CreateThread(function()
    Initialize()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        CleanupAll()
        Framework.Debug('Cleaning up target zones', 'info')
    end
end)