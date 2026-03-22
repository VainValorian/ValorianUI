-- ==========================================
-- VALORIAN UI: TOOLTIPS ENGINE
-- ==========================================
local addonName, ns = ...
local Tooltips = ns.Engine:NewModule("Tooltips")

local issecretvalue = issecretvalue or function() return false end
local function canaccessvalue(v)
    return v ~= nil and not issecretvalue(v)
end

-- ==========================================
-- 1. INSPECT CACHE ENGINE (ZERO OVERHEAD)
-- ==========================================
local InspectCache = {}
local currentInspectGUID = nil

local inspectFrame = CreateFrame("Frame")
inspectFrame:RegisterEvent("INSPECT_READY")
inspectFrame:SetScript("OnEvent", function(self, event, guid)
    if currentInspectGUID and canaccessvalue(guid) and currentInspectGUID == guid then
        local unit = "mouseover"

        if UnitExists(unit) and UnitGUID(unit) == guid then
            local ilvl = C_PaperDollInfo.GetInspectItemLevel(unit)
            local specID = GetInspectSpecialization(unit)
            local specName, specIcon = "", nil

            if specID and specID > 0 then
                _, specName, _, specIcon = GetSpecializationInfoByID(specID)
            end

            InspectCache[guid] = {
                ilvl = (ilvl and ilvl > 0) and math.floor(ilvl) or nil,
                specName = specName,
                specIcon = specIcon,
                time = GetTime()
            }

            GameTooltip:SetUnit(unit)
        end
        ClearInspectPlayer()
        currentInspectGUID = nil
    end
end)

-- ==========================================
-- 2. SAFE BACKDROP ENGINE (STATIC GEOMETRY)
-- ==========================================
local function ApplySafeBackdrop(frame, edgeFile, edgeSize, bgAlpha, insets)
    if not frame.borders then
        frame.borders = {}
        local pieces = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "TopEdge",
            "BottomEdge", "LeftEdge", "RightEdge" }
        for _, p in ipairs(pieces) do
            local tex = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
            frame[p] = tex
            table.insert(frame.borders, tex)
        end
        frame.bg = frame:CreateTexture(nil, "BACKGROUND", nil, -7)

        frame.TopLeftCorner:SetPoint("TOPLEFT")
        frame.TopRightCorner:SetPoint("TOPRIGHT")
        frame.BottomLeftCorner:SetPoint("BOTTOMLEFT")
        frame.BottomRightCorner:SetPoint("BOTTOMRIGHT")

        frame.TopEdge:SetPoint("TOPLEFT", frame.TopLeftCorner, "TOPRIGHT")
        frame.TopEdge:SetPoint("BOTTOMRIGHT", frame.TopRightCorner, "BOTTOMLEFT")

        frame.BottomEdge:SetPoint("TOPLEFT", frame.BottomLeftCorner, "TOPRIGHT")
        frame.BottomEdge:SetPoint("BOTTOMRIGHT", frame.BottomRightCorner, "BOTTOMLEFT")

        frame.LeftEdge:SetPoint("TOPLEFT", frame.TopLeftCorner, "BOTTOMLEFT")
        frame.LeftEdge:SetPoint("BOTTOMRIGHT", frame.BottomLeftCorner, "TOPRIGHT")

        frame.RightEdge:SetPoint("TOPLEFT", frame.TopRightCorner, "BOTTOMLEFT")
        frame.RightEdge:SetPoint("BOTTOMRIGHT", frame.BottomRightCorner, "TOPRIGHT")
    end

    local s = edgeSize
    for _, tex in ipairs(frame.borders) do
        tex:SetTexture(edgeFile)
        tex:SetVertexColor(0.4, 0.4, 0.4, 1)
    end

    frame.TopLeftCorner:SetSize(s, s); frame.TopLeftCorner:SetTexCoord(0.5, 0.625, 0, 1)
    frame.TopRightCorner:SetSize(s, s); frame.TopRightCorner:SetTexCoord(0.625, 0.75, 0, 1)
    frame.BottomLeftCorner:SetSize(s, s); frame.BottomLeftCorner:SetTexCoord(0.75, 0.875, 0, 1)
    frame.BottomRightCorner:SetSize(s, s); frame.BottomRightCorner:SetTexCoord(0.875, 1, 0, 1)

    frame.LeftEdge:SetTexCoord(0, 0.125, 0, 1)
    frame.RightEdge:SetTexCoord(0.125, 0.25, 0, 1)

    -- PERFECT 8-POINT MAPPING: Forces a 90-degree Counter-Clockwise rotation natively
    frame.TopEdge:SetTexCoord(0.25, 1, 0.375, 1, 0.25, 0, 0.375, 0)
    frame.BottomEdge:SetTexCoord(0.375, 1, 0.5, 1, 0.375, 0, 0.5, 0)

    insets = insets or 3
    frame.bg:SetPoint("TOPLEFT", insets, -insets)
    frame.bg:SetPoint("BOTTOMRIGHT", -insets, insets)

    if bgAlpha > 0 then
        frame.bg:SetColorTexture(0.05, 0.05, 0.05, bgAlpha)
    else
        frame.bg:SetColorTexture(0, 0, 0, 0)
    end
