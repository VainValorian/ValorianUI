-- ==========================================
-- VALORIAN UI: CORE MODULE
-- ==========================================
local addonName, ns = ...
local Core = ns.Engine:NewModule("Core")

-- ==========================================
-- 1. GLOBALS & HELPER FUNCTIONS
-- ==========================================
ValUI_MovableFrames = {
    "ValorianUIBar1", "ValorianUIBar2",
    "ValorianUIArt_MultiBarBottomRight", "ValorianUIArt_MultiBarRight", "ValorianUIArt_MultiBarLeft",
    "ValorianUIArt_MultiBar5", "ValorianUIArt_MultiBar6", "ValorianUIArt_MultiBar7",
    "ValorianUIChatArt", "ValorianUIDamageArt", "ValorianUISuccubusFrame",
    "ValorianUIHealthOrb", "ValorianUIPowerOrb", "ValorianUIRunes",
    "ValUI_ChatPanel", "ValorianUI_InfoBar"
}
ValUI_FramesUnlocked = false

local function KillFrame(frame)
    if frame then
        frame:Hide()
        frame:UnregisterAllEvents()
        frame.Show = function() end
    end
end

local function DarkenFrameTextures(frame, r, g, b)
    if not frame then return end
    for i = 1, frame:GetNumRegions() do
        local region = select(i, frame:GetRegions())
        if region:IsObjectType("Texture") then
            region:SetVertexColor(r, g, b)
        end
    end
end

local function AddOutline(fontString)
    if fontString then
        local font, size = fontString:GetFont()
        if font then
            fontString:SetFont(font, size, "OUTLINE")
        end
    end
end

local function CenterHeader(header)
    if not header then return end
    if header.Text then
        header.Text:ClearAllPoints()
        header.Text:SetPoint("CENTER", header, "CENTER", 0, 0)
        header.Text:SetJustifyH("CENTER")
    end
    if header.Background then
        header.Background:ClearAllPoints()
        header.Background:SetPoint("CENTER", header, "CENTER", 0, 0)
    end
end

local function TintMinimizeButton(btn)
    if btn and not btn.isValorianTinted then
        for i = 1, btn:GetNumRegions() do
            local region = select(i, btn:GetRegions())
            if region:IsObjectType("Texture") then
                region:SetDesaturated(true)
                region:SetVertexColor(0.5, 0.5, 0.5)
            end
        end
        if btn:GetNormalTexture() then
            btn:GetNormalTexture():SetDesaturated(true)
            btn:GetNormalTexture():SetVertexColor(0.5, 0.5, 0.5)
        end
        if btn:GetPushedTexture() then
            btn:GetPushedTexture():SetDesaturated(true)
            btn:GetPushedTexture():SetVertexColor(0.5, 0.5, 0.5)
        end
        if btn:GetHighlightTexture() then
            btn:GetHighlightTexture():SetDesaturated(true)
            btn:GetHighlightTexture():SetVertexColor(0.5, 0.5, 0.5)
        end
        btn.isValorianTinted = true
    end
end

local function GetTrackerColor()
    if ns.db.trackerClassColor then
        local _, class = UnitClass("player")
        local color = RAID_CLASS_COLORS[class]
        if color then
            return color.r, color.g, color.b
        end
    end
    local c = ns.db.trackerColor
    return c.r, c.g, c.b
end

local function ApplyToggle(setting, frames)
    for _, frameName in ipairs(frames) do
        if _G[frameName] then
            if ns.db[setting] then
                _G[frameName]:Show()
            else
                _G[frameName]:Hide()
            end
        end
    end
end

-- ==========================================
-- 2. MODULE INITIALIZATION
-- ==========================================
function Core:OnInit()
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local activeFontPath = "Interface\\AddOns\\ValorianUI\\Fonts\\BelweBoldBT.ttf"

    if LSM and LSM:Fetch("font", ns.db.fontChoice) then
        activeFontPath = LSM:Fetch("font", ns.db.fontChoice)
    end

    if activeFontPath then
        DAMAGE_TEXT_FONT = activeFontPath
        UNIT_NAME_FONT = activeFontPath
        NAMEPLATE_FONT = activeFontPath
        STANDARD_TEXT_FONT = activeFontPath

        SystemFont_Large:SetFont(activeFontPath, 17, "")
        GameFontNormalHuge:SetFont(activeFontPath, 20, "")
        QuestFont_Enormous:SetFont(activeFontPath, 30, "OUTLINE")

        SystemFont_Shadow_Med1:SetFont(activeFontPath, 12, "")
        GameFontNormal:SetFont(activeFontPath, 12, "")
        GameFontHighlight:SetFont(activeFontPath, 12, "")
        QuestFont:SetFont(activeFontPath, 13, "")

        NumberFontNormalSmall:SetFont(activeFontPath, 11, "OUTLINE")
    end

    local r, g, b = 0.75, 0.75, 0.75
    GameFontNormal:SetTextColor(r, g, b)
    GameFontNormalHuge:SetTextColor(r, g, b)
    SystemFont_Large:SetTextColor(r, g, b)
    QuestFont:SetTextColor(r, g, b)
