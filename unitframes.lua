-- ==========================================
-- VALORIAN UI: CUSTOM UNIT FRAMES ENGINE
-- ==========================================
local addonName, ns = ...
local UnitFrames = ns.Engine:NewModule("UnitFrames")

local issecretvalue = issecretvalue or function() return false end
local function canaccessvalue(v)
    return v ~= nil and not issecretvalue(v)
end

UnitFrames.PendingUpdates = {}
local UF_Anchors = {}

local function FlipAnchor(anchor)
    if not anchor then return "CENTER" end
    if string.match(anchor, "LEFT") then return string.gsub(anchor, "LEFT", "RIGHT") end
    if string.match(anchor, "RIGHT") then return string.gsub(anchor, "RIGHT", "LEFT") end
    return anchor
end

-- ==========================================
-- 1. THE BLACK HOLE
-- ==========================================
local ValUI_HiddenFrame = CreateFrame("Frame", "ValorianUIHiddenFrame")
ValUI_HiddenFrame:Hide()

local function KillBlizzardFrame(frame)
    if not frame then return end
    frame:UnregisterAllEvents()
    frame:Hide()
    frame:SetAlpha(0)
    if not InCombatLockdown() then frame:SetParent(ValUI_HiddenFrame) end
end

-- ==========================================
-- 2. CASTBAR ANIMATION ENGINE
-- ==========================================
local function CastBar_OnUpdate(self, elapsed)
    if self.casting or self.empowering then
        self.value = self.value + elapsed
        if self.value >= self.maxValue then
            self:Hide()
            return
        end
        self:SetValue(self.value)
        self.Timer:SetText(string.format("%.1f", self.maxValue - self.value))

        local sparkPosition = (self.value / self.maxValue) * self:GetWidth()
        self.Spark:SetPoint("CENTER", self, "LEFT", sparkPosition, 0)
    elseif self.channeling then
        self.value = self.value - elapsed
        if self.value <= 0 then
            self:Hide()
            return
        end
        self:SetValue(self.value)
        self.Timer:SetText(string.format("%.1f", self.value))

        local sparkPosition = (self.value / self.maxValue) * self:GetWidth()
        self.Spark:SetPoint("CENTER", self, "LEFT", sparkPosition, 0)
    end
end

-- ==========================================
-- 3. SECURE UNIT FRAME FACTORY
-- ==========================================
local ActiveValorianFrames = {}

local function MakeDraggable(frame, nameText)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")

    frame.dragOverlay = CreateFrame("Frame", nil, frame)
    frame.dragOverlay:SetAllPoints()
    frame.dragOverlay:SetFrameLevel(frame:GetFrameLevel() + 10)

    local tex = frame.dragOverlay:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints()
    tex:SetColorTexture(0, 1, 0, 0.4)

    local txt = frame.dragOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    txt:SetPoint("CENTER")
    txt:SetText(nameText .. "\n(Drag to Move)")

    frame.dragOverlay:Hide()

    frame:SetScript("OnDragStart", function(self)
        if ValUI_UFUnlocked and not InCombatLockdown() then self:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        if not ns.db.frames then ns.db.frames = {} end
        ns.db.frames[self:GetName()] = { point = p, relativePoint = rp, x = x, y = y, scale = self:GetScale() or 1 }
    end)

    table.insert(UF_Anchors, frame:GetName())
end

local UpdateUnitAuras

local function CreateValorianUnit(unitType, frameName, point, x, y, width, height)
    local frame = CreateFrame("Button", frameName, UIParent, "SecureUnitButtonTemplate, BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetPoint(point, UIParent, point, x, y)

    frame:SetAttribute("unit", unitType)
    frame:SetAttribute("*type1", "target")
    frame:SetAttribute("*type2", "togglemenu")
    RegisterUnitWatch(frame)

    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local barTex = (LSM and LSM:Fetch("statusbar", ns.db.ufHealthTexture or "Minimalist")) or
    "Interface\\TargetingFrame\\UI-StatusBar"

    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 })
    frame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    local portrait = CreateFrame("Frame", nil, frame)
    local portrait3D = CreateFrame("PlayerModel", nil, portrait)
    portrait3D:SetAllPoints()
    local portrait2D = portrait:CreateTexture(nil, "ARTWORK")
    portrait2D:SetAllPoints()

    local healthBar = CreateFrame("StatusBar", nil, frame)
    healthBar:SetStatusBarTexture(barTex)
    healthBar:SetMinMaxValues(0, 1)
    healthBar:SetValue(1)

    local healTex = healthBar:CreateTexture(nil, "ARTWORK", nil, 1)
    healTex:SetTexture(barTex)
    healTex:SetVertexColor(0.2, 0.8, 0.2, 0.6)
    healTex:SetPoint("TOPLEFT", healthBar:GetStatusBarTexture(), "TOPRIGHT")
    healTex:SetPoint("BOTTOMLEFT", healthBar:GetStatusBarTexture(), "BOTTOMRIGHT")
    healTex:SetWidth(0.001)
    healTex:Hide()

    local absorbTex = healthBar:CreateTexture(nil, "ARTWORK", nil, 2)
    absorbTex:SetTexture(barTex)
    absorbTex:SetVertexColor(0.0, 0.8, 1.0, 0.6)
    absorbTex:SetPoint("TOPLEFT", healTex, "TOPRIGHT")
    absorbTex:SetPoint("BOTTOMLEFT", healTex, "BOTTOMRIGHT")
    absorbTex:SetWidth(0.001)
    absorbTex:Hide()

    local powerBar = CreateFrame("StatusBar", nil, frame)
    powerBar:SetStatusBarTexture((LSM and LSM:Fetch("statusbar", ns.db.ufPowerTexture or "Minimalist")) or
    "Interface\\TargetingFrame\\UI-StatusBar")
    powerBar:SetMinMaxValues(0, 1)
    powerBar:SetValue(1)

    local castBar = CreateFrame("StatusBar", nil, frame, "BackdropTemplate")
    castBar:SetStatusBarTexture((LSM and LSM:Fetch("statusbar", ns.db.ufCastbarTexture or "Minimalist")) or
    "Interface\\TargetingFrame\\UI-StatusBar")
    castBar:SetBackdropColor(0, 0, 0, 0.8)
    castBar:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    castBar:Hide()
    castBar:SetScript("OnUpdate", CastBar_OnUpdate)

    local cbIcon = castBar:CreateTexture(nil, "ARTWORK")
    cbIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local cbSpark = castBar:CreateTexture(nil, "OVERLAY")
    cbSpark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    cbSpark:SetBlendMode("ADD")
    cbSpark:SetAlpha(0.8)

    local cbText = castBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cbText:SetTextColor(1, 1, 1)
    if STANDARD_TEXT_FONT then cbText:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE") end

    local cbTimer = castBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cbTimer:SetTextColor(1, 1, 1)
    if STANDARD_TEXT_FONT then cbTimer:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE") end

    castBar.Icon = cbIcon
    castBar.Spark = cbSpark
    castBar.Text = cbText
    castBar.Timer = cbTimer

    local classIcon = frame:CreateTexture(nil, "OVERLAY")
    classIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
    classIcon:Hide()

    local statusIcon = frame:CreateTexture(nil, "OVERLAY")
    statusIcon:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
    statusIcon:Hide()

    local roleIcon = frame:CreateTexture(nil, "OVERLAY")
    roleIcon:Hide()

    local leaderIcon = frame:CreateTexture(nil, "OVERLAY")
    leaderIcon:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
    leaderIcon:Hide()

    local lootIcon = frame:CreateTexture(nil, "OVERLAY")
    lootIcon:SetTexture("Interface\\GroupFrame\\UI-Group-MasterLooter")
    lootIcon:Hide()

    frame.Portrait = portrait
    frame.Portrait3D = portrait3D
    frame.Portrait2D = portrait2D

    frame.HealthBar = healthBar
    frame.HealTex = healTex
    frame.AbsorbTex = absorbTex
    frame.PowerBar = powerBar
    frame.CastBar = castBar

    frame.ClassIcon = classIcon
    frame.StatusIcon = statusIcon
    frame.RoleIcon = roleIcon
    frame.LeaderIcon = leaderIcon
    frame.LootIcon = lootIcon

    local nameText = healthBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if STANDARD_TEXT_FONT then nameText:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE") end
    nameText:SetTextColor(1, 1, 1)
    frame.NameText = nameText

    local healthText = healthBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if STANDARD_TEXT_FONT then healthText:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE") end
    frame.HealthText = healthText

    frame.Auras = {}
    frame.vUnit = unitType

    frame.UpdateAuras = function()
        if ValUI_UFUnlocked then UnitFrames:ShowDummyAuras(frame) else UpdateUnitAuras(frame) end
    end

    table.insert(ActiveValorianFrames, frame)

    return frame