end

-- ==========================================
-- 3. TOOLTIP SCALING ENGINE (TAINT-FREE)
-- ==========================================
function Tooltips:UpdateFonts()
    local bSize = ns.db.tooltipBodySize or 13
    local scaleMult = math.max(0.5, bSize / 13.0)

    local nativeTooltips = { GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2 }
    for _, tt in ipairs(nativeTooltips) do
        tt:SetScale(scaleMult)
    end
end

-- ==========================================
-- 4. SKINNING LOGIC (LAYOUT IMMUNITY)
-- ==========================================
local function SkinTooltip(tt)
    if not tt or tt.isValorianSkinned then return end

    -- Parent to UIParent so it escapes the Tooltip Layout Engine entirely!
    local bg = CreateFrame("Frame", nil, UIParent)
    bg:SetFrameStrata("TOOLTIP")

    -- Glue the frame dynamically behind the tooltip ONLY while it's active
    bg:SetScript("OnUpdate", function(self)
        self:SetFrameLevel(math.max(0, tt:GetFrameLevel() - 1))
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", tt, "TOPLEFT", -4, 4)
        self:SetPoint("BOTTOMRIGHT", tt, "BOTTOMRIGHT", 4, -4)
    end)

    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local borderPath = (LSM and LSM:Fetch("border", ns.db.tooltipBorderTexture or "Blizzard Tooltip")) or
    "Interface\\Tooltips\\UI-Tooltip-Border"

    ApplySafeBackdrop(bg, borderPath, 14, ns.db.tooltipBgAlpha or 0.95, 3)

    tt.ValorianBG = bg
    tt.isValorianSkinned = true

    -- Wake up the background frame when the tooltip shows
    tt:HookScript("OnShow", function(self)
        local bSize = ns.db.tooltipBodySize or 13
        self:SetScale(math.max(0.5, bSize / 13.0))
        if self.NineSlice then self.NineSlice:SetAlpha(0) end
        if self.TopOverlay then self.TopOverlay:SetAlpha(0) end
        if self.BottomOverlay then self.BottomOverlay:SetAlpha(0) end
        if self.SetBackdropColor then self:SetBackdropColor(0, 0, 0, 0) end
        if self.SetBackdropBorderColor then self:SetBackdropBorderColor(0, 0, 0, 0) end

        if self.ValorianBG then
            self.ValorianBG:Show()
            if self.ValorianBG.bg then
                self.ValorianBG.bg:SetColorTexture(0.05, 0.05, 0.05, ns.db.tooltipBgAlpha or 0.95)
            end
        end
    end)

    -- Put the background frame to sleep when the tooltip hides
    tt:HookScript("OnHide", function(self)
        if self.ValorianBG then
            self.ValorianBG:Hide()
        end
    end)

    -- Initialize state correctly
    if not tt:IsShown() then bg:Hide() end
end

local function SkinTooltipStatusBar()
    local bar = GameTooltipStatusBar
    if not bar or bar.isValorianSkinned then return end

    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local texPath = (LSM and LSM:Fetch("statusbar", ns.db.tooltipBarTexture or "Minimalist")) or
    "Interface\\TargetingFrame\\UI-StatusBar"

    bar:SetStatusBarTexture(texPath)
    local tex = bar:GetStatusBarTexture()
    if tex then tex:SetDesaturated(true) end

    hooksecurefunc(bar, "SetStatusBarTexture", function(self, texture)
        if self.ignoreTexture then return end
        self.ignoreTexture = true
        self:SetStatusBarTexture(texPath)
        if self:GetStatusBarTexture() then self:GetStatusBarTexture():SetDesaturated(true) end
        self.ignoreTexture = false
    end)

    local bg = CreateFrame("Frame", nil, bar)

    bg.ignoreInLayout = true

    bg:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 2)
    bg:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 2, -2)
    bg:SetFrameLevel(math.max(0, bar:GetFrameLevel() - 1))

    local borderPath = (LSM and LSM:Fetch("border", ns.db.tooltipBorderTexture or "Blizzard Tooltip")) or
    "Interface\\Tooltips\\UI-Tooltip-Border"

    ApplySafeBackdrop(bg, borderPath, 10, 0, 0)

    bar.ValorianBG = bg
    bar:SetHeight(8)

    hooksecurefunc(bar, "Show", function(self)
        if ns.db.tooltipShowHealthBar == false then
            self:SetAlpha(0)
        else
            self:SetAlpha(1)
        end
    end)
    if ns.db.tooltipShowHealthBar == false then bar:SetAlpha(0) end

    bar.isValorianSkinned = true
