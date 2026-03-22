-- ==========================================
-- VALORIAN UI: THE ORB ENGINE
-- ==========================================
local _, ns = ...
local Orbs = ns.Engine:NewModule("Orbs")

-- ==========================================
-- 1. CONFIGURATION & MEDIA
-- ==========================================
local PATH_FILL = "Interface\\AddOns\\ValorianUI\\Media\\TempOrbFill.tga"
local PATH_FLAT = "Interface\\Buttons\\WHITE8x8"
local PATH_GLOSS = "Interface\\AddOns\\ValorianUI\\Media\\OrbGlass.tga"
local PATH_ANGEL_HEALTH = "Interface\\AddOns\\ValorianUI\\Media\\HealthOrb.tga"
local PATH_ANGEL_POWER = "Interface\\AddOns\\ValorianUI\\Media\\PowerOrb.tga"
local NATIVE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local ORB_SIZE = 155

local ValorianPowerColors = {
    ["MANA"]        = { 0.00, 0.50, 1.00 },
    ["RAGE"]        = { 1.00, 0.00, 0.00 },
    ["FOCUS"]       = { 1.00, 0.50, 0.25 },
    ["ENERGY"]      = { 1.00, 1.00, 0.00 },
    ["RUNIC_POWER"] = { 0.00, 0.82, 1.00 },
    ["LUNAR_POWER"] = { 0.30, 0.52, 0.90 },
    ["MAELSTROM"]   = { 0.00, 0.50, 1.00 },
    ["INSANITY"]    = { 0.40, 0.00, 0.80 },
    ["FURY"]        = { 0.79, 0.26, 0.99 },
    ["PAIN"]        = { 1.00, 0.61, 0.00 },
}

local HealthOrb, PowerOrb
local MicroContainer
local micros = {}
local activeType = nil
local activeMax = 0
local activeAuraID = nil

local MICRO_SIZE = 34
local MICRO_SPACING = 8
local MAX_MICROS = 10

local GetTime = GetTime
local GetRuneCooldown = GetRuneCooldown

local RuneUpdater = CreateFrame("Frame")
RuneUpdater:Hide()