end

-- ==========================================
-- 4. THE DYNAMIC LAYOUT ENGINE
-- ==========================================
local function GetBorderConfig(u)
    if u == "player" then
        return ns.db.ufPlayerBorder, ns.db.ufPlayerBorderOffset
    elseif u == "target" or u == "targettarget" or u == "focus" or u == "focustarget" then
        return ns.db.ufTargetBorder, ns.db.ufTargetBorderOffset
    elseif string.match(u, "^party") then
        return ns.db.ufPartyBorder, ns.db.ufPartyBorderOffset
    elseif string.match(u, "^raid") then
        return ns.db.ufRaidBorder, ns.db.ufRaidBorderOffset
    else
        return ns.db.ufEncounterBorder, ns.db.ufEncounterBorderOffset
    end
end

local function GetBaseSize(u)
    if u == "target" or u == "targettarget" or u == "focus" or u == "focustarget" then
        return ns.db.ufTargetWidth or 240, ns.db.ufTargetHeight or 52, ns.db.ufTargetPortraitSize or 46
    end
    return ns.db.ufWidth or 240, ns.db.ufHeight or 52, ns.db.ufPortraitSize or 46
end

local function GetIconConfig(u, iconType)
    local prefix
    if u == "player" then
        prefix = "ufPlayer"
    elseif u == "target" or u == "targettarget" or u == "focus" or u == "focustarget" then
        prefix = "ufTarget"
    elseif string.match(u, "^party") then
        prefix = "ufParty"
    elseif string.match(u, "^raid") then
        prefix = "ufRaid"
    else
        prefix = "ufEncounter"
    end

    local anchor = ns.db[prefix .. iconType .. "Anchor"]
    if not anchor then
        if iconType == "Aura" then
            anchor = "TOPLEFT"
        elseif iconType == "Class" then
            anchor = "TOPLEFT"
        elseif iconType == "Status" then
            anchor = "BOTTOMLEFT"
        elseif iconType == "Group" then
            anchor = "TOP"
        end
    end

    local size = ns.db[prefix .. iconType .. "Size"]
    if not size then size = (iconType == "Aura" and 22 or (iconType == "Group" and 16 or 24)) end

    local x = ns.db[prefix .. iconType .. "X"]
    local y = ns.db[prefix .. iconType .. "Y"]

    if x == nil then
        if iconType == "Aura" then
            x = 0; y = 2
        elseif iconType == "Class" then
            x = 5; y = -5
        elseif iconType == "Status" then
            x = 5; y = 5
        elseif iconType == "Group" then
            x = 0; y = 8
        end
    end

    return anchor, size, x, y
end