end

-- ==========================================
-- 5. DATA PROCESSOR (THE HIJACK)
-- ==========================================
local function RGBToHex(c, defaultHex)
    if not c then return defaultHex end
    return string.format("%02x%02x%02x", math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5),
        math.floor(c.b * 255 + 0.5))
end

local function GetUnitClassColor(unit)
    if not unit or not UnitExists(unit) then return "ffffffff" end
    if UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        local color = RAID_CLASS_COLORS[class]
        if color then return color.colorStr end
    else
        local reaction = UnitReaction(unit, "player")
        if reaction then
            if reaction >= 5 then
                return "ff20ff20"
            elseif reaction == 4 then
                return "ffffff00"
            else
                return "ffff2020"
            end
        end
    end
    return "ffffffff"
end

local function ProcessTooltipData(tooltip, data)
    if not tooltip or tooltip ~= GameTooltip then return end
    if not data or not data.guid then return end

    local _, unit = tooltip:GetUnit()
    if not unit or not canaccessvalue(unit) then return end

    local unitExists = UnitExists(unit)
    if not canaccessvalue(unitExists) or not unitExists then return end

    local isPlayer = UnitIsPlayer(unit)

    local guildHex = RGBToHex(ns.db.tooltipGuildColor, "FFD100")
    local rankHex = RGBToHex(ns.db.tooltipGuildRankColor, "A0A0A0")
    local mountHex = RGBToHex(ns.db.tooltipMountColor, "A335EE")
    local targetYouHex = RGBToHex(ns.db.tooltipTargetYouColor, "FF0000")

    local function SetOrAddLine(prefix, fullText)
        for i = 2, tooltip:NumLines() do
            local line = _G[tooltip:GetName() .. "TextLeft" .. i]
            if line and line:GetText() and string.find(line:GetText(), prefix, 1, true) then
                line:SetText(fullText)
                return
            end
        end
        tooltip:AddLine(fullText)
    end

    if isPlayer then
        local rawName = UnitName(unit)
        rawName = canaccessvalue(rawName) and rawName or "Unknown"
        local nameStr = _G["GameTooltipTextLeft1"]
        if nameStr then
            local colorHex = GetUnitClassColor(unit)
            nameStr:SetText("|c" .. colorHex .. rawName .. "|r")
        end

        local guildName, guildRank = GetGuildInfo(unit)
        guildName = canaccessvalue(guildName) and guildName or nil
        guildRank = canaccessvalue(guildRank) and guildRank or nil

        if guildName then
            local guildStr = _G["GameTooltipTextLeft2"]
            if guildStr then
                guildStr:SetText("|cff" ..
                guildHex .. "<" .. guildName .. ">|r |cff" .. rankHex .. (guildRank or "") .. "|r")
            end
        end
    else
        local nameStr = _G["GameTooltipTextLeft1"]
        if nameStr then
            local colorHex = GetUnitClassColor(unit)
            local rawName = UnitName(unit)
            rawName = canaccessvalue(rawName) and rawName or "Unknown"
            nameStr:SetText("|c" .. colorHex .. rawName .. "|r")
        end
    end

    local targetUnit = unit .. "target"
    local targetExists = UnitExists(targetUnit)

    if canaccessvalue(targetExists) and targetExists then
        local targetIsPlayer = UnitIsUnit(targetUnit, "player")
        if canaccessvalue(targetIsPlayer) then
            local targetName = UnitName(targetUnit)
            targetName = canaccessvalue(targetName) and targetName or "Unknown"
            local targetColor = GetUnitClassColor(targetUnit)

            if targetIsPlayer then
                SetOrAddLine("Target:", "Target: |cff" .. targetYouHex .. "> YOU <|r")
            elseif targetName ~= "Unknown" then
                SetOrAddLine("Target:", "Target: |c" .. targetColor .. targetName .. "|r")
            end
        end
    end

    if isPlayer and not UnitIsUnit(unit, "player") then
        local mountName = nil
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            for i = 1, 40 do
                local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
                if not aura then break end
                local mountID = C_MountJournal.GetMountFromSpell(aura.spellId)
                if mountID then
                    mountName = aura.name
                    mountName = canaccessvalue(mountName) and mountName or "Unknown"
                    break
                end
            end
        end
        if mountName and mountName ~= "Unknown" then
            SetOrAddLine("Mount:", "Mount: |cff" .. mountHex .. mountName .. "|r")
        end
    end

    if isPlayer and not UnitIsUnit(unit, "player") then
        local guid = UnitGUID(unit)
        local cached = InspectCache[guid]

        if cached and (GetTime() - cached.time < 300) then
            if cached.specName and cached.specName ~= "" then
                local iconStr = cached.specIcon and ("|T" .. cached.specIcon .. ":14:14:0:0:64:64:4:60:4:60|t ") or ""
                SetOrAddLine("Specialization:", "Specialization: " .. iconStr .. "|cffFFD100" .. cached.specName .. "|r")
            end
            if cached.ilvl then
                SetOrAddLine("Item Level:", "Item Level: |cffFFD100" .. cached.ilvl .. "|r")
            end
        else
            if CanInspect(unit) and not currentInspectGUID then
                currentInspectGUID = guid
                NotifyInspect(unit)
            end
        end
    end
