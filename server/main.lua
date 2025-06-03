local Bridge = require('bridge/loader')
local Framework = Bridge.Load()
local activeJobs = {}
local occupiedLocations = {
    pickup = {},
    dropoff = {}
}
local playerActionCooldowns = {}

local function GeneratePlate()
    return Config.CarPlate.platePrefix .. math.random(10^(Config.CarPlate.plateDigits-1), 10^Config.CarPlate.plateDigits - 1)
end

local function ConfigureVehicle(vehicle, plate)
    SetVehicleNumberPlateText(vehicle, plate)
end

local function SpawnDeliveryVehicle(playerId, job)
    local player = Framework.GetPlayer(playerId)
    if not player then return false end
    Framework.Debug(string.format('Spawning vehicle for player %s', player.name), 'info')
    local modelHash = GetHashKey(job.carModel)
    if not modelHash or modelHash == 0 then
        Framework.Debug('Invalid vehicle model hash: ' .. tostring(job.carModel), 'error')
        return false
    end
    local spawnCoords = job.pickup
    local playerPed = GetPlayerPed(playerId)
    if not playerPed or playerPed == 0 then
        Framework.Debug('Invalid player ped', 'error')
        return false
    end
    local playerCoords = GetEntityCoords(playerPed)
    local distance = #(playerCoords - vector3(spawnCoords.x, spawnCoords.y, spawnCoords.z))
    if distance > Config.Vehicles.spawnValidation.maxDistance then
        Framework.Debug(string.format('Player %s too far from pickup: %.2f units', playerId, distance), 'warning')
        return false
    end
    local vehicle = CreateVehicle(modelHash, 
        spawnCoords.x, spawnCoords.y, spawnCoords.z + (Config.Vehicles.spawnHeight or 1.0), 
        spawnCoords.w or 0.0, true, false)
    if not vehicle or vehicle == 0 then
        Framework.Debug('Failed to create vehicle - CreateVehicle returned invalid handle', 'error')
        return false
    end
    local timeout = 0
    while not DoesEntityExist(vehicle) and timeout < 100 do
        Citizen.Wait(10)
        timeout = timeout + 1
    end
    if not DoesEntityExist(vehicle) then
        Framework.Debug('Failed to create vehicle - entity does not exist after creation', 'error')
        return false
    end
    local plate = GeneratePlate()
    ConfigureVehicle(vehicle, plate)
    if Framework.SetFuel then
        Framework.SetFuel(vehicle, Config.Vehicles.defaultFuel or 100)
    end
    if GetResourceState('qbx_vehiclekeys') == 'started' then
        exports.qbx_vehiclekeys:GiveKeys(playerId, vehicle, false)
        Framework.Debug(string.format('Keys given to player %s for vehicle %s', playerId, plate), 'info')
    end
    job.vehicle = vehicle
    job.vehiclePlate = plate
    job.vehicleSpawned = true
    job.actualStartTime = os.time()
    job.spawnedAt = playerCoords
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    TriggerClientEvent('anox-cardelivery:client:vehicleSpawned', playerId, netId, plate)
    Framework.Debug(string.format('Vehicle spawned successfully for player %s, plate: %s, netId: %s', 
        player.name, plate, netId), 'success')
    return true
end

RegisterNetEvent('anox-cardelivery:server:spawnVehicle', function()
    local src = source
    local player = Framework.GetPlayer(src)
    local job = activeJobs[src]
    if not player or not job then
        Framework.Debug(string.format('Invalid spawn request from player %s', src), 'error')
        return
    end
    if not CheckActionCooldown(src, 'spawn', Config.AntiExploit.actionCooldowns.spawn) then
        Framework.Debug(string.format('Player %s spawn request blocked by cooldown', src), 'warning')
        return
    end
    if job.vehicleSpawned then
        Framework.Debug(string.format('Player %s attempted to spawn vehicle twice', src), 'warning')
        return
    end
    local playerPed = GetPlayerPed(src)
    if not playerPed or playerPed == 0 then
        Framework.Debug(string.format('Invalid player ped for spawn request from %s', src), 'error')
        return
    end
    local playerCoords = GetEntityCoords(playerPed)
    local distance = #(playerCoords - vector3(job.pickup.x, job.pickup.y, job.pickup.z))
    if distance > Config.Vehicles.spawnValidation.maxDistance then
        Framework.Debug(string.format('Player %s too far from pickup for spawn: %.2f units', src, distance), 'warning')
        SendNotification(src, _L('car_delivery'), _L('too_far_pickup', distance), 'error')
        return
    end
    local success = SpawnDeliveryVehicle(src, job)
    if not success then
        SendNotification(src, _L('car_delivery'), _L('spawn_failed'), 'error')
    end
end)

