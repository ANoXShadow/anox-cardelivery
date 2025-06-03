local Bridge = {}
Bridge.__index = Bridge
local isClient = IsDuplicityVersion() == false
local isServer = not isClient

function Bridge.Debug(msg, level)
    if not Config or not Config.Debug then return end
    local prefix = '^3[anox-cardelivery]^7'
    local levelColors = {
        info = '^7',
        success = '^2',
        warning = '^3',
        error = '^1'
    }
    local color = levelColors[level] or '^7'
    print(prefix .. ' ' .. color .. msg .. '^7')
end

local UIPresets = {
    notify = {
        default = {
            backgroundColor = '#1E1E2F',
            color = '#A0A0FF',
            position = 'center-right',
            duration = 6000,
            icon = 'bell'
        },
        error = {
            backgroundColor = '#2F1E1E',
            color = '#FF5C5C',
            position = 'center-right',
            duration = 6000,
            icon = 'circle-exclamation'
        },
        success = {
            backgroundColor = '#1E2F1E',
            color = '#6CFF7F',
            position = 'center-right',
            duration = 6000,
            icon = 'circle-check'
        },
        info = {
            backgroundColor = '#1E1E2F',
            color = '#58C5FF',
            position = 'center-right',
            duration = 6000,
            icon = 'circle-info'
        },
        warning = {
            backgroundColor = '#2F2A1E',
            color = '#FFD966',
            position = 'center-right',
            duration = 6000,
            icon = 'triangle-exclamation'
        }
    },
    textUI = {
        default = {
            backgroundColor = '#1E1E2F',
            position = 'top-center',
            icon = 'info-circle',
            iconColor = '#A0A0FF'
        },
        pickup = {
            backgroundColor = '#112F1E',
            position = 'top-center',
            icon = 'box-open',
            iconColor = '#6CFF7F'
        },
        dropoff = {
            backgroundColor = '#2A1E2F',
            position = 'right-center',
            icon = 'dolly',
            iconColor = '#FF8AE2'
        },
        timer = {
            backgroundColor = '#1E1E2F',
            position = 'top-center',
            icon = 'stopwatch',
            iconColor = '#FFCC70'
        }
    }
}

function Bridge.Notify(source, title, description, type, duration)
    local success, err = pcall(function()
        local notifyType = type or 'info'
        local notifyStyle = UIPresets.notify[notifyType] or UIPresets.notify.default
        local msgTitle = title or 'Notification'
        local msgDesc = tostring(description or '')
        local notifyDuration = duration or notifyStyle.duration or 6000
        local style = {
            backgroundColor = notifyStyle.backgroundColor or '#000000',
            color = notifyStyle.color or '#FFD700',
            borderRadius = 14,
            fontSize = '16px',
            fontWeight = 'bold',
            textAlign = 'left',
            padding = '14px 20px',
            border = '1px solid ' .. (notifyStyle.color or '#FFD700'),
            letterSpacing = '0.5px'
        }
        if not source then
            style.boxShadow = '0 0 12px rgba(96, 165, 250, 0.4)'
        end
        if Config.UISystem.Notify == 'ox' then
            local notifyData = {
                title = msgTitle,
                description = msgDesc,
                type = notifyType,
                icon = notifyStyle.icon,
                style = style,
                position = notifyStyle.position or 'top-right',
                duration = notifyDuration
            }
            if source then
                TriggerClientEvent('ox_lib:notify', source, notifyData)
            else
                lib.notify(notifyData)
            end
        else
            if isClient and not source then
                BeginTextCommandThefeedPost('STRING')
                AddTextComponentSubstringPlayerName(msgTitle .. '\n' .. msgDesc)
                EndTextCommandThefeedPostTicker(false, false)
            else
                Bridge.Debug('NOTIFY: ' .. msgTitle .. ' - ' .. msgDesc, 'info')
            end
        end
    end)
    if not success then
        Bridge.Debug('Error in Bridge.Notify: ' .. tostring(err), 'error')
    end
end

function Bridge.ShowTextUI(text, options)
    if not isClient then return end
    local success, err = pcall(function()
        options = options or {}
        local styleKey = options.style or 'default'
        local textUIStyle = UIPresets.textUI[styleKey] or UIPresets.textUI.default
        if Config.UISystem.TextUI == 'ox' then
            lib.showTextUI(text, {
                position = textUIStyle.position or 'top-center',
                icon = textUIStyle.icon,
                iconColor = textUIStyle.iconColor or '#ffffff',
                style = {
                    backgroundColor = textUIStyle.backgroundColor or '#000000',
                    color = textUIStyle.iconColor or '#ffffff',
                    borderRadius = 6,
                    border = '1px solid ' .. (textUIStyle.iconColor or '#ffffff'),
                    fontSize = '15px',
                    fontWeight = '600',
                    padding = '6px 12px',
                    letterSpacing = '0.5px',
                }
            })
        else
            Bridge.Debug('TextUI: ' .. text, 'info')
        end
    end)
    if not success then
        Bridge.Debug('Error in Bridge.ShowTextUI: ' .. tostring(err), 'error')
    end
end

function Bridge.HideTextUI()
    if not isClient then return end
    local success, err = pcall(function()
        if Config.UISystem.TextUI == 'ox' then
            lib.hideTextUI()
        end
    end)
    if not success then
        Bridge.Debug('Error in Bridge.HideTextUI: ' .. tostring(err), 'error')
    end
end

