-- ==========================================
-- VALORIAN UI: MIDNIGHT DAMAGE METER SKIN
-- ==========================================
local addonName, ns = ...
local DamageMeter = ns.Engine:NewModule("DamageMeter")

local PATH_CLASS_ICONS = "Interface\\AddOns\\ValorianUI\\Media\\ClassIcons.tga"

local ValorianAtlasMap = {
    -- { Left, Right, Top, Bottom }
    ["WARRIOR"]     = { 0.00, 0.25, 0.00, 0.25 },
    ["PALADIN"]     = { 0.25, 0.50, 0.00, 0.25 },
    ["HUNTER"]      = { 0.50, 0.75, 0.00, 0.25 },
    ["ROGUE"]       = { 0.75, 1.00, 0.00, 0.25 },

    ["PRIEST"]      = { 0.00, 0.25, 0.25, 0.50 },
    ["DEATHKNIGHT"] = { 0.25, 0.50, 0.25, 0.50 },
    ["SHAMAN"]      = { 0.50, 0.75, 0.25, 0.50 },
    ["MAGE"]        = { 0.75, 1.00, 0.25, 0.50 },

    ["WARLOCK"]     = { 0.00, 0.25, 0.50, 0.75 },
    ["MONK"]        = { 0.25, 0.50, 0.50, 0.75 },
    ["DRUID"]       = { 0.50, 0.75, 0.50, 0.75 },
    ["DEMONHUNTER"] = { 0.75, 1.00, 0.50, 0.75 },

    ["EVOKER"]      = { 0.00, 0.25, 0.75, 1.00 },
}