function UnitFrames:UpdateAllLayouts()
    local partyW = ns.db.ufPartyWidth or 160
    local partyH = ns.db.ufPartyHeight or 40
    local partyPSize = ns.db.ufPartyPortraitSize or 34
    local partySpacing = ns.db.ufPartySpacing or 15

    local raidW = ns.db.ufRaidWidth or 90
    local raidH = ns.db.ufRaidHeight or 36
    local raidCols = ns.db.ufRaidCols or 5
    local raidSpacingX = ns.db.ufRaidSpacingX or 5
    local raidSpacingY = ns.db.ufRaidSpacingY or 5

    local encW = ns.db.ufEncounterWidth or 180
    local encH = ns.db.ufEncounterHeight or 45
    local encSpacing = ns.db.ufEncounterSpacing or 25

    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local hTex = (LSM and LSM:Fetch("statusbar", ns.db.ufHealthTexture or "Minimalist")) or
    "Interface\\TargetingFrame\\UI-StatusBar"

    for _, frame in ipairs(ActiveValorianFrames) do
        local u = frame.vUnit
        local baseW, baseH, basePSize = GetBaseSize(u)

        local bTexName, bOffset = GetBorderConfig(u)
        local borderPath = (LSM and LSM:Fetch("border", bTexName or "Blizzard Tooltip")) or
        "Interface\\Tooltips\\UI-Tooltip-Border"
        bOffset = bOffset or 2
        local pad = bOffset + 2

        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = borderPath,
            edgeSize = 12,
            insets = { left = bOffset, right = bOffset, top = bOffset, bottom = bOffset }
        })
        frame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
        frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

        if frame.HealTex then frame.HealTex:SetTexture(hTex) end
        if frame.AbsorbTex then frame.AbsorbTex:SetTexture(hTex) end

        if frame.CastBar then
            frame.CastBar:SetBackdrop({ edgeFile = borderPath, edgeSize = 10, bgFile = "Interface\\Buttons\\WHITE8x8", insets = { left = bOffset, right = bOffset, top = bOffset, bottom = bOffset } })
            frame.CastBar:SetBackdropColor(0, 0, 0, 0.8)
            frame.CastBar:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        end

        local isSmall = (u == "targettarget" or u == "focustarget")
        local isParty = string.match(u, "^party")
        local isRaid = string.match(u, "^raid")
        local isEncounter = (string.match(u, "^boss") or string.match(u, "^arena"))
        local useLeft = (u == "player" or u == "focus" or isParty or isRaid)

        local cAnchor, cSize, cX, cY = GetIconConfig(u, "Class")
        local sAnchor, sSize, sX, sY = GetIconConfig(u, "Status")
        local gAnchor, gSize, gX, gY = GetIconConfig(u, "Group")

        frame.ClassIcon:SetSize(cSize, cSize)
        frame.StatusIcon:SetSize(sSize, sSize)
        frame.LeaderIcon:SetSize(gSize, gSize)
        frame.RoleIcon:SetSize(gSize, gSize)
        frame.LootIcon:SetSize(gSize, gSize)

        if isRaid then
            local index = tonumber(string.match(u, "%d+"))
            frame:SetSize(raidW, raidH)
            frame.Portrait:Hide()
            frame.CastBar:Hide()

            frame.HealthBar:ClearAllPoints()
            frame.HealthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -pad)
            frame.HealthBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -pad, pad + 8)

            frame.NameText:ClearAllPoints()
            frame.NameText:SetPoint("CENTER", frame.HealthBar, "CENTER", 0, 0)
            frame.NameText:SetJustifyH("CENTER")
            frame.HealthText:Hide()

            frame.PowerBar:ClearAllPoints()
            frame.PowerBar:SetPoint("TOPLEFT", frame.HealthBar, "BOTTOMLEFT", 0, -2)
            frame.PowerBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -pad, pad)

            local row = math.floor((index - 1) / raidCols)
            local col = (index - 1) % raidCols
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", _G["ValorianUI_RaidAnchor"], "TOPLEFT", col * (raidW + raidSpacingX),
                -(row * (raidH + raidSpacingY)))
        else
            local w = isEncounter and encW or (isParty and partyW or (isSmall and (baseW * 0.6) or baseW))
            local h = isEncounter and encH or (isParty and partyH or (isSmall and (baseH * 0.7) or baseH))
            local pSize = isEncounter and (encH - 8) or
            (isParty and partyPSize or (isSmall and (basePSize * 0.7) or basePSize))

            local maxPSize = h - (pad * 2)
            if pSize > maxPSize then pSize = maxPSize end

            frame:SetSize(w, h)
            frame.Portrait:SetSize(pSize, pSize)
            frame.Portrait:Show()

            if isParty then
                local index = tonumber(string.match(u, "%d+"))
                frame:ClearAllPoints()
                frame:SetPoint("TOPLEFT", _G["ValorianUI_PartyAnchor"], "TOPLEFT", 0, -((index - 1) * (h + partySpacing)))
            elseif isEncounter then
                local index = tonumber(string.match(u, "%d+"))
                frame:ClearAllPoints()
                if string.match(u, "^boss") then
                    frame:SetPoint("TOPRIGHT", _G["ValorianUI_BossAnchor"], "TOPRIGHT", 0,
                        -((index - 1) * (h + encSpacing)))
                else
                    frame:SetPoint("TOPRIGHT", _G["ValorianUI_ArenaAnchor"], "TOPRIGHT", 0,
                        -((index - 1) * (h + encSpacing)))
                end
            end

            local cbHeight = (isSmall or isParty or isEncounter) and 12 or 16
            frame.CastBar:SetSize(w, cbHeight)
            frame.CastBar.Icon:SetSize(cbHeight + (bOffset * 2), cbHeight + (bOffset * 2))
            frame.CastBar.Spark:SetSize(20, cbHeight * 2)

            if useLeft then
                frame.Portrait:ClearAllPoints()
                frame.Portrait:SetPoint("LEFT", frame, "LEFT", pad, 0)

                frame.HealthBar:ClearAllPoints()
                frame.HealthBar:SetPoint("TOPLEFT", frame.Portrait, "TOPRIGHT", 4, 1)
                frame.HealthBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -pad, pad + 12)

                frame.NameText:ClearAllPoints()
                frame.NameText:SetPoint("LEFT", frame.HealthBar, "LEFT", 5, 0)
                frame.NameText:SetJustifyH("LEFT")

                frame.HealthText:Show()
                frame.HealthText:ClearAllPoints()
                frame.HealthText:SetPoint("RIGHT", frame.HealthBar, "RIGHT", -5, 0)

                frame.CastBar:ClearAllPoints()
                frame.CastBar:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -8)
                frame.CastBar.Icon:ClearAllPoints()
                frame.CastBar.Icon:SetPoint("RIGHT", frame.CastBar, "LEFT", -2, 0)
                frame.CastBar.Text:ClearAllPoints()
                frame.CastBar.Text:SetPoint("LEFT", frame.CastBar, "LEFT", pad + 2, 0)
                frame.CastBar.Timer:ClearAllPoints()
                frame.CastBar.Timer:SetPoint("RIGHT", frame.CastBar, "RIGHT", -(pad + 2), 0)
            else
                frame.Portrait:ClearAllPoints()
                frame.Portrait:SetPoint("RIGHT", frame, "RIGHT", -pad, 0)

                frame.HealthBar:ClearAllPoints()
                frame.HealthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -pad)
                frame.HealthBar:SetPoint("BOTTOMRIGHT", frame.Portrait, "BOTTOMLEFT", -4, pad + 12)

                frame.NameText:ClearAllPoints()
                frame.NameText:SetPoint("RIGHT", frame.HealthBar, "RIGHT", -5, 0)
                frame.NameText:SetJustifyH("RIGHT")

                frame.HealthText:Show()
                frame.HealthText:ClearAllPoints()
                frame.HealthText:SetPoint("LEFT", frame.HealthBar, "LEFT", 5, 0)

                frame.CastBar:ClearAllPoints()
                frame.CastBar:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -8)
                frame.CastBar.Icon:ClearAllPoints()
                frame.CastBar.Icon:SetPoint("LEFT", frame.CastBar, "RIGHT", 2, 0)
                frame.CastBar.Text:ClearAllPoints()
                frame.CastBar.Text:SetPoint("RIGHT", frame.CastBar, "RIGHT", -(pad + 2), 0)
                frame.CastBar.Timer:ClearAllPoints()
                frame.CastBar.Timer:SetPoint("LEFT", frame.CastBar, "LEFT", pad + 2, 0)
            end

            frame.PowerBar:ClearAllPoints()
            frame.PowerBar:SetPoint("TOPLEFT", frame.HealthBar, "BOTTOMLEFT", 0, -2)
            frame.PowerBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", useLeft and -pad or -(pad + pSize + 4), pad)
        end

        if useLeft then
            frame.ClassIcon:ClearAllPoints()
            frame.ClassIcon:SetPoint("CENTER", frame, cAnchor, cX, cY)
            frame.StatusIcon:ClearAllPoints()
            frame.StatusIcon:SetPoint("CENTER", frame, sAnchor, sX, sY)
            frame.RoleIcon:ClearAllPoints()
            frame.RoleIcon:SetPoint("CENTER", frame, gAnchor, gX - 16, gY)
            frame.LeaderIcon:ClearAllPoints()
            frame.LeaderIcon:SetPoint("CENTER", frame, gAnchor, gX, gY)
            frame.LootIcon:ClearAllPoints()
            frame.LootIcon:SetPoint("CENTER", frame, gAnchor, gX + 16, gY)
        else
            frame.ClassIcon:ClearAllPoints()
            frame.ClassIcon:SetPoint("CENTER", frame, FlipAnchor(cAnchor), -cX, cY)
            frame.StatusIcon:ClearAllPoints()
            frame.StatusIcon:SetPoint("CENTER", frame, FlipAnchor(sAnchor), -sX, sY)
            frame.RoleIcon:ClearAllPoints()
            frame.RoleIcon:SetPoint("CENTER", frame, FlipAnchor(gAnchor), -gX + 16, gY)
            frame.LeaderIcon:ClearAllPoints()
            frame.LeaderIcon:SetPoint("CENTER", frame, FlipAnchor(gAnchor), -gX, gY)
            frame.LootIcon:ClearAllPoints()
            frame.LootIcon:SetPoint("CENTER", frame, FlipAnchor(gAnchor), -gX - 16, gY)
        end

        if frame.UpdateAuras then frame:UpdateAuras() end
    end
end