RegisterNetEvent('anox-cardelivery:server:requestJob', function()
    local src = source
    local player = Framework.GetPlayer(src)
    if not player then return end
    if not CheckActionCooldown(src, 'request', Config.AntiExploit.actionCooldowns.request) then return end
    local validation = ValidateJobRequest(src, player)
    if not validation.success then
        SendNotification(src, _L('car_delivery'), validation.message, 'error')
        return
    end
    local availablePickups = GetAvailableLocations('pickup')
    local availableDropoffs = GetAvailableLocations('dropoff')
    if #availablePickups == 0 or #availableDropoffs == 0 then
        SendNotification(src, _L('car_delivery'), _L('no_locations'), 'error')
        return
    end
    if GetActiveJobCount() >= Config.Job.maxActiveJobs then
        SendNotification(src, _L('car_delivery'), _L('server_capacity'), 'error')
        return
    end
    local job = CreateJob(src, player, availablePickups, availableDropoffs)
    if job then
        activeJobs[src] = job
        occupiedLocations.pickup[job.pickupIndex] = src
        occupiedLocations.dropoff[job.dropoffIndex] = src
        TriggerClientEvent('anox-cardelivery:client:startJob', src, {
            pickup = job.pickup,
            dropoff = job.dropoff,
            carModel = job.carModel,
            carName = job.carName,
            timeLimit = job.timeLimit
        })
        Framework.Debug(string.format('Job started for player %s', player.name), 'success')
    end
end)

RegisterNetEvent('anox-cardelivery:server:vehicleSpawned', function(data)
    local src = source
    local player = Framework.GetPlayer(src)
    local job = activeJobs[src]
    if not player or not job then return end
    if not CheckActionCooldown(src, 'spawn_confirm', Config.AntiExploit.actionCooldowns.spawn) then return end
    Framework.Debug(string.format('Vehicle spawn confirmed for player %s', player.name), 'info')
end)

RegisterNetEvent('anox-cardelivery:server:completeJob', function(data)
    local src = source
    local player = Framework.GetPlayer(src)
    local job = activeJobs[src]
    if not player or not job then return end
    if not CheckActionCooldown(src, 'complete', Config.AntiExploit.actionCooldowns.complete) then return end
    local validation = ValidateJobCompletion(src, job, data)
    if not validation.success then
        Framework.Debug(string.format('Job completion validation failed: %s', validation.message), 'error')
        SendNotification(src, _L('car_delivery'), validation.message, 'error')
        if job.vehicle and DoesEntityExist(job.vehicle) then
            DeleteEntity(job.vehicle)
            Framework.Debug(string.format('Vehicle deleted for failed validation, player %s', src), 'info')
        end
        CleanupJob(src, false, 0, 0)
        return
    end
    if job.vehicle and DoesEntityExist(job.vehicle) then
        DeleteEntity(job.vehicle)
        Framework.Debug(string.format('Vehicle deleted for completed job, player %s', src), 'info')
    end
    local rewards = CalculateRewards(job, validation.timeElapsed, validation.damage)
    player.addMoney(job.deposit) -- Refund deposit
    player.addMoney(rewards.total) -- Add reward
    Framework.Debug(string.format('Job completed by %s (%s). Time: %ds, Damage: %.1f%%, Reward: $%d', 
        player.name, src, validation.timeElapsed, validation.damage * 100, rewards.total), 'success')
    CleanupJob(src, true, rewards.total, rewards.bonus)
end)