-- ==========================================
-- 1. BAR & ICON SKINNING LOGIC
-- ==========================================
local function SkinMeterBars(parent)
    if ns.db.enableDMSkinning == false then return end
    if not parent then return end

    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

    -- Main Bar Textures
    local barTexName = ns.db.meterBarTexture or "Minimalist"
    local safeTex = (LSM and LSM:Fetch("statusbar", barTexName)) or "Interface\\TargetingFrame\\UI-StatusBar"
    local borderTexName = ns.db.meterBorderTexture or "Blizzard Tooltip"
    local borderPath = (LSM and LSM:Fetch("border", borderTexName)) or "Interface\\Tooltips\\UI-Tooltip-Border"
    local borderOffset = ns.db.meterBorderOffset or 2

    -- Icon Specific Textures
    local iconBorderTexName = ns.db.meterIconBorderTexture or "Blizzard Tooltip"
    local iconBorderPath = (LSM and LSM:Fetch("border", iconBorderTexName)) or "Interface\\Tooltips\\UI-Tooltip-Border"
    local iconBorderOffset = ns.db.meterIconBorderOffset or 1

    for i = 1, parent:GetNumChildren() do
        local child = select(i, parent:GetChildren())

        if child:GetObjectType() == "StatusBar" then
            local row = child:GetParent()

            -- =======================================
            -- A. VALORIAN ICON ENHANCER
            -- =======================================
            if row and row.Icon then
                -- Locate the actual texture object
                local actualIconTexture = nil
                if row.Icon.Texture and row.Icon.Texture:GetObjectType() == "Texture" then
                    actualIconTexture = row.Icon.Texture
                elseif row.Icon.icon and row.Icon.icon:GetObjectType() == "Texture" then
                    actualIconTexture = row.Icon.icon
                else
                    for rIdx = 1, row.Icon:GetNumRegions() do
                        local region = select(rIdx, row.Icon:GetRegions())
                        if region:GetObjectType() == "Texture" then
                            actualIconTexture = region
                            break
                        end
                    end
                end

                if actualIconTexture then
                    -- 1. Atlas & Texture Hijack
                    if not actualIconTexture.isValorianAtlasHooked then
                        local function HandleValorianIcon(self)
                            if self.ignoreValorian then return end

                            if ns.db.meterCustomIcons ~= false then
                                local classKey = row.classFilename
                                if classKey and ValorianAtlasMap[classKey] then
                                    self.ignoreValorian = true
                                    self:SetTexture(PATH_CLASS_ICONS)
                                    local c = ValorianAtlasMap[classKey]
                                    self:SetTexCoord(c[1], c[2], c[3], c[4])
                                    self.ignoreValorian = false
                                end
                            else
                                self.ignoreValorian = true
                                self:SetTexCoord(0, 1, 0, 1)
                                self.ignoreValorian = false
                            end
                        end

                        hooksecurefunc(actualIconTexture, "SetTexture", HandleValorianIcon)
                        if actualIconTexture.SetAtlas then
                            hooksecurefunc(actualIconTexture, "SetAtlas", HandleValorianIcon)
                        end

                        actualIconTexture.isValorianAtlasHooked = true
                        HandleValorianIcon(actualIconTexture)
                    end

                    -- 2. Dynamic Icon Border (Aggressive Flush)
                    if ns.db.meterIconBorders ~= false then
                        if not row.ValorianIconBorder then
                            row.ValorianIconBorder = CreateFrame("Frame", nil, row.Icon, "BackdropTemplate")
                            row.ValorianIconBorder:SetFrameLevel(row.Icon:GetFrameLevel() + 2)
                        end

                        if row.currentIconBorderTex ~= iconBorderTexName or row.currentIconBorderOffset ~= iconBorderOffset then
                            row.ValorianIconBorder:SetBackdrop(nil) -- Force flush the old border out of memory

                            row.ValorianIconBorder:ClearAllPoints()
                            row.ValorianIconBorder:SetPoint("TOPLEFT", actualIconTexture, "TOPLEFT", -iconBorderOffset,
                                iconBorderOffset)
                            row.ValorianIconBorder:SetPoint("BOTTOMRIGHT", actualIconTexture, "BOTTOMRIGHT",
                                iconBorderOffset, -iconBorderOffset)

                            row.ValorianIconBorder:SetBackdrop({
                                edgeFile = iconBorderPath,
                                edgeSize = 10,
                            })
                            row.ValorianIconBorder:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

                            row.currentIconBorderTex = iconBorderTexName
                            row.currentIconBorderOffset = iconBorderOffset
                        end
                        -- Ensure anchoring survives ScrollBox recycling
                        row.ValorianIconBorder:ClearAllPoints()
                        row.ValorianIconBorder:SetPoint("TOPLEFT", actualIconTexture, "TOPLEFT", -iconBorderOffset,
                            iconBorderOffset)
                        row.ValorianIconBorder:SetPoint("BOTTOMRIGHT", actualIconTexture, "BOTTOMRIGHT", iconBorderOffset,
                            -iconBorderOffset)
                        row.ValorianIconBorder:Show()
                    else
                        if row.ValorianIconBorder then
                            row.ValorianIconBorder:Hide()
                        end
                    end
                end
            end

            -- =======================================
            -- B. STATUS BAR SKINNING (Aggressive Flush)
            -- =======================================
            if not child.isValorianSkinned then
                child:SetStatusBarTexture(safeTex)

                hooksecurefunc(child, "SetStatusBarTexture", function(self, tex)
                    if self.ignoreTextureHook then return end
                    self.ignoreTextureHook = true
                    self:SetStatusBarTexture(safeTex)
                    self.ignoreTextureHook = false
                end)

                for rIdx = 1, child:GetNumRegions() do
                    local region = select(rIdx, child:GetRegions())
                    if region:GetObjectType() == "FontString" then
                        local fontPath, fontSize = region:GetFont()
                        if fontPath and fontSize then
                            region:SetFont(fontPath, fontSize, "OUTLINE")
                            region:SetShadowColor(0, 0, 0, 1)
                            region:SetShadowOffset(1, -1)
                        end
                    end
                end
                child.isValorianSkinned = true
            end

            if not child.ValorianBorder then
                child.ValorianBorder = CreateFrame("Frame", nil, child, "BackdropTemplate")
                child.ValorianBorder:SetFrameLevel(child:GetFrameLevel() + 1)
            end

            if child.currentValorianBorder ~= borderTexName or child.currentValorianOffset ~= borderOffset then
                child.ValorianBorder:SetBackdrop(nil) -- Force flush the old border out of memory

                child.ValorianBorder:ClearAllPoints()
                child.ValorianBorder:SetPoint("TOPLEFT", child, "TOPLEFT", -borderOffset, borderOffset)
                child.ValorianBorder:SetPoint("BOTTOMRIGHT", child, "BOTTOMRIGHT", borderOffset, -borderOffset)

                child.ValorianBorder:SetBackdrop({
                    edgeFile = borderPath,
                    edgeSize = 10,
                })
                child.ValorianBorder:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

                child.currentValorianBorder = borderTexName
                child.currentValorianOffset = borderOffset
            end
        end
        SkinMeterBars(child)
    end
end

-- ==========================================
-- 2. HEADER SECURE TEXT HOOK
-- ==========================================
local function SecureHeaderText(fontString)
    if ns.db.enableDMSkinning == false then return end
    if not fontString or fontString.isValorianHookedText then return end

    hooksecurefunc(fontString, "SetTextColor", function(self)
        if self.ignoreColorHook then return end
        self.ignoreColorHook = true
        self:SetTextColor(0.8, 0.8, 0.8, 1)
        self.ignoreColorHook = false
    end)

    fontString.ignoreColorHook = true
    fontString:SetTextColor(0.8, 0.8, 0.8, 1)
    fontString:SetShadowColor(0, 0, 0, 1)
    fontString:SetShadowOffset(1, -1)
    fontString.ignoreColorHook = false

    fontString.isValorianHookedText = true
end