-- ==========================================
-- 2. ORB FORGE (FACTORY FUNCTION)
-- ==========================================
local function CreateOrb(name, defaultX, defaultY, r, g, b, angelPath, angelOffsetX, angelOffsetY, isHealthOrb)
    local orb

    if isHealthOrb then
        orb = CreateFrame("Button", name, UIParent, "SecureUnitButtonTemplate")
        orb:RegisterForClicks("AnyUp")
        orb:SetAttribute("unit", "player")
        orb:SetAttribute("type1", "target")
        orb:SetAttribute("type2", "togglemenu")
        orb:SetAttribute("togglemenu", "player")
    else
        orb = CreateFrame("Frame", name, UIParent)
    end

    orb:SetSize(ORB_SIZE, ORB_SIZE)

    local db = ns.db.frames[name]
    if db then
        orb:SetPoint(db.point or "CENTER", UIParent, db.relativePoint or "BOTTOM", db.x or defaultX, db.y or defaultY)
        if db.scale then orb:SetScale(db.scale) end
    else
        orb:SetPoint("CENTER", UIParent, "BOTTOM", defaultX, defaultY)
    end

    orb.bg = orb:CreateTexture(nil, "BACKGROUND", nil, -1)
    orb.bg:SetAllPoints()
    orb.bg:SetTexture(PATH_FLAT)
    orb.bg:SetVertexColor(0.05, 0.05, 0.05, 0.85)

    orb.fill = CreateFrame("StatusBar", nil, orb)
    orb.fill:SetOrientation("VERTICAL")
    orb.fill:SetAllPoints()
    orb.fill:SetStatusBarTexture(PATH_FILL)
    orb.fill:SetStatusBarColor(r, g, b, 1)
    orb.fill:SetMinMaxValues(0, 1)
    orb.fill:SetValue(0)

    orb.spark = orb.fill:CreateTexture(nil, "OVERLAY")
    orb.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    orb.spark:SetBlendMode("ADD")
    orb.spark:SetAlpha(0.25)
    orb.spark:SetSize(ORB_SIZE + 10, 10)
    orb.spark:SetPoint("CENTER", orb.fill:GetStatusBarTexture(), "TOP", 0, 0)

    if isHealthOrb then
        orb.healFill = CreateFrame("StatusBar", nil, orb)
        orb.healFill:SetOrientation("VERTICAL")
        orb.healFill:SetSize(ORB_SIZE, ORB_SIZE)
        orb.healFill:SetPoint("BOTTOM", orb.fill:GetStatusBarTexture(), "TOP", 0, 0)
        orb.healFill:SetPoint("LEFT", orb.fill, "LEFT")
        orb.healFill:SetPoint("RIGHT", orb.fill, "RIGHT")
        orb.healFill:SetStatusBarTexture(PATH_FLAT)
        orb.healFill:SetStatusBarColor(0.2, 0.8, 0.2, 0.75)
        orb.healFill:SetMinMaxValues(0, 1)
        orb.healFill:SetValue(0)

        orb.absorbFill = CreateFrame("StatusBar", nil, orb)
        orb.absorbFill:SetOrientation("VERTICAL")
        orb.absorbFill:SetSize(ORB_SIZE, ORB_SIZE)
        orb.absorbFill:SetPoint("BOTTOM", orb.healFill:GetStatusBarTexture(), "TOP", 0, 0)
        orb.absorbFill:SetPoint("LEFT", orb.fill, "LEFT")
        orb.absorbFill:SetPoint("RIGHT", orb.fill, "RIGHT")
        orb.absorbFill:SetStatusBarTexture(PATH_FLAT)
        orb.absorbFill:SetStatusBarColor(0.0, 0.8, 1.0, 0.75)
        orb.absorbFill:SetMinMaxValues(0, 1)
        orb.absorbFill:SetValue(0)
    end

    local INSET = 3
    orb.mask = orb:CreateMaskTexture()
    orb.mask:SetSize(ORB_SIZE - (INSET * 2), ORB_SIZE - (INSET * 2))
    orb.mask:SetPoint("CENTER", orb, "CENTER", 0, -1)
    orb.mask:SetTexture(NATIVE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

    orb.bg:AddMaskTexture(orb.mask)
    orb.fill:GetStatusBarTexture():AddMaskTexture(orb.mask)
    orb.spark:AddMaskTexture(orb.mask)

    if isHealthOrb then
        orb.healFill:GetStatusBarTexture():AddMaskTexture(orb.mask)
        orb.absorbFill:GetStatusBarTexture():AddMaskTexture(orb.mask)
    end

    orb.overlay = CreateFrame("Frame", nil, orb)
    orb.overlay:SetAllPoints()
    orb.overlay:SetFrameLevel(orb:GetFrameLevel() + 5)

    orb.gloss = orb.overlay:CreateTexture(nil, "OVERLAY", nil, 1)
    orb.gloss:SetAllPoints(orb.overlay)
    orb.gloss:SetTexture(PATH_GLOSS)

    orb.text = orb.overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    orb.text:SetPoint("CENTER", orb.overlay, "CENTER", 0, 0)
    orb.text:SetFont(orb.text:GetFont(), 20, "OUTLINE")
    orb.text:SetDrawLayer("OVERLAY", 7)
    orb.text:SetTextColor(1, 1, 1, 1)

    orb.angel = orb.overlay:CreateTexture(nil, "OVERLAY", nil, 5)
    orb.angel:SetSize(ORB_SIZE * 1.6, ORB_SIZE * 1.6)
    orb.angel:SetPoint("CENTER", orb.overlay, "CENTER", angelOffsetX, angelOffsetY)
    orb.angel:SetTexture(angelPath)

    orb.angelGlow = orb.overlay:CreateTexture(nil, "OVERLAY", nil, 6)
    orb.angelGlow:SetSize(ORB_SIZE * 1.6, ORB_SIZE * 1.6)
    orb.angelGlow:SetPoint("CENTER", orb.overlay, "CENTER", angelOffsetX, angelOffsetY)
    orb.angelGlow:SetTexture(angelPath)
    orb.angelGlow:SetBlendMode("ADD")
    orb.angelGlow:SetVertexColor(0.4, 0.0, 0.0)
    orb.angelGlow:SetAlpha(0)

    orb.combatAnim = orb.angelGlow:CreateAnimationGroup()
    orb.combatAnim:SetLooping("REPEAT")
    local c1 = orb.combatAnim:CreateAnimation("Alpha")
    c1:SetFromAlpha(0)
    c1:SetToAlpha(0.65)
    c1:SetDuration(1.2)
    c1:SetOrder(1)
    local c2 = orb.combatAnim:CreateAnimation("Alpha")
    c2:SetFromAlpha(0.65)
    c2:SetToAlpha(0)
    c2:SetDuration(1.2)
    c2:SetOrder(2)

    if not ns.db.showAngels then
        orb.angel:Hide()
        orb.angelGlow:Hide()
    end

    orb.dragOverlay = orb.overlay:CreateTexture(nil, "OVERLAY", nil, 7)
    orb.dragOverlay:SetAllPoints()
    orb.dragOverlay:SetColorTexture(0, 1, 0, 0.4)
    orb.dragOverlay:Hide()

    orb:SetMovable(true)
    orb:RegisterForDrag("LeftButton")

    if isHealthOrb then
        orb:EnableMouse(true)
    else
        orb:EnableMouse(ValUI_FramesUnlocked or false)
    end

    if ValUI_FramesUnlocked then orb.dragOverlay:Show() end

    orb:SetScript("OnDragStart", function(self)
        if ValUI_FramesUnlocked then self:StartMoving() end
    end)

    orb:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, newX, newY = self:GetPoint()

        if not ns.db.frames[name] then ns.db.frames[name] = {} end
        ns.db.frames[name].point = point
        ns.db.frames[name].relativePoint = relativePoint or point
        ns.db.frames[name].x = newX
        ns.db.frames[name].y = newY
    end)

    return orb
