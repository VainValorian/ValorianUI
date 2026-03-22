-- ==========================================
-- VALORIAN UI: MASTER ENGINE & NAMESPACE
-- ==========================================
local addonName, ns = ...

-- ==========================================
-- 1. ENGINE & REGISTRY INITIALIZATION
-- ==========================================
ns.Engine = CreateFrame("Frame", "ValorianUIEngine", UIParent)
ns.Modules = {}
ns.db = {}

-- ==========================================
-- 2. DEFAULT CONFIGURATION MATRIX
-- ==========================================
local defaultSettings = {
    showActionBars = true,
    showExtraActionBars = true,
    showChatDamage = true,
    showAngels = true,
    showSuccubus = true,
    minimapAngle = 45,
    trackerClassColor = false,
    trackerColor = { r = 0.8, g = 0.2, b = 0.2 },
    showPlayerFrame = true,
    showTargetFrames = true,
    showFocusFrames = true,
    showPartyFrames = true,
    showRaidFrames = true,
    showBossFrames = true,
    showPetFrame = true,
    showArenaFrames = true,
    showInfoBar = true,
    enableUFSkinning = true,
    enableDMSkinning = true,
    enableSBSkinning = true,
    enableActionBarsSkinning = true,
    enableAurasSkinning = true,
    showOrbText = true,
    fontChoice = "Friz Quadrata TT",
    meterBarTexture = "Minimalist",
    meterBorderTexture = "Blizzard Tooltip",
    meterBorderOffset = 2,
    meterAutoResetOpenWorld = true,
    statusBarTexture = "Minimalist",
    statusBorderTexture = "Blizzard Tooltip",
    statusBorderOffset = 2,
    statusWidth = 580,
    statusHeight = 14,
    ufHealthTexture = "Minimalist",
    ufPowerTexture = "Minimalist",
    ufCastbarTexture = "Minimalist",
    Runes_X = 0,
    Runes_Y = 120,
    frames = {
        ValorianUIChatArt = { point = "BOTTOMLEFT", x = 0, y = 0, scale = 1 },
        ValorianUIDamageArt = { point = "BOTTOMRIGHT", x = 0, y = 0, scale = 1 },
        ValorianUISuccubusFrame = { point = "TOPLEFT", x = -92, y = 100, scale = 1 },
        ValorianUIHealthOrb = { point = "CENTER", x = -300, y = 150, scale = 1 },
        ValorianUIPowerOrb = { point = "CENTER", x = 300, y = 150, scale = 1 },
        ValorianUI_InfoBar = { point = "TOPLEFT", relativePoint = "TOPLEFT", xOfs = 16, yOfs = -10, scale = 1 }
    }
}

-- ==========================================
-- 3. RECURSIVE DATABASE MERGE
-- ==========================================
local function CopyDefaults(src, dst)
    if type(src) ~= "table" then return {} end
    if type(dst) ~= "table" then dst = {} end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = CopyDefaults(v, dst[k])
        elseif type(v) ~= type(dst[k]) then
            dst[k] = v
        end
    end
    return dst
end

-- ==========================================
-- 4. MODULE FACTORY API
-- ==========================================
function ns.Engine:NewModule(name)
    if ns.Modules[name] then return ns.Modules[name] end
    local module = {}
    module.name = name
    ns.Modules[name] = module
    return module
end

-- ==========================================
-- 5. MASTER EVENT ROUTING
-- ==========================================
ns.Engine:RegisterEvent("ADDON_LOADED")
ns.Engine:RegisterEvent("PLAYER_ENTERING_WORLD")
ns.Engine:RegisterEvent("PLAYER_LOGOUT")

ns.Engine:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            ValorianUIDB = ValorianUIDB or {}

            if type(ValorianUIDB.global) ~= "table" then
                local legacyData = {}
                for k, v in pairs(ValorianUIDB) do
                    legacyData[k] = v
                    ValorianUIDB[k] = nil
                end
                ValorianUIDB.global = legacyData
            end

            ValorianUIDB.global = ValorianUIDB.global or {}
            ValorianUIDB.profiles = ValorianUIDB.profiles or {}
            ValorianUIDB.useProfile = ValorianUIDB.useProfile or {}

            ns.charKey = UnitName("player") .. " - " .. GetRealmName()

            if ValorianUIDB.useProfile[ns.charKey] then
                ValorianUIDB.profiles[ns.charKey] = ValorianUIDB.profiles[ns.charKey] or {}
                ns.db = CopyDefaults(defaultSettings, ValorianUIDB.profiles[ns.charKey])
                ns.dbType = "profile"
            else
                ns.db = CopyDefaults(defaultSettings, ValorianUIDB.global)
                ns.dbType = "global"
            end

            for _, module in pairs(ns.Modules) do
                if type(module.OnInit) == "function" then
                    module:OnInit()
                end
            end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        local isInitialLogin, isReloadingUI = ...

        for _, module in pairs(ns.Modules) do
            if type(module.OnEnable) == "function" then
                module:OnEnable(isInitialLogin, isReloadingUI)
            end
        end
    elseif event == "PLAYER_LOGOUT" then
        if ns.dbType == "profile" then
            ValorianUIDB.profiles[ns.charKey] = CopyDefaults(ns.db, ValorianUIDB.profiles[ns.charKey] or {})
        else
            ValorianUIDB.global = CopyDefaults(ns.db, ValorianUIDB.global or {})
        end
    end
end)