RegisterNetEvent('anox-cardelivery:server:failJob', function(reason)
    local src = source
    local player = Framework.GetPlayer(src)
    local job = activeJobs[src]
    if not player or not job then return end
    if not CheckActionCooldown(src, 'fail', Config.AntiExploit.actionCooldowns.fail) then return end
    if job.vehicle and DoesEntityExist(job.vehicle) then
        DeleteEntity(job.vehicle)
        Framework.Debug(string.format('Vehicle deleted for failed job, player %s', src), 'info')
    end
    Framework.Debug(string.format('Job failed for player %s (%s): %s', 
        player.name, src, reason or "Unknown reason"), 'warning')
    CleanupJob(src, false, 0, 0)
end)

RegisterNetEvent('anox-cardelivery:server:jobTimeout', function()
    local src = source
    local job = activeJobs[src]
    if not job then return end
    local timeElapsed = os.time() - (job.actualStartTime or job.startTime)
    if timeElapsed < job.timeLimit then
        Framework.Debug(string.format('Player %s false timeout claim (%ds < %ds)', 
            src, timeElapsed, job.timeLimit), 'warning')
        return
    end
    if job.vehicle and DoesEntityExist(job.vehicle) then
        DeleteEntity(job.vehicle)
        Framework.Debug(string.format('Vehicle deleted for timed out job, player %s', src), 'info')
    end
    CleanupJob(src, false, 0, 0)
    Framework.Debug(string.format('Job timed out for player %s', src), 'warning')
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    if activeJobs[src] then
        local job = activeJobs[src]
        if job.vehicle and DoesEntityExist(job.vehicle) then
            DeleteEntity(job.vehicle)
            Framework.Debug(string.format('Vehicle deleted for dropped player %s', src), 'info')
        end
        CleanupJob(src, false, 0, 0)
        ClearPlayerCooldowns(src)
    end
end)

function ValidateJobRequest(playerId, player)
    if activeJobs[playerId] then
        return { success = false, message = _L('already_active') }
    end
    local playerMoney = player.getMoney()
    if playerMoney < Config.Job.deposit then
        return { success = false, message = _L('insufficient_funds', Config.Job.deposit) }
    end
    return { success = true }
end

function ValidateVehicleSpawn(playerId, job, data)
    if job.vehicleSpawned then
        Framework.Debug(string.format('Player %s attempted to spawn vehicle twice', playerId), 'warning')
        return { success = false, message = _L('vehicle_already_spawned') }
    end
    job.spawnAttempts = (job.spawnAttempts or 0) + 1
    if job.spawnAttempts > Config.AntiExploit.maxSpawnAttempts then
        Framework.Debug(string.format('Player %s exceeded max spawn attempts', playerId), 'error')
        return { success = false, message = _L('too_many_attempts') }
    end
    local playerPed = GetPlayerPed(playerId)
    if not playerPed or playerPed == 0 then
        Framework.Debug(string.format('Invalid player ped for player %s', playerId), 'error')
        return { success = false, message = _L('invalid_player_ped') }
    end
    local playerCoords = GetEntityCoords(playerPed)
    local distance = #(playerCoords - vector3(job.pickup.x, job.pickup.y, job.pickup.z))
    if distance > Config.Vehicles.spawnValidation.maxDistance then
        Framework.Debug(string.format('Player %s too far from pickup: %.2f units', playerId, distance), 'warning')
        return { success = false, message = _L('too_far_pickup', distance) }
    end
    if data and data.plate and type(data.plate) == 'string' then
        local platePattern = "^" .. Config.CarPlate.platePrefix .. string.rep("%d", Config.CarPlate.plateDigits) .. "$"
        if not string.match(data.plate, platePattern) then
            Framework.Debug(string.format('Invalid plate format from player %s: %s', playerId, data.plate), 'error')
            return { success = false, message = _L('invalid_plate_format') }
        end
        if data.model and data.model ~= job.carModel then
            Framework.Debug(string.format('Model mismatch for player %s: expected %s, got %s', 
                playerId, job.carModel, tostring(data.model)), 'error')
            return { success = false, message = _L('model_mismatch') }
        end
    end
    return { success = true }