function Bridge.AlertDialog(options)
    if not isClient then return 'confirm' end
    local success, result = pcall(function()
        options = options or {}
        if Config.UISystem.AlertDialog == 'ox' then
            return lib.alertDialog({
                header = options.header or 'Alert',
                content = options.content or '',
                centered = options.centered ~= nil and options.centered or true,
                cancel = options.cancel ~= nil and options.cancel or true,
                labels = options.labels or {
                    confirm = 'Confirm',
                    cancel = 'Cancel'
                }
            })
        else
            return 'confirm'
        end
    end)
    if not success then
        Bridge.Debug('Error in Bridge.AlertDialog: ' .. tostring(result), 'error')
    end
    return result or 'confirm'
end

Bridge.Target = {
    AddLocalEntity = function(entity, options)
        if not isClient then return end
        local success, err = pcall(function()
            if Config.Target == 'ox' then
                exports['ox_target']:addLocalEntity(entity, options)
            elseif Config.Target == 'qb' then
                local qbOptions = {}
                for _, opt in ipairs(options) do
                    table.insert(qbOptions, {
                        type = opt.type or 'client',
                        event = opt.event,
                        icon = opt.icon,
                        label = opt.label,
                        canInteract = opt.canInteract,
                        job = opt.job,
                        action = opt.onSelect and function()
                            opt.onSelect()
                        end
                    })
                end
                exports['qb-target']:AddTargetEntity(entity, {
                    options = qbOptions,
                    distance = 2.5
                })
            else
                Bridge.Debug('Target system not supported: ' .. tostring(Config.Target), 'warning')
            end
        end)
        if not success then
            Bridge.Debug('Error in Bridge.Target.AddLocalEntity: ' .. tostring(err), 'error')
        end
    end,
    RemoveLocalEntity = function(entity, names)
        if not isClient then return end
        local success, err = pcall(function()
            if Config.Target == 'ox' then
                exports['ox_target']:removeLocalEntity(entity, names)
            elseif Config.Target == 'qb' then
                exports['qb-target']:RemoveTargetEntity(entity, names)
            end
        end)
        if not success then
            Bridge.Debug('Error in Bridge.Target.RemoveLocalEntity: ' .. tostring(err), 'error')
        end
    end
}

Bridge.SetFuel = function(vehicle, amount)
    if not isClient or not vehicle or vehicle == 0 then return end
    local fuelSystem = Config.Fuel or 'none'
    pcall(function()
        if fuelSystem == 'legacy' then
            exports['LegacyFuel']:SetFuel(vehicle, amount or 100.0)
        else
            SetVehicleFuelLevel(vehicle, amount or 100.0)
        end
    end)
end

Bridge.SetVehicleKeys = function(vehicle, plate)
    if not isClient then return end
    local keysSystem = Config.Keys or 'none'
    local vehPlate = plate or (vehicle and GetVehicleNumberPlateText(vehicle))
    if not vehPlate then return end
    pcall(function()
        if keysSystem == 'qb' then
            TriggerEvent('vehiclekeys:client:SetOwner', vehPlate)
        elseif vehicle and DoesEntityExist(vehicle) then
            SetVehicleDoorsLocked(vehicle, 1)
            SetVehicleHasBeenOwnedByPlayer(vehicle, true)
        end
    end)
end

function Bridge.Load()
    if not Config then
        Bridge.Debug('Config not found', 'error')
        return nil
    end
    local framework = nil
    local frameworkMap = {
        ['esx'] = 'esx',
        ['qb'] = 'qb',
        ['qbx'] = 'qbx'
    }
    if Config.Framework and Config.Framework ~= 'auto' and Config.Framework ~= 'autodetect' then
        framework = frameworkMap[string.lower(Config.Framework)]
        if not framework then
            Bridge.Debug('Unknown framework specified: ' .. Config.Framework, 'error')
            return nil
        end
    else
        if GetResourceState('es_extended') == 'started' then
            framework = 'esx'
        elseif GetResourceState('qb-core') == 'started' then
            framework = 'qb'
        elseif GetResourceState('qbx_core') == 'started' then
            framework = 'qbx'
        else
            Bridge.Debug('No supported framework detected', 'error')
            return nil
        end
    end
    local context = isClient and 'client' or 'server'
    local bridgePath = ('bridge/%s/%s'):format(context, framework)
    local success, frameworkBridge = pcall(require, bridgePath)
    if not success or not frameworkBridge then
        Bridge.Debug('Failed to load bridge module: ' .. bridgePath, 'error')
        return nil
    end
    if frameworkBridge.Init and type(frameworkBridge.Init) == 'function' then
        if not frameworkBridge:Init() then
            Bridge.Debug('Failed to initialize ' .. framework .. ' bridge', 'error')
            return nil
        end
        Bridge.Debug('Successfully initialized ' .. framework .. ' bridge', 'success')
        if frameworkBridge.RegisterEvents and type(frameworkBridge.RegisterEvents) == 'function' then
            frameworkBridge:RegisterEvents()
        end
    else
        Bridge.Debug('Loaded ' .. framework .. ' bridge', 'success')
    end
    return setmetatable({
        Notify = Bridge.Notify,
        ShowTextUI = Bridge.ShowTextUI,
        HideTextUI = Bridge.HideTextUI,
        AlertDialog = Bridge.AlertDialog,
        Target = Bridge.Target,
        Debug = Bridge.Debug,
        SetFuel = Bridge.SetFuel,
        SetVehicleKeys = Bridge.SetVehicleKeys
    }, {
        __index = function(t, k)
            return frameworkBridge[k] or Bridge[k]
        end
    })
end

return Bridge