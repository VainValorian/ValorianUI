-- ==========================================
-- VALORIAN UI: STATUS TRACKING BARS (EXP/REP)
-- ==========================================
local addonName, ns = ...
local StatusBars = ns.Engine:NewModule("StatusBars")

-- ==========================================
-- 1. STATUS BAR SKINNING
-- ==========================================
local function SkinStatusBars()
    if ns.db.enableSBSkinning == false then return end
    if not MainStatusTrackingBarContainer then return end

    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

    local barTexName = ns.db.statusBarTexture or "Minimalist"
    local safeTex = (LSM and LSM:Fetch("statusbar", barTexName)) or "Interface\\TargetingFrame\\UI-StatusBar"
    local borderTexName = ns.db.statusBorderTexture or "Blizzard Tooltip"
    local borderPath = (LSM and LSM:Fetch("border", borderTexName)) or "Interface\\Tooltips\\UI-Tooltip-Border"
    local borderOffset = ns.db.statusBorderOffset or 2

    local customWidth = ns.db.statusWidth or 580
    local customHeight = ns.db.statusHeight or 14

    if MainStatusTrackingBarContainer.BarFrameTexture then MainStatusTrackingBarContainer.BarFrameTexture:SetAlpha(0) end
    if MainStatusTrackingBarContainer.BarFrameMask then MainStatusTrackingBarContainer.BarFrameMask:SetAlpha(0) end

    local inCombat = InCombatLockdown()
    if not inCombat then
        MainStatusTrackingBarContainer:SetWidth(customWidth)
    end

    for i = 1, MainStatusTrackingBarContainer:GetNumChildren() do
        local bar = select(i, MainStatusTrackingBarContainer:GetChildren())
        if bar.StatusBar then
            local statusBar = bar.StatusBar

            -- Dimension Override Hooks
            if not bar.isValorianSizeHooked then
                hooksecurefunc(bar, "SetWidth", function(self, w)
                    if self.ignoreWidth or InCombatLockdown() then return end
                    local targetW = ns.db.statusWidth or 580
                    if w ~= targetW then
                        self.ignoreWidth = true
                        self:SetWidth(targetW)
                        self.ignoreWidth = false
                    end
                end)
                hooksecurefunc(statusBar, "SetWidth", function(self, w)
                    if self.ignoreWidth or InCombatLockdown() then return end
                    local targetW = ns.db.statusWidth or 580
                    if w ~= targetW then
                        self.ignoreWidth = true
                        self:SetWidth(targetW)
                        self.ignoreWidth = false
                    end
                end)
                bar.isValorianSizeHooked = true
            end

            if not inCombat then
                bar.ignoreWidth = true
                bar:SetWidth(customWidth)
                bar:SetHeight(customHeight)
                bar.ignoreWidth = false

                statusBar.ignoreWidth = true
                statusBar:SetWidth(customWidth)
                statusBar:SetHeight(customHeight)
                statusBar.ignoreWidth = false
            end

            -- Custom Texture & Desaturation Hooks
            if not statusBar.isValorianSkinned then
                statusBar:SetStatusBarTexture(safeTex)
                if statusBar:GetStatusBarTexture() then statusBar:GetStatusBarTexture():SetDesaturated(true) end

                if statusBar.Background then
                    statusBar.Background:SetTexture(safeTex)
                    statusBar.Background:SetVertexColor(0.1, 0.1, 0.1, 0.8)
                end

                hooksecurefunc(statusBar, "SetStatusBarTexture", function(self, tex)
                    if self.ignoreTextureHook then return end
                    self.ignoreTextureHook = true
                    self:SetStatusBarTexture(safeTex)
                    if self:GetStatusBarTexture() then self:GetStatusBarTexture():SetDesaturated(true) end
                    self.ignoreTextureHook = false
                end)

                statusBar.isValorianSkinned = true
            end

            -- Dynamic Color Engine Hooks
            local function GetBarColor(b)
                local barName = b:GetName() or ""

                if b.factionID or string.find(barName, "Reputation") then
                    return ns.db.sbRepColor or { r = 0.2, g = 0.6, b = 0.8 }
                end

                if b.honor or b.isHonor or string.find(barName, "Honor") then
                    return ns.db.sbHonorColor or { r = 0.8, g = 0.2, b = 0.2 }
                end

                return ns.db.sbExpColor or { r = 0.5, g = 0.2, b = 0.8 }
            end

            if not statusBar.isValorianColorHooked then
                hooksecurefunc(statusBar, "SetStatusBarColor", function(self, r, g, b)
                    if self.ignoreColorHook then return end

                    local parent = self:GetParent()
                    local c = GetBarColor(parent)

                    self.ignoreColorHook = true
                    if self:GetStatusBarTexture() then self:GetStatusBarTexture():SetDesaturated(true) end
                    self:SetStatusBarColor(c.r, c.g, c.b)
                    self.ignoreColorHook = false
                end)
                statusBar.isValorianColorHooked = true
            end

            local activeColor = GetBarColor(bar)
            statusBar.ignoreColorHook = true
            if statusBar:GetStatusBarTexture() then statusBar:GetStatusBarTexture():SetDesaturated(true) end
            statusBar:SetStatusBarColor(activeColor.r, activeColor.g, activeColor.b)
            statusBar.ignoreColorHook = false

            -- Text & Art Enhancement Hooks
            if bar.OverlayFrame then
                for rIdx = 1, bar.OverlayFrame:GetNumRegions() do
                    local region = select(rIdx, bar.OverlayFrame:GetRegions())
                    if region:IsObjectType("Texture") then
                        region:SetAlpha(0)
                    elseif region:IsObjectType("FontString") and not region.isValorianSkinned then
                        local fontPath, fontSize = region:GetFont()
                        if fontPath and fontSize then
                            region:SetFont(fontPath, fontSize, "OUTLINE")
                            region:SetShadowColor(0, 0, 0, 1)
                            region:SetShadowOffset(1, -1)
                        end
                        region.isValorianSkinned = true
                    end
                end
            end

            -- Valorian Border Injection
            if not statusBar.ValorianBorder then
                statusBar.ValorianBorder = CreateFrame("Frame", nil, statusBar, "BackdropTemplate")
                statusBar.ValorianBorder:SetFrameLevel(statusBar:GetFrameLevel() + 2)
            end

            if statusBar.currentValorianBorder ~= borderTexName or statusBar.currentValorianOffset ~= borderOffset or statusBar.currentValorianWidth ~= customWidth then
                statusBar.ValorianBorder:ClearAllPoints()
                statusBar.ValorianBorder:SetPoint("TOPLEFT", statusBar, "TOPLEFT", -borderOffset, borderOffset)
                statusBar.ValorianBorder:SetPoint("BOTTOMRIGHT", statusBar, "BOTTOMRIGHT", borderOffset, -borderOffset)

                statusBar.ValorianBorder:SetBackdrop({
                    edgeFile = borderPath,
                    edgeSize = 10,
                })
                statusBar.ValorianBorder:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

                statusBar.currentValorianBorder = borderTexName
                statusBar.currentValorianOffset = borderOffset
                statusBar.currentValorianWidth = customWidth
            end
        end
    end
end

-- ==========================================
-- 2. MODULE ENABLE & EVENT LOOP
-- ==========================================
function StatusBars:OnEnable()
    if StatusTrackingBarManager and StatusTrackingBarManager.UpdateBarsShown then
        hooksecurefunc(StatusTrackingBarManager, "UpdateBarsShown", SkinStatusBars)
    end

    SkinStatusBars()
    C_Timer.After(0.1, SkinStatusBars)

    self.Watcher = CreateFrame("Frame")
    local timer = 0
    self.Watcher:SetScript("OnUpdate", function(_, elapsed)
        timer = timer + elapsed
        if timer > 0.5 then
            if MainStatusTrackingBarContainer and MainStatusTrackingBarContainer:IsShown() then
                local currentChildren = MainStatusTrackingBarContainer:GetNumChildren()
                -- Only skin if Blizzard generated a new tracking bar!
                if MainStatusTrackingBarContainer.lastChildCount ~= currentChildren then
                    SkinStatusBars()
                    MainStatusTrackingBarContainer.lastChildCount = currentChildren
                end
            end
            timer = 0
        end
    end)
end