-- ==========================================
-- 5. TEST MODE ENGINE & DUMMY AURAS
-- ==========================================
function UnitFrames:ShowDummyAuras(frame)
    local u = frame.vUnit
    local isSmall = (u == "targettarget" or u == "focustarget" or string.match(u, "^party"))
    local isEncounter = (string.match(u, "^boss") or string.match(u, "^arena"))
    local isRaid = string.match(u, "^raid")
    local useLeft = (u == "player" or u == "focus" or string.match(u, "^party") or isRaid)

    local aAnchor, iconSize, aX, aY = GetIconConfig(u, "Aura")
    local actualSize = (isSmall or isEncounter or isRaid) and (iconSize * 0.7) or iconSize

    local isRightAnchor = string.match(aAnchor, "RIGHT")
    local isBottomAnchor = string.match(aAnchor, "BOTTOM")
    local btnY = isBottomAnchor and "TOP" or "BOTTOM"
    local btnX = isRightAnchor and "RIGHT" or "LEFT"
    if aAnchor == "CENTER" or aAnchor == "TOP" or aAnchor == "BOTTOM" then btnX = "LEFT" end
    local btnAnchor = btnY .. btnX

    for i = 1, 3 do
        local btn = frame.Auras[i]
        if not btn then
            btn = CreateFrame("Frame", nil, frame, "BackdropTemplate")
            btn:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
            btn.icon = btn:CreateTexture(nil, "BACKGROUND")
            btn.icon:SetPoint("TOPLEFT", 1, -1)
            btn.icon:SetPoint("BOTTOMRIGHT", -1, 1)
            btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            btn.cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
            btn.count = btn.cd:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
            btn.count:SetPoint("BOTTOMRIGHT", 2, -2)
            frame.Auras[i] = btn
        end

        btn:SetSize(actualSize, actualSize)
        btn.icon:SetTexture("Interface\\Icons\\Spell_Holy_WordFortitude")
        btn:SetBackdropBorderColor(0, 0, 0, 1)
        btn.count:SetText("")
        btn.cd:Hide()

        btn:ClearAllPoints()
        local xOffset = (i - 1) * (actualSize + 2)
        if isRightAnchor then xOffset = -xOffset end

        if useLeft then
            btn:SetPoint(btnAnchor, frame, aAnchor, xOffset + aX, aY)
        else
            local fAnchor = FlipAnchor(aAnchor)
            local fbAnchor = FlipAnchor(btnAnchor)
            local fXOffset = (i - 1) * (actualSize + 2)
            if string.match(fAnchor, "RIGHT") then fXOffset = -fXOffset end
            btn:SetPoint(fbAnchor, frame, fAnchor, fXOffset - aX, aY)
        end

        btn:Show()
    end
end

function UnitFrames:ToggleTestMode(enable)
    if InCombatLockdown() then return end

    for _, anchor in ipairs(UF_Anchors) do
        local f = _G[anchor]
        if f and f.dragOverlay then
            if enable then
                f.dragOverlay:Show()
                f:EnableMouse(true)
            else
                f.dragOverlay:Hide()
                if not f.vUnit then f:EnableMouse(false) end
            end
        end
    end

    for _, frame in ipairs(ActiveValorianFrames) do
        if enable then
            local u = frame.vUnit
            UnregisterUnitWatch(frame)
            frame:Show()
            frame:SetAlpha(1)

            if frame.NameText then frame.NameText:SetText(frame.vUnit:upper()) end
            if frame.HealthBar then
                frame.HealthBar:SetMinMaxValues(0, 100)
                frame.HealthBar:SetValue(60)
                frame.HealthBar:SetStatusBarColor(0.2, 0.8, 0.2)

                local bw = frame.HealthBar:GetWidth()
                if bw and bw > 0 then
                    frame.HealTex:SetWidth(bw * 0.2)
                    frame.HealTex:Show()
                    frame.AbsorbTex:SetWidth(bw * 0.2)
                    frame.AbsorbTex:Show()
                end
            end

            if frame.HealthText then frame.HealthText:SetText("60k") end

            if frame.PowerBar then
                frame.PowerBar:SetMinMaxValues(0, 100)
                frame.PowerBar:SetValue(100)
                frame.PowerBar:SetStatusBarColor(0.2, 0.5, 1.0)
            end

            if frame.Portrait then
                if ns.db.ufUse2DPortraits then
                    frame.Portrait3D:Hide()
                    frame.Portrait2D:Show()
                    SetPortraitTexture(frame.Portrait2D, "player")
                    frame.Portrait2D:SetTexCoord(0.15, 0.85, 0.15, 0.85)
                else
                    frame.Portrait2D:Hide()
                    frame.Portrait3D:Show()
                    if frame.Portrait3D.ClearModel then frame.Portrait3D:ClearModel() end
                end
            end

            if frame.CastBar then frame.CastBar:Hide() end
            if frame.ClassIcon then frame.ClassIcon:Show() end
            if frame.StatusIcon and u == "player" then
                frame.StatusIcon:Show(); frame.StatusIcon:SetTexCoord(0.5, 1.0, 0.0, 0.49)
            end

            local isGroupFrame = (u == "player" or string.match(u, "^party") or string.match(u, "^raid"))
            if isGroupFrame then
                if frame.RoleIcon then
                    frame.RoleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
                    frame.RoleIcon:SetTexCoord(0, 0.296875, 0.015625, 0.3125)
                    frame.RoleIcon:Show()
                end
                if frame.LeaderIcon then frame.LeaderIcon:Show() end
                if frame.LootIcon then frame.LootIcon:Show() end
            else
                if frame.RoleIcon then frame.RoleIcon:Hide() end
                if frame.LeaderIcon then frame.LeaderIcon:Hide() end
                if frame.LootIcon then frame.LootIcon:Hide() end
            end

            frame:SetBackdropBorderColor(1, 0.1, 0.1, 1)

            if frame.UpdateAuras then frame:UpdateAuras() end
        else
            RegisterUnitWatch(frame)
            frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
            if frame.HealTex then frame.HealTex:Hide() end
            if frame.AbsorbTex then frame.AbsorbTex:Hide() end
            if self.PendingUpdates then self.PendingUpdates[frame] = { all = true } end
        end
    end
end

-- ==========================================
-- 6. UNIT FRAME CASTBAR DATA ENGINE
-- ==========================================
local function GetCastColor(castType, notInterruptible)
    if notInterruptible then return ns.db.ufCastUninterruptColor or { r = 0.6, g = 0.6, b = 0.6 } end
    if castType == "channel" then return ns.db.ufCastChannelColor or { r = 0.2, g = 0.8, b = 0.2 } end
    if castType == "empower" then return ns.db.ufCastEmpoweredColor or { r = 0.3, g = 0.7, b = 1.0 } end
    return ns.db.ufCastNormalColor or { r = 1.0, g = 0.7, b = 0.0 }
end

local function StartCast(frame, u)
    if string.match(u, "^raid") then return end

    local name, _, texture, startTime, endTime, _, _, notInterruptible = UnitCastingInfo(u)
    if not name or not canaccessvalue(startTime) or not canaccessvalue(endTime) then return end

    frame.CastBar.casting = true
    frame.CastBar.channeling = false
    frame.CastBar.empowering = false
    frame.CastBar.value = (GetTime() - (startTime / 1000))
    frame.CastBar.maxValue = (endTime - startTime) / 1000
    frame.CastBar:SetMinMaxValues(0, frame.CastBar.maxValue)
    frame.CastBar:SetValue(frame.CastBar.value)

    frame.CastBar.Icon:SetTexture(texture)
    frame.CastBar.Text:SetText(name)

    local c = GetCastColor("normal", notInterruptible)
    frame.CastBar:SetStatusBarColor(c.r, c.g, c.b)
    frame.CastBar:Show()
end