end

-- ==========================================
-- 3. RESOURCE MATHEMATICS & UPDATES
-- ==========================================
local function UpdateHealth()
    if not UnitExists("player") or not HealthOrb then return end

    local health = UnitHealth("player") or 0
    local maxHealth = UnitHealthMax("player") or 1
    local incomingHeal = UnitGetIncomingHeals("player") or 0
    local absorb = UnitGetTotalAbsorbs("player") or 0

    if _G.StatusBar_SetMinMaxSmoothedValue then
        _G.StatusBar_SetMinMaxSmoothedValue(HealthOrb.fill, 0, maxHealth, health)
        _G.StatusBar_SetMinMaxSmoothedValue(HealthOrb.healFill, 0, maxHealth, incomingHeal)
        _G.StatusBar_SetMinMaxSmoothedValue(HealthOrb.absorbFill, 0, maxHealth, absorb)
    else
        HealthOrb.fill:SetMinMaxValues(0, maxHealth)
        HealthOrb.fill:SetValue(health)
        HealthOrb.healFill:SetMinMaxValues(0, maxHealth)
        HealthOrb.healFill:SetValue(incomingHeal)
        HealthOrb.absorbFill:SetMinMaxValues(0, maxHealth)
        HealthOrb.absorbFill:SetValue(absorb)
    end


    if ns.db.showOrbText == false then
        HealthOrb.text:Hide()
    else
        HealthOrb.text:Show()
        HealthOrb.text:SetText(health)
    end
end

local function UpdatePower()
    if not UnitExists("player") or not PowerOrb then return end

    local powerType, powerToken = UnitPowerType("player")
    local power = UnitPower("player", powerType) or 0
    local maxPower = UnitPowerMax("player", powerType) or 1

    if _G.StatusBar_SetMinMaxSmoothedValue then
        _G.StatusBar_SetMinMaxSmoothedValue(PowerOrb.fill, 0, maxPower, power)
    else
        PowerOrb.fill:SetMinMaxValues(0, maxPower)
        PowerOrb.fill:SetValue(power)
    end

    if ns.db.showOrbText == false then
        PowerOrb.text:Hide()
    else
        PowerOrb.text:Show()
        PowerOrb.text:SetText(power)
    end

    local color = ValorianPowerColors[powerToken] or { 0.0, 0.5, 1.0 }
    PowerOrb.fill:SetStatusBarColor(color[1], color[2], color[3], 1)
end

-- ==========================================
-- 4. MICRO-ORB ENGINE LOGIC
-- ==========================================
local function GetMaxPowerSafe(rType, fallback)
    local m = UnitPowerMax("player", rType)
    return (m and type(m) == "number" and m > 0) and m or fallback
end