end

function ValidateJobCompletion(playerId, job, data)
    if not job.vehicleSpawned then
        return { success = false, message = _L('no_vehicle_spawned') }
    end
    local playerPed = GetPlayerPed(playerId)
    if not playerPed or playerPed == 0 then
        return { success = false, message = _L('invalid_player') }
    end
    local playerCoords = GetEntityCoords(playerPed)
    local distance = #(playerCoords - vector3(job.dropoff.x, job.dropoff.y, job.dropoff.z))
    if distance > 5.0 then
        return { success = false, message = _L('too_far_away') }
    end
    if not data.plate or data.plate ~= job.vehiclePlate then
        return { success = false, message = _L('wrong_vehicle') }
    end
    local timeElapsed = os.time() - (job.actualStartTime or job.startTime)
    if timeElapsed < Config.AntiExploit.minCompletionTime then
        return { success = false, message = _L('job_too_quick') }
    end
    local damage = tonumber(data.damage) or 0
    damage = math.max(0, math.min(1, damage))
    if job.spawnedAt and Config.AntiExploit.teleportDetection.enabled then
        local totalDistance = #(job.spawnedAt - playerCoords)
        local directDistance = #(vector3(job.pickup.x, job.pickup.y, job.pickup.z) - 
                                vector3(job.dropoff.x, job.dropoff.y, job.dropoff.z))
        local minimumDistance = directDistance * Config.AntiExploit.teleportDetection.minimumDistancePercent
        if totalDistance < minimumDistance then
            return { success = false, message = _L('insufficient_distance') }
        end
    end
    return { 
        success = true, 
        timeElapsed = timeElapsed,
        damage = damage
    }
end