-- ==========================================
-- 3. MASTER FRAME SKINNING
-- ==========================================
local function SkinMeterFrame()
    local dm = DamageMeterSessionWindow1
    if not dm then return end

    if not dm.isValorianSkinned then
        if dm.NineSlice then dm.NineSlice:SetAlpha(0) end

        if dm.Background then
            hooksecurefunc(dm.Background, "SetVertexColor", function(self, r, g, b, a)
                if self.ignoreColorHook then return end
                self.ignoreColorHook = true
                self:SetVertexColor(0, 0, 0, a)
                self.ignoreColorHook = false
            end)

            local _, _, _, a = dm.Background:GetVertexColor()
            dm.Background.ignoreColorHook = true
            dm.Background:SetVertexColor(0, 0, 0, a)
            dm.Background.ignoreColorHook = false
        end

        for i = 1, dm:GetNumRegions() do
            local region = select(i, dm:GetRegions())
            if region:IsObjectType("Texture") and region ~= dm.Background then
                region:SetAlpha(0)
            end
        end

        if dm.TypeName then SecureHeaderText(dm.TypeName) end
        if dm.TitleText then SecureHeaderText(dm.TitleText) end

        local buttons = { dm.DamageMeterTypeDropdown, dm.SessionDropdown, dm.SettingsDropdown, dm.CloseButton }
        for _, btn in pairs(buttons) do
            if btn then
                for rIdx = 1, btn:GetNumRegions() do
                    local region = select(rIdx, btn:GetRegions())
                    if region:GetObjectType() == "Texture" then
                        region:SetDesaturated(true)
                        region:SetVertexColor(0.7, 0.7, 0.7)
                    elseif region:GetObjectType() == "FontString" then
                        SecureHeaderText(region)
                    end
                end
                if btn.GetNormalTexture and btn:GetNormalTexture() then
                    btn:GetNormalTexture():SetDesaturated(true)
                    btn:GetNormalTexture():SetVertexColor(0.7, 0.7, 0.7)
                end
                if btn.GetPushedTexture and btn:GetPushedTexture() then
                    btn:GetPushedTexture():SetDesaturated(true)
                    btn:GetPushedTexture():SetVertexColor(0.4, 0.4, 0.4)
                end
            end
        end

        dm.isValorianSkinned = true
    end
end

-- ==========================================
-- 4. DYNAMIC MOUSEOVER HEADER ENGINE
-- ==========================================
local function HandleHeaderHover()
    if ns.db.enableDMSkinning == false then return end
    local dm = DamageMeterSessionWindow1
    if not dm then return end

    local isHovered = dm:IsMouseOver()
    if DropDownList1 and DropDownList1:IsShown() and DropDownList1:IsMouseOver() then isHovered = true end
    if DropDownList2 and DropDownList2:IsShown() and DropDownList2:IsMouseOver() then isHovered = true end

    if dm.currentHeaderState ~= isHovered then
        local function ToggleElement(el, state)
            if not el then return end
            if state then
                el:SetAlpha(1)
                el:Show()
            else
                el:Hide()
            end
        end

        ToggleElement(dm.DamageMeterTypeDropdown, isHovered)
        ToggleElement(dm.SessionDropdown, isHovered)
        ToggleElement(dm.SettingsDropdown, isHovered)
        ToggleElement(dm.CloseButton, isHovered)
        ToggleElement(dm.TypeName, isHovered)
        ToggleElement(dm.TitleText, isHovered)

        dm.currentHeaderState = isHovered
    end
end

-- ==========================================
-- 5. MODULE ENABLE & EVENTS
-- ==========================================
function DamageMeter:OnEnable()
    self.Watcher = CreateFrame("Frame")
    local timer = 0
    self.Watcher:SetScript("OnUpdate", function(_, elapsed)
        HandleHeaderHover()

        timer = timer + elapsed
        if timer > 0.5 then
            if DamageMeterSessionWindow1 and DamageMeterSessionWindow1:IsShown() then
                SkinMeterFrame()
                -- VALORIAN FIX: CPU Leak Optimization (Child Count Lock)
                local currentChildren = DamageMeterSessionWindow1:GetNumChildren()
                if DamageMeterSessionWindow1.lastChildCount ~= currentChildren then
                    SkinMeterBars(DamageMeterSessionWindow1)
                    DamageMeterSessionWindow1.lastChildCount = currentChildren
                end
            end
            timer = 0
        end
    end)

    self.Events = CreateFrame("Frame")
    self.Events:RegisterEvent("PLAYER_REGEN_DISABLED")
    self.Events:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            if ns.db.meterAutoResetOpenWorld then
                local inInstance, _ = IsInInstance()
                if not inInstance then
                    C_Timer.After(0.2, function()
                        if C_DamageMeter and C_DamageMeter.ResetAllCombatSessions then
                            pcall(function() C_DamageMeter.ResetAllCombatSessions() end)
                        end
                    end)
                end
            end
        end
    end)
end