end

-- ==========================================
-- 6. INITIALIZATION
-- ==========================================
function Tooltips:OnInit()
    local anchor = CreateFrame("Frame", "ValorianUI_TooltipAnchor", UIParent)
    anchor:SetSize(200, 40)
    anchor:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -40, 40)

    anchor.dragOverlay = CreateFrame("Frame", nil, anchor)
    anchor.dragOverlay:SetAllPoints()
    anchor.dragOverlay:SetFrameLevel(anchor:GetFrameLevel() + 10)

    local overlayTex = anchor.dragOverlay:CreateTexture(nil, "OVERLAY")
    overlayTex:SetAllPoints()
    overlayTex:SetColorTexture(0, 1, 0, 0.4)

    local txt = anchor.dragOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    txt:SetPoint("CENTER")
    txt:SetText("Tooltip Anchor\n(Drag to Move)")

    anchor.dragOverlay:Hide()

    anchor:SetMovable(true)
    anchor:RegisterForDrag("LeftButton")

    anchor:SetScript("OnDragStart", function(self)
        if ValUI_FramesUnlocked then self:StartMoving() end
    end)
    anchor:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        if not ns.db.frames then ns.db.frames = {} end
        ns.db.frames["ValorianUI_TooltipAnchor"] = {
            point = p,
            relativePoint = rp,
            x = x,
            y = y,
            scale = self:GetScale() or 1
        }
    end)

    if type(ValUI_MovableFrames) == "table" then
        table.insert(ValUI_MovableFrames, "ValorianUI_TooltipAnchor")
    end

    self.Anchor = anchor
end

function Tooltips:OnEnable()
    if ns.db.enableTooltips == false then return end

    local db = ns.db.frames and ns.db.frames["ValorianUI_TooltipAnchor"]
    if db and db.point then
        self.Anchor:ClearAllPoints()
        self.Anchor:SetPoint(db.point, UIParent, db.relativePoint or db.point, db.x, db.y)
    end

    hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
        if ns.db.tooltipAnchorCursor then
            tooltip:SetOwner(parent, "ANCHOR_CURSOR")
        else
            tooltip:SetOwner(parent, "ANCHOR_NONE")
            tooltip:ClearAllPoints()

            local right = self.Anchor:GetRight()
            local bottom = self.Anchor:GetBottom()

            if right and bottom then
                local anchorScale = self.Anchor:GetEffectiveScale()
                local trueRight = right * anchorScale
                local trueBottom = bottom * anchorScale

                local ttScale = tooltip:GetEffectiveScale()

                tooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", trueRight / ttScale, trueBottom / ttScale)
            else
                tooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -40, 40)
            end
        end
    end)

    local nativeTooltips = { GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2 }
    for _, tt in ipairs(nativeTooltips) do
        SkinTooltip(tt)
    end

    SkinTooltipStatusBar()
    self:UpdateFonts()

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, ProcessTooltipData)
end