end

-- ==========================================
-- 3. MODULE ENABLE
-- ==========================================
function Core:OnEnable(isInitialLogin, isReloadingUI)
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
            if ValUI_FramesUnlocked then self:StartMoving() end
        end)
        frame:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            local p, _, rp, x, y = self:GetPoint()
            if not ns.db.frames then ns.db.frames = {} end
            ns.db.frames[self:GetName()] = {
                point = p,
                relativePoint = rp,
                x = x,
                y = y,
                scale = self:GetScale() or 1
            }
        end)
    end

    local bar1 = CreateFrame("Frame", "ValorianUIBar1", UIParent)
    bar1:SetSize(1030, 452)
    bar1:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, -122)
    bar1:SetFrameStrata("BACKGROUND")
    bar1:SetFrameLevel(0)
    local tex1 = bar1:CreateTexture(nil, "BACKGROUND")
    tex1:SetAllPoints(bar1)
    tex1:SetTexture("Interface\\AddOns\\ValorianUI\\Textures\\ActionBars.tga")
    MakeDraggable(bar1, "Main Action Bar Art")

    local bar2 = CreateFrame("Frame", "ValorianUIBar2", UIParent)
    bar2:SetSize(560, 365)
    bar2:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, -30)
    bar2:SetFrameStrata("BACKGROUND")
    bar2:SetFrameLevel(0)
    local tex2 = bar2:CreateTexture(nil, "BACKGROUND")
    tex2:SetAllPoints(bar2)
    tex2:SetTexture("Interface\\AddOns\\ValorianUI\\Textures\\ActionBars.tga")
    MakeDraggable(bar2, "Extra Action Bar Art")

    local mask1 = CreateFrame("Frame", "ValorianUIBar1Mask", bar1)
    mask1:SetSize(652, 55)
    mask1:SetPoint("BOTTOM", bar1, "BOTTOM", 0, 132)
    mask1:SetFrameStrata("BACKGROUND")
    mask1:SetFrameLevel(bar1:GetFrameLevel() + 1)
    local maskTex1 = mask1:CreateTexture(nil, "BACKGROUND")
    maskTex1:SetAllPoints(mask1)
    maskTex1:SetTexture("Interface\\AddOns\\ValorianUI\\Textures\\ActionBarMask.tga")

    local mask2 = CreateFrame("Frame", "ValorianUIBar2Mask", bar2)
    mask2:SetSize(355, 46)
    mask2:SetPoint("BOTTOM", bar2, "BOTTOM", 0, 105)
    mask2:SetFrameStrata("BACKGROUND")
    mask2:SetFrameLevel(bar2:GetFrameLevel() + 1)
    local maskTex2 = mask2:CreateTexture(nil, "BACKGROUND")
    maskTex2:SetAllPoints(mask2)
    maskTex2:SetTexture("Interface\\AddOns\\ValorianUI\\Textures\\ActionBarMask.tga")

    local extraBars = {
        "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft",
        "MultiBar5", "MultiBar6", "MultiBar7"
    }

    ValUI_ModularBarFrames = {}

    for _, barName in ipairs(extraBars) do
        local bar = _G[barName]
        if bar then
            local art = CreateFrame("Frame", "ValorianUIArt_" .. barName, bar)
            art:SetFrameStrata("BACKGROUND")
            art:SetFrameLevel(0)

            local ART_WIDTH = 612
            local ART_HEIGHT = 312
            art:SetSize(ART_WIDTH, ART_HEIGHT)

            local tex = art:CreateTexture(nil, "BACKGROUND")
            tex:SetAllPoints(art)
            tex:SetTexture("Interface\\AddOns\\ValorianUI\\Textures\\ActionBarsExtra.tga")

            art.lastW, art.lastH = -1, -1
            art.lastX, art.lastY = -1, -1

            art:SetScript("OnUpdate", function(self)
                local cx, cy = bar:GetCenter()
                local cw, ch = bar:GetSize()

                if not cx or not cy then return end

                if cw ~= self.lastW or ch ~= self.lastH or cx ~= self.lastX or cy ~= self.lastY then
                    self.lastW, self.lastH = cw, ch
                    self.lastX, self.lastY = cx, cy

                    self:ClearAllPoints()
                    self:SetPoint("CENTER", bar, "CENTER", 0, 0)

                    if ch > cw then
                        tex:SetRotation(math.rad(-90))
                    else
                        tex:SetRotation(0)
                    end
                end
            end)

            table.insert(ValUI_ModularBarFrames, "ValorianUIArt_" .. barName)
        end
    end

    local chatArt = CreateFrame("Frame", "ValorianUIChatArt", UIParent)
    chatArt:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
    chatArt:SetSize(570, 360)
    chatArt:SetFrameStrata("BACKGROUND")
    chatArt:SetFrameLevel(0)
    local chatTex = chatArt:CreateTexture(nil, "BACKGROUND")
    chatTex:SetAllPoints(chatArt)
    chatTex:SetTexture("Interface\\AddOns\\ValorianUI\\Textures\\Chat.tga")
    MakeDraggable(chatArt, "Chat Backdrop Art")

    local damageArt = CreateFrame("Frame", "ValorianUIDamageArt", UIParent)
    damageArt:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
    damageArt:SetSize(570, 360)
    damageArt:SetFrameStrata("BACKGROUND")
    damageArt:SetFrameLevel(0)
    local damageTex = damageArt:CreateTexture(nil, "BACKGROUND")
    damageTex:SetAllPoints(damageArt)
    damageTex:SetTexture("Interface\\AddOns\\ValorianUI\\Textures\\Damage.tga")
    MakeDraggable(damageArt, "Damage Meter Art")

    local SuccubusFrame = CreateFrame("Frame", "ValorianUISuccubusFrame", UIParent)
    SuccubusFrame:SetSize(450, 450)
    SuccubusFrame:SetFrameStrata("BACKGROUND")
    SuccubusFrame:SetFrameLevel(0)
    local SuccubusTexture = SuccubusFrame:CreateTexture(nil, "BACKGROUND")
    SuccubusTexture:SetAllPoints(SuccubusFrame)
    SuccubusTexture:SetTexture("Interface\\AddOns\\ValorianUI\\Textures\\Corner.tga")
    MakeDraggable(SuccubusFrame, "Succubus Art")

    for name, data in pairs(ns.db.frames) do
        if name ~= "ValorianUIBar1Mask" and name ~= "ValorianUIBar2Mask" then
            local f = _G[name]
            if f then
                if data.point then
                    f:ClearAllPoints()
                    f:SetPoint(data.point, UIParent, data.relativePoint, data.x, data.y)
                end
                if data.scale then
                    f:SetScale(data.scale)
                end
            end
        end
    end

    ApplyToggle("showActionBars", { "ValorianUIBar1", "ValorianUIBar2", "ValorianUIBar1Mask", "ValorianUIBar2Mask" })
    ApplyToggle("showExtraActionBars", ValUI_ModularBarFrames)
    ApplyToggle("showChatDamage", { "ValorianUIChatArt", "ValorianUIDamageArt" })
    ApplyToggle("showSuccubus", { "ValorianUISuccubusFrame" })

    if TimeManagerClockButton then KillFrame(TimeManagerClockButton) end
    if GameTimeFrame then KillFrame(GameTimeFrame) end
    if MinimapCluster and MinimapCluster.Tracking then KillFrame(MinimapCluster.Tracking) end
    if MinimapCluster and MinimapCluster.TrackingFrame then KillFrame(MinimapCluster.TrackingFrame) end

    if StatusTrackingBarManager then
        hooksecurefunc(StatusTrackingBarManager, "UpdateBarsShown", function()
            local function DarkenContainer(container)
                if container then
                    DarkenFrameTextures(container, 0.4, 0.4, 0.4)
                    for i = 1, container:GetNumChildren() do
                        local child = select(i, container:GetChildren())
                        DarkenFrameTextures(child, 0.4, 0.4, 0.4)
                    end
                end
            end

            DarkenContainer(MainStatusTrackingBarContainer)
            DarkenContainer(SecondaryStatusTrackingBarContainer)
        end)
    end

    if BuffFrame and BuffFrame.CollapseAndExpandButton then
        local btn = BuffFrame.CollapseAndExpandButton
        for i = 1, btn:GetNumRegions() do
            local region = select(i, btn:GetRegions())
            if region:IsObjectType("Texture") then
                region:SetDesaturated(true)
                region:SetVertexColor(0.2, 0.2, 0.2)
            end
        end
        if btn:GetNormalTexture() then
            btn:GetNormalTexture():SetDesaturated(true)
            btn:GetNormalTexture():SetVertexColor(0.2, 0.2, 0.2)
        end
        if btn:GetPushedTexture() then
            btn:GetPushedTexture():SetDesaturated(true)
            btn:GetPushedTexture():SetVertexColor(0.2, 0.2, 0.2)
        end
    end

    local microButtons = {
        "CharacterMicroButton", "ProfessionMicroButton", "PlayerSpellsMicroButton",
        "AchievementMicroButton", "QuestLogMicroButton", "GuildMicroButton",
        "LFDMicroButton", "CollectionsMicroButton", "EJMicroButton",
        "StoreMicroButton", "MainMenuMicroButton", "HousingMicroButton"
    }

    local function DarkenMicroButtons()
        for _, btnName in ipairs(microButtons) do
            local btn = _G[btnName]
            if btn then
                for i = 1, btn:GetNumRegions() do
                    local region = select(i, btn:GetRegions())
                    if region:IsObjectType("Texture") then
                        region:SetDesaturated(true)
                        region:SetVertexColor(0.5, 0.5, 0.5)
                    end
                end
                if btn:GetNormalTexture() then
                    btn:GetNormalTexture():SetDesaturated(true)
                    btn:GetNormalTexture():SetVertexColor(0.5, 0.5, 0.5)
                end
                if btn:GetPushedTexture() then
                    btn:GetPushedTexture():SetDesaturated(true)
                    btn:GetPushedTexture():SetVertexColor(0.5, 0.5, 0.5)
                end
                if btn:GetDisabledTexture() then
                    btn:GetDisabledTexture():SetDesaturated(true)
                    btn:GetDisabledTexture():SetVertexColor(0.5, 0.5, 0.5)
                end
            end
        end
    end

    DarkenMicroButtons()
    hooksecurefunc("UpdateMicroButtons", DarkenMicroButtons)

    if MicroButtonAndBagsBar and MicroButtonAndBagsBar.MicroBagBar then
        DarkenFrameTextures(MicroButtonAndBagsBar.MicroBagBar, 0.5, 0.5, 0.5)
    end

    if MinimapCluster and MinimapCluster.BorderTop then MinimapCluster.BorderTop:Hide() end
    if Minimap.Backdrop then Minimap.Backdrop:Hide() end
    if MinimapCompassTexture then MinimapCompassTexture:Hide() end
    if MinimapCluster.ZoneTextButton then MinimapCluster.ZoneTextButton:Hide() end

    -- Hide Native Zoom Buttons
    Minimap.ZoomIn:Hide()
    Minimap.ZoomOut:Hide()

    if MinimapCluster then MinimapCluster:SetClampedToScreen(false) end
    Minimap:SetClampedToScreen(false)

    -- Square Masking
    Minimap:SetMaskTexture("Interface\\Buttons\\WHITE8X8")
    function GetMinimapShape() return "SQUARE" end

    -- Custom Valorian Border
    local customMapFrame = CreateFrame("Frame", "ValorianUIMinimapFrame", Minimap)
    customMapFrame:SetAllPoints(Minimap)
    customMapFrame:SetFrameLevel(Minimap:GetFrameLevel() + 5)

    local customBorder = customMapFrame:CreateTexture(nil, "OVERLAY")
    customBorder:SetSize(250, 250)
    customBorder:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
    customBorder:SetTexture("Interface\\AddOns\\ValorianUI\\Textures\\MinimapBorder.tga")

    -- ZERO-CPU Blob Blocker
    if Minimap.SetQuestBlobRingTexture then Minimap:SetQuestBlobRingTexture("empty") end
    if Minimap.SetArchBlobRingTexture then Minimap:SetArchBlobRingTexture("empty") end
    if Minimap.SetTaskBlobRingTexture then Minimap:SetTaskBlobRingTexture("empty") end
    if Minimap.SetQuestBlobRingScalar then Minimap:SetQuestBlobRingScalar(0) end
    if Minimap.SetArchBlobRingScalar then Minimap:SetArchBlobRingScalar(0) end
    if Minimap.SetTaskBlobRingScalar then Minimap:SetTaskBlobRingScalar(0) end

    local hiddenVoid = CreateFrame("Frame")
    hiddenVoid:Hide()
    if Minimap.Ring then Minimap.Ring:SetParent(hiddenVoid) end
    if Minimap.QuestHint then Minimap.QuestHint:SetParent(hiddenVoid) end

    -- ==========================================
    -- FEATURES 1 & 2: ZOOM & TRACKING (ZERO-INTERFERENCE OVERLAY)
    -- ==========================================
    -- Unhook completely from the Minimap parent to escape its C++ hit-rect restrictions
    local mapOverlay = CreateFrame("Button", "ValorianUIMapOverlay", UIParent)
    mapOverlay:SetFrameStrata("HIGH")
    mapOverlay:SetAllPoints(Minimap)
    mapOverlay:RegisterForClicks("RightButtonUp")

    local hitBox = mapOverlay:CreateTexture(nil, "BACKGROUND")
    hitBox:SetAllPoints()
    hitBox:SetColorTexture(0, 0, 0, 0)

    if mapOverlay.SetPassThroughButtons then
        mapOverlay:SetPassThroughButtons("LeftButton", "MiddleButton")
    end

    -- Feature 1: Mousewheel Zoom
    mapOverlay:EnableMouseWheel(true)
    mapOverlay:SetScript("OnMouseWheel", function(self, d)
        if d > 0 then Minimap_ZoomIn() elseif d < 0 then Minimap_ZoomOut() end
    end)

    -- Feature 2: Custom Tracking Menu
    mapOverlay:SetScript("OnClick", function(self, btn)
        if btn == "RightButton" then
            MenuUtil.CreateContextMenu(Minimap, function(owner, rootDescription)
                rootDescription:CreateTitle("Minimap Tracking")
                for i = 1, C_Minimap.GetNumTrackingTypes() do
                    local info = C_Minimap.GetTrackingInfo(i)
                    local name = type(info) == "table" and info.name or select(1, C_Minimap.GetTrackingInfo(i))
                    if name then
                        rootDescription:CreateCheckbox(name,
                            function()
                                local curr = C_Minimap.GetTrackingInfo(i)
                                return type(curr) == "table" and curr.active or select(3, C_Minimap.GetTrackingInfo(i))
                            end,
                            function()
                                local curr = C_Minimap.GetTrackingInfo(i)
                                local isActive = type(curr) == "table" and curr.active or
                                    select(3, C_Minimap.GetTrackingInfo(i))
                                C_Minimap.SetTracking(i, not isActive)
                            end
                        )
                    end
                end
            end)
        end
    end)

    -- Feature 3: Auto-Fading Zone Text
    local zoneText = customMapFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    zoneText:SetPoint("TOP", Minimap, "TOP", 0, -5)
    zoneText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    zoneText:SetTextColor(1, 0.82, 0)
    zoneText:SetAlpha(0)

    customMapFrame:SetScript("OnUpdate", function()
        if Minimap:IsMouseOver() then
            zoneText:SetText(GetMinimapZoneText())
            zoneText:SetAlpha(1)
        else
            zoneText:SetAlpha(0)
        end
    end)

    -- Feature 4: Addon Button Drawer
    local ignoredButtons = {
        ["ValorianUIMapOverlay"] = true,
        ["ValorianUIMinimapFrame"] = true,
        ["ValorianUI_DrawerToggle"] = true,
        ["MiniMapTrackingFrame"] = true,
        ["MiniMapTracking"] = true,
        ["MiniMapMailFrame"] = true,
        ["HelpOpenTicketButton"] = true,
        ["GameTimeFrame"] = true,
        ["TimeManagerClockButton"] = true,
        ["MinimapZoomIn"] = true,
        ["MinimapZoomOut"] = true,
        ["QueueStatusMinimapButton"] = true,
        ["GarrisonLandingPageMinimapButton"] = true,
        ["MiniMapWorldMapButton"] = true,
        ["MiniMapInstanceDifficulty"] = true,
        ["GuildInstanceDifficulty"] = true,
        ["MiniMapChallengeMode"] = true,
    }

    -- 2. Only build and run the vacuum if the user wants it!
    if ns.db.showMinimapDrawer ~= false then
        local drawerToggle = CreateFrame("Button", "ValorianUI_DrawerToggle", UIParent)
        drawerToggle:SetSize(18, 40)
        drawerToggle:SetFrameStrata("HIGH")
        drawerToggle:SetPoint("RIGHT", customMapFrame, "LEFT", 4, 0)

        local toggleText = drawerToggle:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        toggleText:SetPoint("CENTER", -1, 0)
        local tFont, tSize, tFlags = toggleText:GetFont()
        toggleText:SetFont(tFont, 18, "OUTLINE")
        toggleText:SetText("<")
        toggleText:SetTextColor(0.6, 0.6, 0.6, 1)

        drawerToggle:SetScript("OnEnter", function() toggleText:SetTextColor(1, 1, 1, 1) end)
        drawerToggle:SetScript("OnLeave", function() toggleText:SetTextColor(0.6, 0.6, 0.6, 1) end)

        local buttonDrawer = CreateFrame("Frame", "ValorianUI_ButtonDrawer", UIParent, "BackdropTemplate")
        buttonDrawer:SetFrameStrata("HIGH")
        buttonDrawer:SetPoint("RIGHT", drawerToggle, "LEFT", -2, 0)
        buttonDrawer:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        buttonDrawer:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
        buttonDrawer:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        buttonDrawer:Hide()

        drawerToggle:SetScript("OnClick", function()
            if buttonDrawer:IsShown() then
                buttonDrawer:Hide()
                toggleText:SetText("<")
            else
                buttonDrawer:Show()
                toggleText:SetText(">")
            end
        end)

        local collectedButtons = {}

        local function UpdateDrawerLayout()
            local padding = 6
            local btnSize = 30
            local cols = 3

            local numBtns = #collectedButtons
            if numBtns == 0 then return end

            local rows = math.ceil(numBtns / cols)
            local currentCols = math.min(numBtns, cols)

            buttonDrawer:SetSize((currentCols * btnSize) + (padding * (currentCols + 1)),
                (rows * btnSize) + (padding * (rows + 1)))

            for i, btn in ipairs(collectedButtons) do
                local row = math.floor((i - 1) / cols)
                local col = (i - 1) % cols

                btn.isValorianPositioning = true
                btn:ClearAllPoints()
                btn:SetPoint("TOPLEFT", buttonDrawer, "TOPLEFT", padding + (col * (btnSize + padding)),
                    -(padding + (row * (btnSize + padding))))
                btn.isValorianPositioning = false
            end
        end

        local function GrabMinimapButtons()
            for i = 1, Minimap:GetNumChildren() do
                local child = select(i, Minimap:GetChildren())
                local name = child:GetName()
                if child:IsObjectType("Button") and name and not ignoredButtons[name] then
                    if not child.isValorianGrabbed then
                        child.isValorianGrabbed = true
                        child:SetParent(buttonDrawer)
                        child:SetFrameLevel(buttonDrawer:GetFrameLevel() + 5)

                        child:SetScript("OnDragStart", nil)
                        child:SetScript("OnDragStop", nil)
                        child:SetSize(30, 30)

                        hooksecurefunc(child, "SetPoint", function(self)
                            if not self.isValorianPositioning then
                                UpdateDrawerLayout()
                            end
                        end)

                        if child:GetNormalTexture() then child:GetNormalTexture():SetAlpha(0) end
                        if child:GetPushedTexture() then child:GetPushedTexture():SetAlpha(0) end
                        if child:GetHighlightTexture() then child:GetHighlightTexture():SetAlpha(0) end

                        if child.Border then child.Border:SetAlpha(0) end
                        if child.border then child.border:SetAlpha(0) end
                        if child.Background then child.Background:SetAlpha(0) end
                        if child.background then child.background:SetAlpha(0) end

                        for i = 1, child:GetNumRegions() do
                            local region = select(i, child:GetRegions())
                            if region:IsObjectType("Texture") then
                                local tex = region:GetTexture()
                                local texID = type(tex) == "number" and tex or 0
                                local texStr = type(tex) == "string" and tex:lower() or ""

                                local isBorder = false
                                if texID == 136430 or texID == 136467 or texID == 136431 or texID == 136432 or texID == 130924 or texID == 136477 or texID == 136468 then isBorder = true end
                                if string.find(texStr, "border") or string.find(texStr, "minimap%-mask") then isBorder = true end

                                if isBorder then
                                    region:SetAlpha(0)
                                end
                            end
                        end

                        table.insert(collectedButtons, child)
                    end
                end
            end
            UpdateDrawerLayout()
        end

        C_Timer.NewTicker(5, GrabMinimapButtons)
        C_Timer.After(1, GrabMinimapButtons)
    end

    -- 3. Run the Tinter independently so native icons always fit the theme
    local function TintMinimapRings()
        for i = 1, Minimap:GetNumChildren() do
            local child = select(i, Minimap:GetChildren())
            local name = child:GetName()
            if child:IsObjectType("Button") and name and ignoredButtons[name] then
                if not child.isValorianTinted and not child.isValorianGrabbed then
                    local iconTex = child.icon or child.Icon or (name and _G[name .. "Icon"])
                    for rIdx = 1, child:GetNumRegions() do
                        local region = select(rIdx, child:GetRegions())
                        if region:IsObjectType("Texture") and region ~= iconTex then
                            region:SetDesaturated(true)
                            region:SetVertexColor(0.4, 0.4, 0.4)
                        end
                    end
                    child.isValorianTinted = true
                end
            end
        end
    end
    TintMinimapRings()

    if OBJECTIVE_TRACKER_COLOR then
        OBJECTIVE_TRACKER_COLOR["Header"] = CreateColor(0.8, 0.8, 0.8)
        OBJECTIVE_TRACKER_COLOR["HeaderHighlight"] = CreateColor(1.0, 1.0, 1.0)
        OBJECTIVE_TRACKER_COLOR["Normal"] = CreateColor(0.6, 0.6, 0.6)
        OBJECTIVE_TRACKER_COLOR["NormalHighlight"] = CreateColor(1.0, 1.0, 1.0)
        OBJECTIVE_TRACKER_COLOR["Complete"] = CreateColor(0.4, 0.8, 0.4)
    end

    local trackerModules = {
        CampaignQuestObjectiveTracker, QuestObjectiveTracker,
        AchievementObjectiveTracker, BonusObjectiveTracker,
        WorldQuestObjectiveTracker, ScenarioObjectiveTracker,
        MonthlyActivitiesObjectiveTracker
    }

    for _, tracker in ipairs(trackerModules) do
        if tracker then
            hooksecurefunc(tracker, "Update", function(self)
                if self.Header then
                    TintMinimizeButton(self.Header.MinimizeButton)
                    if self.Header.Text then
                        local r2, g2, b2 = GetTrackerColor()
                        self.Header.Text:SetTextColor(r2, g2, b2)
                        AddOutline(self.Header.Text)
                    end
                    if self.Header.Background then
                        self.Header.Background:SetVertexColor(0, 0, 0, 0.6)
                    end
                    CenterHeader(self.Header)
                end

                if self.ContentsFrame then
                    for i = 1, self.ContentsFrame:GetNumChildren() do
                        local block = select(i, self.ContentsFrame:GetChildren())
                        if block.HeaderText then AddOutline(block.HeaderText) end

                        local function StyleTrackerButton(btn)
                            if not btn then return end
                            if btn.Display and btn.Display.Icon then
                                btn.Display.Icon:SetDesaturated(true)
                                btn.Display.Icon:SetVertexColor(0.7, 0.7, 0.7)
                            end
                            if btn.NormalTexture then
                                btn.NormalTexture:SetDesaturated(true)
                                btn.NormalTexture:SetVertexColor(0.5, 0.5, 0.5)
                            end
                            if btn.Icon then
                                btn.Icon:SetDesaturated(true)
                                btn.Icon:SetVertexColor(0.7, 0.7, 0.7)
                            end
                            if btn.icon then
                                btn.icon:SetDesaturated(true)
                                btn.icon:SetVertexColor(0.7, 0.7, 0.7)
                            end
                        end

                        StyleTrackerButton(block.poiButton)
                        StyleTrackerButton(block.ItemButton)
                        StyleTrackerButton(block.RightButton)

                        if block.linesPool then
                            for line in block.linesPool:EnumerateActive() do
                                if line.Text then
                                    if STANDARD_TEXT_FONT then
                                        line.Text:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
                                    else
                                        AddOutline(line.Text)
                                    end
                                    line.Text:SetShadowColor(0, 0, 0, 0)
                                end
                                if line.Icon then
                                    line.Icon:SetDesaturated(true)
                                    line.Icon:SetVertexColor(0.7, 0.7, 0.7)
                                end
                            end
                        end
                    end
                end
            end)
        end
    end

    local function StyleMainHeader()
        if ObjectiveTrackerFrame and ObjectiveTrackerFrame.Header then
            TintMinimizeButton(ObjectiveTrackerFrame.Header.MinimizeButton)
            if ObjectiveTrackerFrame.Header.Text then
                local r3, g3, b3 = GetTrackerColor()
                ObjectiveTrackerFrame.Header.Text:SetTextColor(r3, g3, b3)
                AddOutline(ObjectiveTrackerFrame.Header.Text)
            end
            if ObjectiveTrackerFrame.Header.Background then
                ObjectiveTrackerFrame.Header.Background:SetVertexColor(0, 0, 0, 0.6)
            end
            CenterHeader(ObjectiveTrackerFrame.Header)
        end
    end

    StyleMainHeader()

    if ObjectiveTrackerFrame then
        hooksecurefunc(ObjectiveTrackerFrame, "Update", StyleMainHeader)
    end

    self:SetupVisibilityWatchdog()