local function GetResourceInfo()
    local _, class = UnitClass("player")
    local spec = GetSpecialization and GetSpecialization() or 1

    local rType = nil
    local maxCount = 0
    local color = { 1, 1, 1 }
    local auraID = nil

    if class == "DEATHKNIGHT" then
        rType = "RUNES"
        maxCount = 6
        if spec == 1 then
            color = { 1.0, 0.1, 0.1 }
        elseif spec == 2 then
            color = { 0.0, 0.82, 1.0 }
        elseif spec == 3 then
            color = { 0.2, 0.9, 0.2 }
        else
            color = { 0.8, 0.1, 0.1 }
        end
    elseif class == "ROGUE" then
        rType = 4
        maxCount = GetMaxPowerSafe(4, 5)
        color = { 1.0, 0.9, 0.1 }
    elseif class == "DRUID" and spec == 2 then
        rType = 4
        maxCount = GetMaxPowerSafe(4, 5)
        color = { 1.0, 0.9, 0.1 }
    elseif class == "PALADIN" then
        rType = 9
        maxCount = GetMaxPowerSafe(9, 5)
        color = { 1.0, 0.9, 0.4 }
    elseif class == "WARLOCK" then
        rType = 7
        maxCount = GetMaxPowerSafe(7, 5)
        color = { 0.7, 0.3, 0.9 }
    elseif class == "MAGE" and spec == 1 then
        rType = 16
        maxCount = GetMaxPowerSafe(16, 4)
        color = { 0.2, 0.6, 1.0 }
    elseif class == "MAGE" and spec == 3 then
        rType = "AURA"
        maxCount = 5
        color = { 0.2, 0.8, 1.0 }
        auraID = 205473
    elseif class == "SHAMAN" and spec == 2 then
        rType = "AURA"
        maxCount = 10
        color = { 0.0, 0.5, 1.0 }
        auraID = 344179
    elseif class == "MONK" and spec == 3 then
        rType = 12
        maxCount = GetMaxPowerSafe(12, 5)
        color = { 0.3, 1.0, 0.6 }
    elseif class == "EVOKER" then
        rType = 19
        maxCount = GetMaxPowerSafe(19, 6)
        color = { 0.4, 0.8, 0.9 }
    end

    if maxCount == nil or maxCount == 0 then rType = nil end
    return rType, maxCount, color, auraID
end

local function UpdateStandardPower()
    if not activeType or activeType == "RUNES" or activeType == "AURA" then return end
    local current = UnitPower("player", activeType)
    if type(current) ~= "number" then current = 0 end

    local isApex = (current == activeMax and activeMax > 0 and InCombatLockdown())

    for i = 1, MAX_MICROS do
        local r = micros[i]
        if i <= current and i <= activeMax then
            r.fill:SetHeight(MICRO_SIZE)
            r.fill:SetTexCoord(0, 1, 0, 1)
            r.fill:SetAlpha(1)

            if isApex then
                if not r.glowAnim:IsPlaying() then r.glowAnim:Play() end
            else
                r.glowAnim:Stop()
                r.apexGlow:SetAlpha(0)
            end
        else
            r.fill:SetHeight(0.1)
            r.fill:SetAlpha(0)
            r.glowAnim:Stop()
            r.apexGlow:SetAlpha(0)
        end
    end
end

local function UpdateAuraPower()
    if activeType ~= "AURA" or not activeAuraID then return end

    local current = 0
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(activeAuraID)
        if aura then
            current = (aura.applications and aura.applications > 0) and aura.applications or 1
        end
    end


    local isApex = (current == activeMax and activeMax > 0 and InCombatLockdown())

    for i = 1, MAX_MICROS do
        local r = micros[i]
        if i <= current and i <= activeMax then
            r.fill:SetHeight(MICRO_SIZE)
            r.fill:SetTexCoord(0, 1, 0, 1)
            r.fill:SetAlpha(1)

            if isApex then
                if not r.glowAnim:IsPlaying() then r.glowAnim:Play() end
            else
                r.glowAnim:Stop()
                r.apexGlow:SetAlpha(0)
            end
        else
            r.fill:SetHeight(0.1)
            r.fill:SetAlpha(0)
            r.glowAnim:Stop()
            r.apexGlow:SetAlpha(0)
        end
    end
end

local function RefreshMicroLayout()
    local rType, maxCount, color, auraID = GetResourceInfo()
    activeType = rType
    activeMax = maxCount
    activeAuraID = auraID

    if not activeType then
        MicroContainer:Hide()
        RuneUpdater:Hide()
        return
    end

    MicroContainer:Show()
    MicroContainer:SetWidth((MICRO_SIZE * maxCount) + (MICRO_SPACING * (maxCount - 1)))

    for i = 1, MAX_MICROS do
        local r = micros[i]
        if i <= maxCount then
            r:Show()
            r.fill:SetVertexColor(color[1], color[2], color[3], 1)
            r.apexGlow:SetVertexColor(color[1], color[2], color[3], 1)
        else
            r:Hide()
            r.glowAnim:Stop()
            r.apexGlow:SetAlpha(0)
        end
    end

    if activeType == "RUNES" then
        RuneUpdater:Show()
    elseif activeType == "AURA" then
        RuneUpdater:Hide()
        UpdateAuraPower()
    else
        RuneUpdater:Hide()
        UpdateStandardPower()
    end