local function StartChannel(frame, u)
    if string.match(u, "^raid") then return end

    local name, _, texture, startTime, endTime, _, notInterruptible = UnitChannelInfo(u)
    if not name or not canaccessvalue(startTime) or not canaccessvalue(endTime) then return end

    frame.CastBar.casting = false
    frame.CastBar.channeling = true
    frame.CastBar.empowering = false
    frame.CastBar.value = ((endTime / 1000) - GetTime())
    frame.CastBar.maxValue = (endTime - startTime) / 1000
    frame.CastBar:SetMinMaxValues(0, frame.CastBar.maxValue)
    frame.CastBar:SetValue(frame.CastBar.value)

    frame.CastBar.Icon:SetTexture(texture)
    frame.CastBar.Text:SetText(name)

    local c = GetCastColor("channel", notInterruptible)
    frame.CastBar:SetStatusBarColor(c.r, c.g, c.b)
    frame.CastBar:Show()
end

local function StartEmpower(frame, u)
    if string.match(u, "^raid") then return end

    local name, _, texture, startTime, endTime, _, notInterruptible = UnitChannelInfo(u)
    if not name or not canaccessvalue(startTime) or not canaccessvalue(endTime) then return end

    frame.CastBar.casting = false
    frame.CastBar.channeling = false
    frame.CastBar.empowering = true
    frame.CastBar.value = (GetTime() - (startTime / 1000))
    frame.CastBar.maxValue = (endTime - startTime) / 1000
    frame.CastBar:SetMinMaxValues(0, frame.CastBar.maxValue)
    frame.CastBar:SetValue(frame.CastBar.value)

    frame.CastBar.Icon:SetTexture(texture)
    frame.CastBar.Text:SetText(name)

    local c = GetCastColor("empower", notInterruptible)
    frame.CastBar:SetStatusBarColor(c.r, c.g, c.b)
    frame.CastBar:Show()
end

local function StopCast(frame)
    if not frame.CastBar then return end
    frame.CastBar.casting = false
    frame.CastBar.channeling = false
    frame.CastBar.empowering = false
    frame.CastBar:Hide()
end

-- ==========================================
-- 7. NATIVE CASTBAR DOMINATION ENGINE
-- ==========================================
local function ForceNativeCastbarColor(bar)
    if not canaccessvalue(bar) then return end
    if canaccessvalue(bar.isValorianColoring) and bar.isValorianColoring then return end
    bar.isValorianColoring = true

    local c
    local isChannel = false
    local isEmpower = false
    local notInterruptible = false

    local name, _, _, _, _, _, _, uninterruptible = UnitCastingInfo("player")
    if not canaccessvalue(name) then name = nil end

    if not name then
        name, _, _, _, _, _, uninterruptible = UnitChannelInfo("player")
        if canaccessvalue(name) and name then
            local bEmp = canaccessvalue(bar.isEmpowered) and bar.isEmpowered
            local bType = canaccessvalue(bar.barType) and bar.barType
            if bEmp or bType == "empowered" then isEmpower = true else isChannel = true end
        end
    end

    notInterruptible = canaccessvalue(uninterruptible) and uninterruptible or false

    if isChannel then
        c = ns.db.nativeCastChannelColor or { r = 0.2, g = 0.8, b = 0.2 }
    elseif notInterruptible then
        c = ns.db.nativeCastUninterruptColor or { r = 0.6, g = 0.6, b = 0.6 }
    elseif isEmpower then
        c = ns.db.nativeCastEmpoweredColor or { r = 0.3, g = 0.7, b = 1.0 }
    else
        c = ns.db.nativeCastNormalColor or { r = 1.0, g = 0.7, b = 0.0 }
    end

    if c then bar:SetStatusBarColor(c.r, c.g, c.b) end
    bar.isValorianColoring = false
end

local function SkinNativeCastbar(bar)
    if not bar or bar.isValorianSkinned then return end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

    hooksecurefunc(bar, "SetStatusBarTexture", function(self)
        if self.isValorianTexturing then return end
        self.isValorianTexturing = true
        local tex = (LSM and LSM:Fetch("statusbar", ns.db.nativeCastbarTexture or "Minimalist")) or
        "Interface\\TargetingFrame\\UI-StatusBar"
        self:SetStatusBarTexture(tex)
        self.isValorianTexturing = false
    end)
    local t = (LSM and LSM:Fetch("statusbar", ns.db.nativeCastbarTexture or "Minimalist")) or
    "Interface\\TargetingFrame\\UI-StatusBar"
    bar:SetStatusBarTexture(t)

    if bar.Border then
        bar.Border:SetDesaturated(true); bar.Border:SetVertexColor(0.5, 0.5, 0.5)
    end
    if bar.BorderShield then
        bar.BorderShield:SetDesaturated(true); bar.BorderShield:SetVertexColor(0.5, 0.5, 0.5)
    end
    if bar.Flash then bar.Flash:SetTexture("") end

    bar:HookScript("OnShow", ForceNativeCastbarColor)
    bar:HookScript("OnEvent", ForceNativeCastbarColor)
    hooksecurefunc(bar, "SetStatusBarColor", ForceNativeCastbarColor)

    bar.isValorianSkinned = true
end

-- ==========================================
-- 8. THE DATA NERVOUS SYSTEM
-- ==========================================
local function UpdateUnitPortrait(frame)
    local u = frame.vUnit
    if string.match(u, "^raid") then return end
    if not UnitExists(u) then return end

    if ns.db.ufUse2DPortraits then
        frame.Portrait3D:Hide()
        frame.Portrait2D:Show()
        SetPortraitTexture(frame.Portrait2D, u)
        frame.Portrait2D:SetTexCoord(0.15, 0.85, 0.15, 0.85)
    else
        frame.Portrait2D:Hide()
        frame.Portrait3D:Show()

        local currentGUID = UnitGUID(u)
        if frame.Portrait3D.lastGUID ~= currentGUID or frame.Portrait3D.needsModelUpdate then
            frame.Portrait3D:SetUnit(u)
            frame.Portrait3D:SetPortraitZoom(1)
            frame.Portrait3D.lastGUID = currentGUID
            frame.Portrait3D.needsModelUpdate = false
        end
    end
end

local function UpdateFluffIcons(frame)
    local u = frame.vUnit
    if not UnitExists(u) then return end

    if UnitIsPlayer(u) then
        local _, class = UnitClass(u)
        local coords = CLASS_ICON_TCOORDS[class]
        if coords then
            frame.ClassIcon:SetTexCoord(unpack(coords))
            frame.ClassIcon:Show()
        end
    else
        frame.ClassIcon:Hide()
    end

    if u == "player" then
        if IsResting() then
            frame.StatusIcon:SetTexCoord(0, 0.5, 0, 0.421875)
            frame.StatusIcon:Show()
        elseif InCombatLockdown() then
            frame.StatusIcon:SetTexCoord(0.5, 1.0, 0.0, 0.49)
            frame.StatusIcon:Show()
        else
            frame.StatusIcon:Hide()
        end
    end

    local isGroupFrame = (u == "player" or string.match(u, "^party") or string.match(u, "^raid"))
    if isGroupFrame then
        if UnitIsGroupLeader(u) then
            frame.LeaderIcon:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
            frame.LeaderIcon:Show()
        elseif UnitIsGroupAssistant(u) then
            frame.LeaderIcon:SetTexture("Interface\\GroupFrame\\UI-Group-AssistantIcon")
            frame.LeaderIcon:Show()
        else
            frame.LeaderIcon:Hide()
        end

        local role = UnitGroupRolesAssigned(u)
        if role == "TANK" or role == "HEALER" or role == "DAMAGER" then
            frame.RoleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
            if role == "TANK" then
                frame.RoleIcon:SetTexCoord(0, 0.296875, 0.015625, 0.3125)
            elseif role == "HEALER" then
                frame.RoleIcon:SetTexCoord(0.3125, 0.609375, 0.015625, 0.3125)
            elseif role == "DAMAGER" then
                frame.RoleIcon:SetTexCoord(0.3125, 0.609375, 0.34375, 0.640625)
            end
            frame.RoleIcon:Show()
        else
            frame.RoleIcon:Hide()
        end

        if frame.LootIcon then
            local isML = false
            if GetLootMethod then
                local lootMethod, mlParty, mlRaid = GetLootMethod()
                if lootMethod == "master" then
                    if u == "player" and mlParty == 0 then
                        isML = true
                    elseif mlParty and mlParty > 0 and u == "party" .. mlParty then
                        isML = true
                    elseif mlRaid and mlRaid > 0 and u == "raid" .. mlRaid then
                        isML = true
                    end
                end
            end
            if isML then frame.LootIcon:Show() else frame.LootIcon:Hide() end
        end
    else
        frame.LeaderIcon:Hide()
        frame.RoleIcon:Hide()
        if frame.LootIcon then frame.LootIcon:Hide() end
    end