function CreateJob(playerId, player, availablePickups, availableDropoffs)
    player.removeMoney(Config.Job.deposit)
    math.randomseed(os.time() + playerId)
    local pickup = availablePickups[math.random(#availablePickups)]
    local dropoff = availableDropoffs[math.random(#availableDropoffs)]
    local car = Config.Cars[math.random(#Config.Cars)]
    if not car or not car.model or not car.name then
        player.addMoney(Config.Job.deposit)
        return nil
    end
    return {
        playerId = playerId,
        pickup = pickup.coords,
        dropoff = dropoff.coords,
        pickupIndex = pickup.index,
        dropoffIndex = dropoff.index,
        carModel = car.model,
        carName = car.name,
        startTime = os.time(),
        timeLimit = Config.Job.timeLimit,
        deposit = Config.Job.deposit,
        vehicleSpawned = false,
        spawnAttempts = 0,
        vehicle = nil,
        vehiclePlate = nil
    }
end

function CalculateRewards(job, timeElapsed, damage)
    local baseReward = Config.Job.baseReward
    local bonus = 0
    local totalReward = baseReward
    if timeElapsed <= Config.Job.bonusTimeLimit then
        bonus = Config.Job.bonusReward
        totalReward = totalReward + bonus
    end
    if Config.Job.damageSettings.penaltyEnabled and damage > Config.Job.damageSettings.minDamageThreshold then
        local penalty = math.floor(baseReward * damage * Config.Job.damageSettings.penaltyMultiplier)
        local maxPenalty = baseReward * Config.Job.damageSettings.maxPenaltyPercent
        penalty = math.min(penalty, maxPenalty)
        totalReward = math.max(totalReward - penalty, baseReward * (1 - Config.Job.damageSettings.maxPenaltyPercent))
    end
    local maxReward = Config.Job.baseReward + Config.Job.bonusReward
    totalReward = math.min(totalReward, maxReward)
    return {
        base = baseReward,
        bonus = bonus,
        total = totalReward
    }
end

function CleanupJob(playerId, success, reward, bonus)
    local job = activeJobs[playerId]
    if not job then return end
    if job.vehicle and DoesEntityExist(job.vehicle) then
        SetEntityAsMissionEntity(job.vehicle, true, true)
        DeleteEntity(job.vehicle)
        Framework.Debug(string.format('Vehicle cleaned up for player %s', playerId), 'info')
    end
    if job.pickupIndex and occupiedLocations.pickup[job.pickupIndex] == playerId then
        occupiedLocations.pickup[job.pickupIndex] = nil
    end
    if job.dropoffIndex and occupiedLocations.dropoff[job.dropoffIndex] == playerId then
        occupiedLocations.dropoff[job.dropoffIndex] = nil
    end
    activeJobs[playerId] = nil
    TriggerClientEvent('anox-cardelivery:client:endJob', playerId, success, reward or 0, bonus or 0)
end

function GetAvailableLocations(locationType)
    local available = {}
    local locations = Config.Locations[locationType == 'pickup' and 'Pickup' or 'Dropoff']
    if not locations or type(locations) ~= 'table' then
        return available
    end
    for i, coords in ipairs(locations) do
        if coords and coords.x and coords.y and coords.z and not occupiedLocations[locationType][i] then
            table.insert(available, {
                index = i,
                coords = coords
            })
        end
    end
    return available
end

function GetActiveJobCount()
    local count = 0
    for _ in pairs(activeJobs) do
        count = count + 1
    end
    return count
end

function CheckActionCooldown(playerId, action, seconds)
    local key = playerId .. '_' .. action
    local currentTime = os.time()
    if playerActionCooldowns[key] and (currentTime - playerActionCooldowns[key]) < seconds then
        return false
    end
    playerActionCooldowns[key] = currentTime
    return true
end

function ClearPlayerCooldowns(playerId)
    for _, action in ipairs({'request', 'spawn', 'spawn_confirm', 'complete', 'fail'}) do
        playerActionCooldowns[playerId .. '_' .. action] = nil
    end
end

function SendNotification(playerId, title, message, type)
    Framework.Notify(playerId, title, message, type)
end

Citizen.CreateThread(function()
    while not Framework do
        Citizen.Wait(100)
    end
    Framework.Debug('Server initialization complete', 'success')
    if not Config then
        Framework.Debug('Config not found!', 'error')
        return
    end
    if Config.Job.maxActiveJobs then
        Framework.Debug(string.format('Max active jobs set to: %d', Config.Job.maxActiveJobs), 'info')
    end
    local oxLibAvailable = GetResourceState('ox_lib') == 'started'
    if Config.UISystem.Notify == 'ox' and not oxLibAvailable then
        Framework.Debug('ox_lib not found but configured for notifications!', 'warning')
        Framework.Debug('Consider installing ox_lib or changing Config.UISystem.Notify to "native"', 'info')
    else
        Framework.Debug('Notification system ready: ' .. Config.UISystem.Notify, 'success')
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(60000) -- Every minute
        local currentTime = os.time()
        for key, time in pairs(playerActionCooldowns) do
            if currentTime - time > 300 then -- 5 minutes old
                playerActionCooldowns[key] = nil
            end
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5000) -- Every 5 seconds
        local currentTime = os.time()
        local playersToTimeout = {}
        for playerId, job in pairs(activeJobs) do
            local player = Framework.GetPlayer(playerId)
            if not player then
                table.insert(playersToTimeout, playerId)
            else
                local startTime = job.actualStartTime or job.startTime
                if (currentTime - startTime) > job.timeLimit then
                    table.insert(playersToTimeout, playerId)
                end
            end
        end
        for _, playerId in ipairs(playersToTimeout) do
            if activeJobs[playerId] then
                Framework.Debug(string.format('Job timed out for player %s', playerId), 'warning')
                local job = activeJobs[playerId]
                if job.vehicle and DoesEntityExist(job.vehicle) then
                    DeleteEntity(job.vehicle)
                end
                CleanupJob(playerId, false, 0, 0)
            end
        end
    end
end)