end

RuneUpdater:SetScript("OnUpdate", function()
    local now = GetTime()

    local readyCount = 0
    for i = 1, activeMax do
        local start, _, runeReady = GetRuneCooldown(i)
        if not start or start == 0 or runeReady then
            readyCount = readyCount + 1
        end
    end
    local isApex = (readyCount == activeMax and activeMax > 0 and InCombatLockdown())

    for i = 1, activeMax do
        local start, duration, runeReady = GetRuneCooldown(i)
        local r = micros[i]

        if not start or start == 0 or runeReady then
            r.fill:SetHeight(MICRO_SIZE)
            r.fill:SetTexCoord(0, 1, 0, 1)
            r.fill:SetAlpha(1)
        else
            local percent = math.max(0, math.min(1, (now - start) / duration))
            r.fill:SetHeight(math.max(MICRO_SIZE * percent, 0.1))
            r.fill:SetTexCoord(0, 1, 1 - percent, 1)
            r.fill:SetAlpha(0.6)
        end

        if isApex then
            if not r.glowAnim:IsPlaying() then r.glowAnim:Play() end
        else
            r.glowAnim:Stop()
            r.apexGlow:SetAlpha(0)
        end
    end
end)

-- ==========================================
-- 5. INITIALIZATION & EVENTS
-- ==========================================
function Orbs:OnInit()
    HealthOrb = CreateOrb("ValorianUIHealthOrb", -300, 150, 0.8, 0.1, 0.1, PATH_ANGEL_HEALTH, -94, 25, true)
    PowerOrb = CreateOrb("ValorianUIPowerOrb", 300, 150, 0.1, 0.3, 0.8, PATH_ANGEL_POWER, 90, -3, false)

    HealthOrb:SetScript("OnEnter", function(orb)
        if ValUI_FramesUnlocked then return end
        GameTooltip_SetDefaultAnchor(GameTooltip, orb)
        GameTooltip:SetUnit("player")
        GameTooltip:Show()
    end)
    HealthOrb:SetScript("OnLeave", function() GameTooltip:Hide() end)

    MicroContainer = CreateFrame("Frame", "ValorianUIRunes", UIParent)
    MicroContainer:SetHeight(MICRO_SIZE)

    local rX = ns.db.Runes_X or 0
    local rY = ns.db.Runes_Y or 120
    MicroContainer:SetPoint("BOTTOM", UIParent, "BOTTOM", rX, rY)

    MicroContainer.dragOverlay = MicroContainer:CreateTexture(nil, "OVERLAY")
    MicroContainer.dragOverlay:SetAllPoints()
    MicroContainer.dragOverlay:SetColorTexture(0, 1, 0, 0.4)
    MicroContainer.dragOverlay:Hide()

    MicroContainer:SetMovable(true)
    MicroContainer:EnableMouse(ValUI_FramesUnlocked or false)
    if ValUI_FramesUnlocked then MicroContainer.dragOverlay:Show() end
    MicroContainer:RegisterForDrag("LeftButton")

    MicroContainer:SetScript("OnDragStart", function(mc) mc:StartMoving() end)
    MicroContainer:SetScript("OnDragStop", function(mc)
        mc:StopMovingOrSizing()
        local centerX = mc:GetCenter()
        local parentX = UIParent:GetCenter()
        ns.db.Runes_X = centerX - parentX
        ns.db.Runes_Y = mc:GetBottom()
        mc:ClearAllPoints()
        mc:SetPoint("BOTTOM", UIParent, "BOTTOM", ns.db.Runes_X, ns.db.Runes_Y)
    end)


    for i = 1, MAX_MICROS do
        local r = CreateFrame("Frame", "ValorianUIMicro" .. i, MicroContainer)
        r:SetSize(MICRO_SIZE, MICRO_SIZE)
        r:SetPoint("LEFT", MicroContainer, "LEFT", (i - 1) * (MICRO_SIZE + MICRO_SPACING), 0)

        local INSET = 1
        r.mask = r:CreateMaskTexture()
        r.mask:SetSize(MICRO_SIZE - (INSET * 2), MICRO_SIZE - (INSET * 2))
        r.mask:SetPoint("CENTER", r, "CENTER", 0, 0)
        r.mask:SetTexture(NATIVE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

        r.bg = r:CreateTexture(nil, "BACKGROUND")
        r.bg:SetAllPoints()
        r.bg:SetTexture(PATH_FLAT)
        r.bg:SetVertexColor(0.05, 0.05, 0.05, 0.85)
        r.bg:AddMaskTexture(r.mask)

        r.fill = r:CreateTexture(nil, "ARTWORK")
        r.fill:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT")
        r.fill:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT")
        r.fill:SetHeight(MICRO_SIZE)
        r.fill:SetTexture(PATH_FILL)
        r.fill:SetVertexColor(1, 1, 1, 1)
        r.fill:AddMaskTexture(r.mask)

        r.apexGlow = r:CreateTexture(nil, "OVERLAY", nil, 2)
        r.apexGlow:SetAllPoints()
        r.apexGlow:SetTexture(PATH_FILL)
        r.apexGlow:SetBlendMode("ADD")
        r.apexGlow:SetAlpha(0)
        r.apexGlow:AddMaskTexture(r.mask)

        r.glowAnim = r.apexGlow:CreateAnimationGroup()
        r.glowAnim:SetLooping("REPEAT")
        local a1 = r.glowAnim:CreateAnimation("Alpha")
        a1:SetFromAlpha(0)
        a1:SetToAlpha(0.6)
        a1:SetDuration(0.5)
        a1:SetOrder(1)
        local a2 = r.glowAnim:CreateAnimation("Alpha")
        a2:SetFromAlpha(0.6)
        a2:SetToAlpha(0)
        a2:SetDuration(0.5)
        a2:SetOrder(2)

        r.gloss = r:CreateTexture(nil, "OVERLAY", nil, 3)
        r.gloss:SetAllPoints()
        r.gloss:SetTexture(PATH_GLOSS)

        r:Hide()
        micros[i] = r
    end
end

function Orbs:OnEnable()
    self.EventFrame = CreateFrame("Frame")

    -- VALORIAN FIX: CPU Optimized Unit Tracking
    self.EventFrame:RegisterUnitEvent("UNIT_HEALTH", "player")
    self.EventFrame:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
    self.EventFrame:RegisterUnitEvent("UNIT_HEAL_PREDICTION", "player")
    self.EventFrame:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player")
    self.EventFrame:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    self.EventFrame:RegisterUnitEvent("UNIT_MAXPOWER", "player")
    self.EventFrame:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
    self.EventFrame:RegisterUnitEvent("UNIT_AURA", "player")

    self.EventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    self.EventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    self.EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

    self.EventFrame:SetScript("OnEvent", function(_, event, eventUnit)
        if event == "PLAYER_SPECIALIZATION_CHANGED" then
            C_Timer.After(0.5, RefreshMicroLayout)
        elseif event == "PLAYER_REGEN_DISABLED" then
            if ns.db.showAngels then
                HealthOrb.combatAnim:Play()
                PowerOrb.combatAnim:Play()
            end
            if activeType == "AURA" then
                UpdateAuraPower()
            elseif activeType ~= "RUNES" then
                UpdateStandardPower()
            end
        elseif event == "PLAYER_REGEN_ENABLED" then
            HealthOrb.combatAnim:Stop()
            HealthOrb.angelGlow:SetAlpha(0)
            PowerOrb.combatAnim:Stop()
            PowerOrb.angelGlow:SetAlpha(0)
            if activeType == "AURA" then
                UpdateAuraPower()
            elseif activeType ~= "RUNES" then
                UpdateStandardPower()
            end
        elseif eventUnit == "player" then
            if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_HEAL_PREDICTION" or event == "UNIT_ABSORB_AMOUNT_CHANGED" then
                UpdateHealth()
            elseif event == "UNIT_MAXPOWER" then
                UpdatePower()
                RefreshMicroLayout()
            elseif event == "UNIT_AURA" then
                if activeType == "AURA" then UpdateAuraPower() end
            elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_DISPLAYPOWER" then
                UpdatePower()
                UpdateStandardPower()
            end
        end
    end)

    UpdateHealth()
    UpdatePower()
    RefreshMicroLayout()

    C_Timer.After(0.5, function()
        UpdateHealth()
        UpdatePower()
        RefreshMicroLayout()

        if InCombatLockdown() and ns.db.showAngels then
            HealthOrb.combatAnim:Play()
            PowerOrb.combatAnim:Play()
        end
    end)
end