end

UpdateUnitAuras = function(frame)
    local u = frame.vUnit
    if not UnitExists(u) then return end

    local auraIndex = 1
    local isSmall = (u == "targettarget" or u == "focustarget" or string.match(u, "^party"))
    local isEncounter = (string.match(u, "^boss") or string.match(u, "^arena"))
    local isRaid = string.match(u, "^raid")
    local useLeft = (u == "player" or u == "focus" or string.match(u, "^party") or isRaid)

    local maxAuras = isRaid and 3 or (isSmall and 6 or 12)
    local aAnchor, iconSize, aX, aY = GetIconConfig(u, "Aura")
    local actualSize = (isSmall or isEncounter or isRaid) and (iconSize * 0.7) or iconSize

    local isRightAnchor = string.match(aAnchor, "RIGHT")
    local isBottomAnchor = string.match(aAnchor, "BOTTOM")
    local btnY = isBottomAnchor and "TOP" or "BOTTOM"
    local btnX = isRightAnchor and "RIGHT" or "LEFT"
    if aAnchor == "CENTER" or aAnchor == "TOP" or aAnchor == "BOTTOM" then btnX = "LEFT" end
    local btnAnchor = btnY .. btnX

    local function ProcessAuras(filter)
        if not C_UnitAuras then return end
        for i = 1, 40 do
            if auraIndex > maxAuras then break end
            local aura = C_UnitAuras.GetAuraDataByIndex(u, i, filter)
            if not aura then break end

            local btn = frame.Auras[auraIndex]
            if not btn then
                btn = CreateFrame("Frame", nil, frame, "BackdropTemplate")
                btn:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
                btn.icon = btn:CreateTexture(nil, "BACKGROUND")
                btn.icon:SetPoint("TOPLEFT", 1, -1)
                btn.icon:SetPoint("BOTTOMRIGHT", -1, 1)
                btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                btn.cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
                btn.cd:SetAllPoints(btn.icon)
                btn.cd:SetHideCountdownNumbers(false)
                btn.count = btn.cd:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
                btn.count:SetPoint("BOTTOMRIGHT", 2, -2)
                frame.Auras[auraIndex] = btn
            end

            btn:SetSize(actualSize, actualSize)
            btn.icon:SetTexture(aura.icon)

            local safeApps = canaccessvalue(aura.applications) and tonumber(aura.applications) or 0
            local safeDur = canaccessvalue(aura.duration) and tonumber(aura.duration) or 0
            local safeExpTime = canaccessvalue(aura.expirationTime) and tonumber(aura.expirationTime) or 0

            if safeApps > 1 then btn.count:SetText(safeApps) else btn.count:SetText("") end
            if safeDur > 0 then
                btn.cd:SetCooldown(safeExpTime - safeDur, safeDur)
                btn.cd:Show()
            else
                btn.cd:Hide()
            end

            if filter == "HARMFUL" then btn:SetBackdropBorderColor(0.8, 0.1, 0.1, 1) else btn:SetBackdropBorderColor(0, 0,
                    0, 1) end

            btn:ClearAllPoints()
            local xOffset = (auraIndex - 1) * (actualSize + 2)
            if isRightAnchor then xOffset = -xOffset end

            if useLeft then
                btn:SetPoint(btnAnchor, frame, aAnchor, xOffset + aX, aY)
            else
                local fAnchor = FlipAnchor(aAnchor)
                local fbAnchor = FlipAnchor(btnAnchor)
                local fXOffset = (auraIndex - 1) * (actualSize + 2)
                if string.match(fAnchor, "RIGHT") then fXOffset = -fXOffset end
                btn:SetPoint(fbAnchor, frame, fAnchor, fXOffset + aX, aY)
            end

            btn:Show()
            auraIndex = auraIndex + 1
        end
    end

    ProcessAuras("HELPFUL")
    ProcessAuras("HARMFUL")

    for i = auraIndex, #frame.Auras do frame.Auras[i]:Hide() end
end

local function UpdateUnitThreat(frame)
    local u = frame.vUnit
    if not UnitExists(u) then return end

    local status = UnitThreatSituation(u)
    if status and status >= 2 then
        frame:SetBackdropBorderColor(1, 0.1, 0.1, 1)
    else
        frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    end
end

local function UpdateUnitHealth(frame)
    local u = frame.vUnit
    if not UnitExists(u) then return end

    local hp = UnitHealth(u)
    local maxHp = UnitHealthMax(u)
    local incomingHeal = UnitGetIncomingHeals(u) or 0
    local absorb = UnitGetTotalAbsorbs(u) or 0

    local safeHP = canaccessvalue(hp) and tonumber(hp) or 0
    local safeMaxHP = canaccessvalue(maxHp) and tonumber(maxHp) or 1
    local safeIncoming = canaccessvalue(incomingHeal) and tonumber(incomingHeal) or 0
    local safeAbsorb = canaccessvalue(absorb) and tonumber(absorb) or 0

    if hp and maxHp then
        frame.HealthBar:SetMinMaxValues(0, maxHp)
        frame.HealthBar:SetValue(hp)
    end

    if safeMaxHP > 0 then
        local barWidth = frame.HealthBar:GetWidth()
        if barWidth and barWidth > 0 then
            local healWidth = (safeIncoming / safeMaxHP) * barWidth
            if (safeHP + safeIncoming) > safeMaxHP then
                healWidth = ((safeMaxHP - safeHP) / safeMaxHP) * barWidth
            end
            healWidth = math.max(0.001, healWidth)

            frame.HealTex:SetWidth(healWidth)
            if safeIncoming > 0 and safeHP < safeMaxHP then
                frame.HealTex:Show()
            else
                frame.HealTex:Hide()
            end

            local absorbWidth = (safeAbsorb / safeMaxHP) * barWidth
            local remainingWidth = barWidth - ((safeHP / safeMaxHP) * barWidth) - healWidth
            absorbWidth = math.min(absorbWidth, remainingWidth)
            absorbWidth = math.max(0.001, absorbWidth)

            frame.AbsorbTex:SetWidth(absorbWidth)
            if safeAbsorb > 0 and absorbWidth > 0.001 then
                frame.AbsorbTex:Show()
            else
                frame.AbsorbTex:Hide()
            end
        end
    end

    if not string.match(u, "^raid") then
        if canaccessvalue(hp) then
            local hpNum = tonumber(hp) or 0
            local hpStr = tostring(hpNum)
            if hpNum >= 1000000 then
                hpStr = string.format("%.1fm", hpNum / 1000000)
            elseif hpNum >= 1000 then
                hpStr = string.format("%.1fk", hpNum / 1000)
            end
            frame.HealthText:SetText(hpStr)
        else
            frame.HealthText:SetText("")
        end
    end

    if UnitIsPlayer(u) then
        local _, class = UnitClass(u)
        local color = RAID_CLASS_COLORS[class]
        if color then frame.HealthBar:SetStatusBarColor(color.r, color.g, color.b) end
    else
        local reaction = UnitReaction(u, "player")
        if reaction and reaction >= 5 then
            frame.HealthBar:SetStatusBarColor(0.1, 0.8, 0.1)
        elseif reaction == 4 then
            frame.HealthBar:SetStatusBarColor(0.8, 0.8, 0.1)
        else
            frame.HealthBar:SetStatusBarColor(0.8, 0.1, 0.1)
        end
    end
