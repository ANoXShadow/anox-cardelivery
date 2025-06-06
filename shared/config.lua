--[[------------------------>FOR ASSISTANCE,SCRIPTS AND MORE JOIN OUR DISCORD<-------------------------------------
 ________   ________    ________      ___    ___      ________   _________   ___  ___   ________   ___   ________     
|\   __  \ |\   ___  \ |\   __  \    |\  \  /  /|  ||  |\   ____\ |\___   ___\|\  \|\  \ |\   ___ \ |\  \ |\   __  \    
\ \  \|\  \\ \  \\ \  \\ \  \|\  \   \ \  \/  / /  ||  \ \  \___|_\|___ \  \_|\ \  \\\  \\ \  \_|\ \\ \  \\ \  \|\  \   
 \ \   __  \\ \  \\ \  \\ \  \\\  \   \ \    / /   ||   \ \_____  \    \ \  \  \ \  \\\  \\ \  \ \\ \\ \  \\ \  \\\  \  
  \ \  \ \  \\ \  \\ \  \\ \  \\\  \   /     \/    ||    \|____|\  \    \ \  \  \ \  \\\  \\ \  \_\\ \\ \  \\ \  \\\  \ 
   \ \__\ \__\\ \__\\ \__\\ \_______\ /  /\   \    ||      ____\_\  \    \ \__\  \ \_______\\ \_______\\ \__\\ \_______\
    \|__|\|__| \|__| \|__| \|_______|/__/ /\ __\   ||     |\_________\    \|__|   \|_______| \|_______| \|__| \|_______|
                                     |__|/ \|__|   ||     \|_________|                                                 
------------------------------------->(https://discord.gg/gbJ5SyBJBv)---------------------------------------------------]]
Config = {}
Config.Debug = true -- Enable debug logs
Config.Framework = 'qbx' -- 'esx', 'qb', 'qbx'
Config.Language = 'en' -- 'en'
Config.Target = 'ox' -- 'ox', 'qb'
Config.Fuel = 'none' -- 'legacy' or 'none'
Config.Keys = 'none' -- 'qb' or 'none(make sure its for qbx)'
Config.UISystem = {
    Notify = 'ox',        -- 'ox'
    TextUI = 'ox',        -- 'ox'
    ProgressBar = 'ox',   -- 'ox'
    AlertDialog = 'ox',   -- 'ox'
    Menu = 'ox'           -- 'ox'
}

Config.Job = {
    deposit = 500,           -- Security deposit required
    baseReward = 1000,       -- Base reward for delivery
    bonusReward = 250,       -- Bonus for fast delivery
    timeLimit = 300,         -- Time limit in seconds (5 minutes)
    bonusTimeLimit = 150,    -- Time for bonus reward (2.5 minutes)
    cooldown = 100,          -- Cooldown in seconds
    maxActiveJobs = 10,      -- Maximum concurrent jobs on server
    damageSettings = {
        penaltyEnabled = true,           -- Enable/disable damage penalties
        penaltyMultiplier = 0.5,         -- Multiplier for damage penalty (0.5 = 50% of base reward maximum)
        minDamageThreshold = 0.1,        -- Minimum damage (10%) before penalties apply
        maxPenaltyPercent = 0.5,         -- Maximum penalty as percentage of base reward (0.5 = 50%)
        visualDamageWarning = 0.1,       -- Damage percentage to show warning in UI (10%)
    }
}

Config.Vehicles = {
    defaultFuel = 100,
    spawnHeight = 0.5,
    maxSpeed = 100.0,
    lockDoors = false,
    engineOn = true,
    dirtLevel = 15.0,
    teleportPlayer = true,
    exitMonitoring = {
        enabled = true,                 -- Enable/disable vehicle exit monitoring
        gracePeriod = 30000,            -- Grace period in milliseconds (30 seconds)
        warningEnabled = true,          -- Show warning when player exits vehicle
        warningDuration = 3000,         -- Warning notification duration
        checkInterval = 1000,           -- How often to check if player is in vehicle (ms)
        autoFailEnabled = true,         -- Automatically fail job if player abandons vehicle
    },
    spawnValidation = {
        maxDistance = 5.0,
        antiSpamInterval = 2000,
        modelLoadTimeout = 5000,
    }
}

Config.Cars = {
    -- ListA Cars
    { model = "asea", name = "Asea" },
    { model = "blista", name = "Blista" },
    { model = "futo", name = "Futo" },
    { model = "penumbra", name = "Penumbra" },
    { model = "sultan", name = "Sultan" },
    { model = "sentinel", name = "Sentinel" },
    -- ListB Bikes
    { model = "bati", name = "Bati 801" },
    { model = "akuma", name = "Akuma" },
    { model = "manchez", name = "Manchez" },
    { model = "double", name = "Double T" },
    { model = "vader", name = "Vader" },
    { model = "nemesis", name = "Nemesis" },
    -- ListC Luxury Cars
    { model = "turismor", name = "Turismo R" },
    { model = "osiris", name = "Osiris" },
    { model = "reaper", name = "Reaper" },
    { model = "seven70", name = "Seven-70" },
    { model = "xa21", name = "XA-21" },
    { model = "ztype", name = "Z-Type" }
}

Config.NPC = {
    model = 'a_m_m_business_01',
    coords = vector4(-248.96, -964.27, 31.22, 246.40),
    scenario = 'WORLD_HUMAN_CLIPBOARD',
    invincible = true,
    frozen = true,
    blockEvents = true,
    blip = {
        enabled = true,
        sprite = 280,
        display = 4,
        scale = 0.8,
        color = 5,
        shortRange = true
    },
    target = {
        distance = 2.5,
        icon = 'fas fa-car'
    }
}

Config.Blips = {
    pickup = {
        sprite = 225,
        display = 4,
        scale = 1.0,
        color = 3,
        shortRange = false,
        route = true,
        flash = false
    },
    dropoff = {
        sprite = 38,
        display = 4,
        scale = 1.2,
        color = 2,
        shortRange = false,
        route = true,
        flash = false
    }
}

Config.Locations = {
    Pickup = {
        vector4(-555.24, 665.26, 145.05, 343.24),
        vector4(97.74, 566.88, 182.36, 0.20),
        vector4(-1323.48, 449.72, 99.76, 6.36),
        vector4(-1041.29, 796.04, 167.35, 186.57),
        vector4(217.58, 756.72, 204.68, 37.77)
    },
    Dropoff = {
        vector4(235.90, -739.03, 30.82, 257.08),
        vector4(-286.49, -921.03, 31.08, 253.07),
        vector4(-2298.75, 431.74, 174.47, 357.15),
        vector4(963.14, -198.67, 73.05, 144.37),
        vector4(167.11, -2021.83, 18.20, 354.01)
    }
}

Config.AntiExploit = {
    teleportDetection = {
        enabled = true,
        minimumDistancePercent = 0.8,
    },
    minCompletionTime = 30,
    maxSpawnAttempts = 3,
    actionCooldowns = {
        request = 2,
        spawn = 2,
        complete = 2,
        fail = 2
    }
}

Config.CarPlate = {
    platePrefix = 'ANOX',
    plateDigits = 4,
}