end

-- ==========================================
-- 4. MASTER VISIBILITY WATCHDOG
-- ==========================================
function Core:SetupVisibilityWatchdog()
    self.Watchdog = CreateFrame("Frame")

    local framesToToggle = {
        "ValorianUIHealthOrb", "ValorianUIPowerOrb", "ValorianUIRunes",
        "ValorianUIBar1", "ValorianUIBar2", "ValorianUIBar1Mask", "ValorianUIBar2Mask",
        "ValorianUIChatArt", "ValorianUIDamageArt", "ValorianUISuccubusFrame",
        "ValorianUIArt_MultiBarBottomRight", "ValorianUIArt_MultiBarRight",
        "ValorianUIArt_MultiBarLeft", "ValorianUIArt_MultiBar5",
        "ValorianUIArt_MultiBar6", "ValorianUIArt_MultiBar7"
    }

    local function UpdateValorianVisibility()
        local shouldHide = false

        if HasVehicleActionBar() then shouldHide = true end
        if HasOverrideActionBar() then shouldHide = true end
        if C_PetBattles and C_PetBattles.IsInBattle() then shouldHide = true end
        if UnitHasVehicleUI("player") then shouldHide = true end

        local targetAlpha = shouldHide and 0 or 1

        for _, name in ipairs(framesToToggle) do
            if _G[name] then
                _G[name]:SetAlpha(targetAlpha)

                if type(_G[name].EnableMouse) == "function" then
                    local isSecure = (name == "ValorianUIHealthOrb")
                    local canChangeMouse = not (isSecure and InCombatLockdown())

                    if canChangeMouse then
                        if targetAlpha == 0 then
                            _G[name]:EnableMouse(false)
                        else
                            if isSecure then
                                _G[name]:EnableMouse(true)
                            else
                                _G[name]:EnableMouse(ValUI_FramesUnlocked or false)
                            end
                        end
                    end
                end
            end
        end
    end

    self.Watchdog:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")
    self.Watchdog:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR")
    self.Watchdog:RegisterEvent("PET_BATTLE_OPENING_START")
    self.Watchdog:RegisterEvent("PET_BATTLE_CLOSE")
    self.Watchdog:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.Watchdog:RegisterEvent("UNIT_ENTERED_VEHICLE")
    self.Watchdog:RegisterEvent("UNIT_EXITED_VEHICLE")

    self.Watchdog:SetScript("OnEvent", function()
        C_Timer.After(0.1, UpdateValorianVisibility)
    end)
end

-- ==========================================
-- 5. UNIT FRAME COLOR ENFORCER
-- ==========================================
if hooksecurefunc then
    hooksecurefunc("UnitFrameManaBar_UpdateType", function(manaBar)
        if not manaBar or not manaBar.unit then return end

        local powerType, powerToken = UnitPowerType(manaBar.unit)
        local color = PowerBarColor[powerToken]

        if color then
            manaBar:SetStatusBarColor(color.r, color.g, color.b)

            if manaBar.Bg or manaBar.bg then
                local bg = manaBar.Bg or manaBar.bg
                if bg.SetVertexColor then
                    bg:SetVertexColor(color.r * 0.3, color.g * 0.3, color.b * 0.3)
                end
            end
        end
    end)

    hooksecurefunc("UnitFrameHealthBar_Update", function(healthBar, unit)
        if not healthBar or not unit then return end

        if UnitIsPlayer(unit) and UnitClass(unit) then
            local _, class = UnitClass(unit)
            local color = RAID_CLASS_COLORS[class]
            if color then
                healthBar:SetStatusBarColor(color.r, color.g, color.b)
            end
        else
            healthBar:SetStatusBarColor(0, 1, 0)
        end
    end)
end