end

local function UpdateUnitPower(frame)
    local u = frame.vUnit
    if not UnitExists(u) then return end

    local power = UnitPower(u)
    local maxPower = UnitPowerMax(u)

    if power and maxPower then
        frame.PowerBar:SetMinMaxValues(0, maxPower)
        frame.PowerBar:SetValue(power)
    end

    local _, powerToken = UnitPowerType(u)
    local color = PowerBarColor[powerToken]
    if color then
        frame.PowerBar:SetStatusBarColor(color.r, color.g, color.b)
    else
        frame.PowerBar:SetStatusBarColor(0, 0.5, 1)
    end
end

local function UpdateUnitName(frame)
    local u = frame.vUnit
    if not UnitExists(u) then return end

    local name = UnitName(u)
    name = canaccessvalue(name) and name or ""

    if string.match(u, "^raid") and string.len(name) > 8 then
        name = string.sub(name, 1, 8) .. ".."
    end
    frame.NameText:SetText(name)
end

-- ==========================================
-- 9. INITIALIZATION & THE ASYNC QUEUE LOOP
-- ==========================================
function UnitFrames:OnInit()
    KillBlizzardFrame(PlayerFrame)
    KillBlizzardFrame(TargetFrame)
    KillBlizzardFrame(TargetFrameToT)
    KillBlizzardFrame(FocusFrame)
    KillBlizzardFrame(FocusFrameToT)
    KillBlizzardFrame(PartyFrame)
    if CompactPartyFrame then KillBlizzardFrame(CompactPartyFrame) end
    if CompactRaidFrameManager then KillBlizzardFrame(CompactRaidFrameManager) end
    if CompactRaidFrameContainer then KillBlizzardFrame(CompactRaidFrameContainer) end
    for i = 1, 5 do KillBlizzardFrame(_G["ArenaEnemyMatchFrame" .. i]) end
    for i = 1, 5 do KillBlizzardFrame(_G["Boss" .. i .. "TargetFrame"]) end

    if ns.db.showPlayerFrame ~= false then
        self.PlayerFrame = CreateValorianUnit("player", "ValorianUI_Player", "BOTTOM", -220, 250, 240, 52)
        MakeDraggable(self.PlayerFrame, "Player Frame")
    end

    if ns.db.showTargetFrames ~= false then
        self.TargetFrame = CreateValorianUnit("target", "ValorianUI_Target", "BOTTOM", 220, 250, 240, 52)
        MakeDraggable(self.TargetFrame, "Target Frame")
        self.FocusFrame = CreateValorianUnit("focus", "ValorianUI_Focus", "BOTTOM", -220, 450, 240, 52)
        MakeDraggable(self.FocusFrame, "Focus Frame")
    end

    if ns.db.showToTFrames ~= false then
        if self.TargetFrame then
            self.ToTFrame = CreateValorianUnit("targettarget", "ValorianUI_ToT", "TOPRIGHT", -20, 45, 140, 35)
            MakeDraggable(self.ToTFrame, "Target of Target")
            self.ToTFrame:SetPoint("TOPRIGHT", self.TargetFrame, "BOTTOMRIGHT", -10, -35)
        end
        if self.FocusFrame then
            self.FocusTargetFrame = CreateValorianUnit("focustarget", "ValorianUI_FocusTarget", "TOPLEFT", 20, 45, 140,
                35)
            MakeDraggable(self.FocusTargetFrame, "Focus Target")
            self.FocusTargetFrame:SetPoint("TOPLEFT", self.FocusFrame, "BOTTOMLEFT", 10, -35)
        end
    end

    if ns.db.showPartyFrames ~= false then
        self.PartyAnchor = CreateFrame("Frame", "ValorianUI_PartyAnchor", UIParent)
        self.PartyAnchor:SetSize(160, 40)
        self.PartyAnchor:SetPoint("LEFT", UIParent, "LEFT", 20, 100)
        MakeDraggable(self.PartyAnchor, "Party Frames Anchor")
        self.PartyFrames = {}
        for i = 1, 4 do table.insert(self.PartyFrames,
                CreateValorianUnit("party" .. i, "ValorianUI_Party" .. i, "TOPLEFT", 0, 0, 160, 40)) end
    end

    if ns.db.showRaidFrames ~= false then
        self.RaidAnchor = CreateFrame("Frame", "ValorianUI_RaidAnchor", UIParent)
        self.RaidAnchor:SetSize(90, 36)
        self.RaidAnchor:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -200)
        MakeDraggable(self.RaidAnchor, "Raid Frames Anchor")
        self.RaidFrames = {}
        for i = 1, 40 do table.insert(self.RaidFrames,
                CreateValorianUnit("raid" .. i, "ValorianUI_Raid" .. i, "TOPLEFT", 0, 0, 90, 36)) end
    end

    if ns.db.showBossFrames ~= false then
        self.BossAnchor = CreateFrame("Frame", "ValorianUI_BossAnchor", UIParent)
        self.BossAnchor:SetSize(180, 45)
        self.BossAnchor:SetPoint("RIGHT", UIParent, "RIGHT", -20, 100)
        MakeDraggable(self.BossAnchor, "Boss Frames Anchor")

        self.ArenaAnchor = CreateFrame("Frame", "ValorianUI_ArenaAnchor", UIParent)
        self.ArenaAnchor:SetSize(180, 45)
        self.ArenaAnchor:SetPoint("RIGHT", UIParent, "RIGHT", -20, -50)
        MakeDraggable(self.ArenaAnchor, "Arena Frames Anchor")

        self.BossFrames = {}
        for i = 1, 5 do table.insert(self.BossFrames,
                CreateValorianUnit("boss" .. i, "ValorianUI_Boss" .. i, "TOPRIGHT", 0, 0, 180, 45)) end
        self.ArenaFrames = {}
        for i = 1, 5 do table.insert(self.ArenaFrames,
                CreateValorianUnit("arena" .. i, "ValorianUI_Arena" .. i, "TOPRIGHT", 0, 0, 180, 45)) end
    end

    for _, name in ipairs(UF_Anchors) do
        local db = ns.db.frames and ns.db.frames[name]
        local f = _G[name]
        if f and db and db.point then
            f:ClearAllPoints()
            f:SetPoint(db.point, UIParent, db.relativePoint or db.point, db.x, db.y)
        end
    end
end

function UnitFrames:OnEnable()
    self:UpdateAllLayouts()

    if PlayerCastingBarFrame then SkinNativeCastbar(PlayerCastingBarFrame) end
    if CastingBarFrame then SkinNativeCastbar(CastingBarFrame) end

    -- VALORIAN FIX: Master Global Event Watcher (Only for systemic events)
    local GlobalWatcher = CreateFrame("Frame")
    GlobalWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    GlobalWatcher:RegisterEvent("PLAYER_TARGET_CHANGED")
    GlobalWatcher:RegisterEvent("PLAYER_FOCUS_CHANGED")
    GlobalWatcher:RegisterEvent("UNIT_TARGET")
    GlobalWatcher:RegisterEvent("GROUP_ROSTER_UPDATE")
    GlobalWatcher:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
    GlobalWatcher:RegisterEvent("ARENA_OPPONENT_UPDATE")
    GlobalWatcher:RegisterEvent("PLAYER_REGEN_DISABLED")
    GlobalWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    GlobalWatcher:RegisterEvent("PLAYER_UPDATE_RESTING")

    GlobalWatcher:SetScript("OnEvent", function(self, event, unit)
        if ValUI_UFUnlocked then return end

        for _, frame in ipairs(ActiveValorianFrames) do
            local u = frame.vUnit
            local needsUpdate = false
            local flag = ""

            if event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" or event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" or event == "ARENA_OPPONENT_UPDATE" then
                needsUpdate = true; flag = "all"
            elseif event == "PLAYER_TARGET_CHANGED" and (u == "target" or u == "targettarget") then
                needsUpdate = true; flag = "all"
            elseif event == "PLAYER_FOCUS_CHANGED" and (u == "focus" or u == "focustarget") then
                needsUpdate = true; flag = "all"
            elseif event == "UNIT_TARGET" then
                if unit == "target" and u == "targettarget" then
                    needsUpdate = true; flag = "all"
                elseif unit == "focus" and u == "focustarget" then
                    needsUpdate = true; flag = "all"
                elseif unit == "player" and u == "target" then
                    needsUpdate = true; flag = "all"
                end
            elseif (event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_UPDATE_RESTING") and u == "player" then
                needsUpdate = true; flag = "fluff"
            end

            if needsUpdate then
                UnitFrames.PendingUpdates[frame] = UnitFrames.PendingUpdates[frame] or {}
                UnitFrames.PendingUpdates[frame][flag] = true
            end
        end
    end)

    -- VALORIAN FIX: CPU Optimized Local Watchers!
    -- Each frame registers ONLY for its specific unit using RegisterUnitEvent.
    for _, frame in ipairs(ActiveValorianFrames) do
        local u = frame.vUnit
        local unitWatcher = CreateFrame("Frame", nil, frame)

        local function SafeRegister(evt)
            pcall(function() unitWatcher:RegisterUnitEvent(evt, u) end)
        end

        SafeRegister("UNIT_HEALTH")
        SafeRegister("UNIT_MAXHEALTH")
        SafeRegister("UNIT_POWER_UPDATE")
        SafeRegister("UNIT_MAXPOWER")
        SafeRegister("UNIT_NAME_UPDATE")
        SafeRegister("UNIT_AURA")
        SafeRegister("UNIT_PORTRAIT_UPDATE")
        SafeRegister("UNIT_MODEL_CHANGED")
        SafeRegister("UNIT_SPELLCAST_START")
        SafeRegister("UNIT_SPELLCAST_DELAYED")
        SafeRegister("UNIT_SPELLCAST_STOP")
        SafeRegister("UNIT_SPELLCAST_FAILED")
        SafeRegister("UNIT_SPELLCAST_INTERRUPTED")
        SafeRegister("UNIT_SPELLCAST_CHANNEL_START")
        SafeRegister("UNIT_SPELLCAST_CHANNEL_UPDATE")
        SafeRegister("UNIT_SPELLCAST_CHANNEL_STOP")
        SafeRegister("UNIT_SPELLCAST_EMPOWER_START")
        SafeRegister("UNIT_SPELLCAST_EMPOWER_UPDATE")
        SafeRegister("UNIT_SPELLCAST_EMPOWER_STOP")
        SafeRegister("UNIT_HEAL_PREDICTION")
        SafeRegister("UNIT_ABSORB_AMOUNT_CHANGED")
        SafeRegister("UNIT_THREAT_SITUATION_UPDATE")
        SafeRegister("UNIT_THREAT_LIST_UPDATE")

        unitWatcher:SetScript("OnEvent", function(self, event, unit)
            if ValUI_UFUnlocked then return end

            UnitFrames.PendingUpdates[frame] = UnitFrames.PendingUpdates[frame] or {}
            local flags = UnitFrames.PendingUpdates[frame]

            if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_HEAL_PREDICTION" or event == "UNIT_ABSORB_AMOUNT_CHANGED" then
                flags.health = true
            elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" then
                flags.power = true
            elseif event == "UNIT_NAME_UPDATE" then
                flags.name = true
            elseif event == "UNIT_AURA" then
                flags.aura = true
            elseif event == "UNIT_PORTRAIT_UPDATE" or event == "UNIT_MODEL_CHANGED" then
                flags.portrait = true
                if frame.Portrait3D then frame.Portrait3D.needsModelUpdate = true end
            elseif event == "UNIT_THREAT_SITUATION_UPDATE" or event == "UNIT_THREAT_LIST_UPDATE" then
                flags.threat = true
            elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_DELAYED" then
                StartCast(frame, u)
            elseif event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
                StartChannel(frame, u)
            elseif event == "UNIT_SPELLCAST_EMPOWER_START" or event == "UNIT_SPELLCAST_EMPOWER_UPDATE" then
                StartEmpower(frame, u)
            elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_EMPOWER_STOP" then
                StopCast(frame)
            end
        end)
    end

    local UpdateDispatcher = CreateFrame("Frame")
    UpdateDispatcher:SetScript("OnUpdate", function()
        if not next(UnitFrames.PendingUpdates) then return end

        for frame, flags in pairs(UnitFrames.PendingUpdates) do
            if ValUI_UFUnlocked then
                -- Do nothing
            elseif UnitExists(frame.vUnit) then
                if flags.all or flags.name then UpdateUnitName(frame) end
                if flags.all or flags.health then UpdateUnitHealth(frame) end
                if flags.all or flags.power then UpdateUnitPower(frame) end
                if flags.all or flags.portrait then UpdateUnitPortrait(frame) end
                if flags.all or flags.fluff then UpdateFluffIcons(frame) end
                if flags.all or flags.aura then UpdateUnitAuras(frame) end
                if flags.all or flags.threat then UpdateUnitThreat(frame) end

                if flags.all then
                    if UnitCastingInfo(frame.vUnit) then
                        StartCast(frame, frame.vUnit)
                    elseif UnitChannelInfo(frame.vUnit) then
                        StartChannel(frame, frame.vUnit)
                    else
                        StopCast(frame)
                    end
                end
            else
                if frame.vUnit ~= "player" then
                    frame.NameText:SetText("")
                    frame.HealthText:SetText("")
                    frame.HealthBar:SetValue(0)
                    frame.PowerBar:SetValue(0)
                    if frame.Portrait and frame.Portrait.ClearModel then frame.Portrait:ClearModel() end
                    frame.ClassIcon:Hide()
                    frame.StatusIcon:Hide()
                    if frame.RoleIcon then frame.RoleIcon:Hide() end
                    if frame.LeaderIcon then frame.LeaderIcon:Hide() end
                    if frame.LootIcon then frame.LootIcon:Hide() end
                    if frame.HealTex then frame.HealTex:Hide() end
                    if frame.AbsorbTex then frame.AbsorbTex:Hide() end
                    frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
                    StopCast(frame)
                    if frame.Auras then
                        for _, btn in ipairs(frame.Auras) do btn:Hide() end
                    end
                end
            end
            UnitFrames.PendingUpdates[frame] = nil
        end
    end)

    for _, frame in ipairs(ActiveValorianFrames) do
        UnitFrames.PendingUpdates[frame] = { all = true }
    end
end
