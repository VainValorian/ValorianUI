-- ==========================================
-- VALORIAN UI: NATIVE OPTIONS MODULE
local _, ns = ...
local Options = ns.Engine:NewModule("Options")
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

-- ==========================================
-- THE UI GRID FACTORY
-- ==========================================
local UI = {}

function UI.AddHeader(canvas, text, y)
    local h = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    h:SetPoint("TOPLEFT", 20, y)
    h:SetText(text)
    return y - 40
end

function UI.AddSubHeader(canvas, text, y)
    local h = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    h:SetPoint("TOPLEFT", 20, y)
    h:SetText("|cffFFD100" .. text .. "|r")

    local line = canvas:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.3)
    line:SetSize(540, 1)
    line:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -4)

    return y - 35
end

function UI.AddCheckbox(canvas, label, key, default, x, y, frames, callback)
    local cb = CreateFrame("CheckButton", nil, canvas, "ChatConfigCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb.Text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cb.Text:SetPoint("LEFT", cb, "RIGHT", 5, 0)
    cb.Text:SetText(label)

    local function SyncState() cb:SetChecked(ns.db[key] == nil and default or ns.db[key]) end
    cb:HookScript("OnShow", SyncState)
    SyncState()

    cb:SetScript("OnClick", function(clickedCb)
        local isChecked = clickedCb:GetChecked()
        ns.db[key] = isChecked
        if frames then
            for _, f in ipairs(frames) do
                if _G[f] then if isChecked then _G[f]:Show() else _G[f]:Hide() end end
            end
        end
        if callback then callback(isChecked) end
    end)
    return cb
end

function UI.AddDropdownLSM(canvas, name, labelText, key, mediaType, x, y, callback)
    local lbl = canvas:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    lbl:SetPoint("TOPLEFT", x, y)
    lbl:SetText(labelText)

    local dd = CreateFrame("DropdownButton", name, canvas, "WowStyle1DropdownTemplate")
    dd:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -5)
    dd:SetWidth(180)

    dd:SetupMenu(function(_, rootDescription)
        rootDescription:SetScrollMode(250)
        if LSM then
            for _, item in ipairs(LSM:List(mediaType)) do
                rootDescription:CreateRadio(item, function() return (ns.db[key] or "") == item end, function()
                    ns.db[key] = item
                    if callback then callback(item) end
                end)
            end
        end
    end)
    return dd
end

function UI.AddDropdownList(canvas, name, labelText, key, optionsList, x, y, callback)
    local lbl = canvas:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    lbl:SetPoint("TOPLEFT", x, y)
    lbl:SetText(labelText)

    local dd = CreateFrame("DropdownButton", name, canvas, "WowStyle1DropdownTemplate")
    dd:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -5)
    dd:SetWidth(180)

    dd:SetupMenu(function(_, rootDescription)
        for _, item in ipairs(optionsList) do
            rootDescription:CreateRadio(item, function() return (ns.db[key] or optionsList[1]) == item end, function()
                ns.db[key] = item
                if callback then callback(item) end
            end)
        end
    end)
    return dd
end

function UI.AddSlider(canvas, name, labelText, key, minV, maxV, step, x, y, callback)
    local slider = CreateFrame("Slider", name, canvas, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", x, y - 15)
    slider:SetWidth(180)
    slider:SetMinMaxValues(minV, maxV)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    _G[name .. "Low"]:SetText(minV)
    _G[name .. "High"]:SetText(maxV)
    _G[name .. "Text"]:SetText(labelText)

    local function SyncState() slider:SetValue(ns.db[key] or (minV < 0 and 0 or minV)) end
    slider:HookScript("OnShow", SyncState)
    SyncState()

    slider:SetScript("OnValueChanged", function(_, value)
        ns.db[key] = value
        if callback then callback(value) end
    end)
    return slider
end

function UI.AddColorPicker(canvas, labelText, key, r, g, b, x, y, callback)
    local lbl = canvas:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", x, y)
    lbl:SetText(labelText)

    local btn = CreateFrame("Button", nil, canvas, "BackdropTemplate")
    btn:SetSize(18, 18)
    btn:SetPoint("LEFT", lbl, "RIGHT", 8, 0)
    local tex = btn:CreateTexture(nil, "OVERLAY")
    tex:SetPoint("TOPLEFT", 2, -2)
    tex:SetPoint("BOTTOMRIGHT", -2, 2)
    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetColorTexture(1, 1, 1, 1)

    local function SyncColor()
        local c = ns.db[key] or { r = r, g = g, b = b }
        tex:SetColorTexture(c.r, c.g, c.b)
    end
    btn:HookScript("OnShow", SyncColor)
    SyncColor()

    btn:SetScript("OnClick", function()
        local c = ns.db[key] or { r = r, g = g, b = b }
        ColorPickerFrame:SetupColorPickerAndShow({
            r = c.r,
            g = c.g,
            b = c.b,
            swatchFunc = function()
                local r2, g2, b2 = ColorPickerFrame:GetColorRGB()
                ns.db[key] = { r = r2, g = g2, b = b2 }
                tex:SetColorTexture(r2, g2, b2)
                if callback then callback() end
            end,
            cancelFunc = function(prev)
                ns.db[key] = prev
                tex:SetColorTexture(prev.r, prev.g, prev.b)
                if callback then callback() end
            end,
        })
    end)
end

function Options:CreateSubCategory(name, parentCategory)
    local frame = CreateFrame("Frame", "ValorianUI_" .. name:gsub("%s+", "") .. "Options")
    frame.name = name

    local scrollFrame = CreateFrame("ScrollFrame", "$parentScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 10)

    local canvas = CreateFrame("Frame", "$parentCanvas", scrollFrame)
    canvas:SetSize(600, 100)
    scrollFrame:SetScrollChild(canvas)

    local category = Settings.RegisterCanvasLayoutSubcategory(parentCategory, frame, name)
    return canvas, category
end

local function TriggerUfUpdate()
    if ns.Modules["UnitFrames"] and ns.Modules["UnitFrames"].UpdateAllLayouts then
        ns.Modules["UnitFrames"]:UpdateAllLayouts()
        if ValUI_UFUnlocked then
            for _, f in ipairs({ _G.ValorianUI_Player, _G.ValorianUI_Target, _G.ValorianUI_ToT, _G.ValorianUI_Focus, _G.ValorianUI_Party1, _G.ValorianUI_Raid1 }) do
                if f and f.UpdateAuras then f:UpdateAuras() end
            end
        end
    end
end

local function BuildIconPositioners(canvas, title, prefix, flags, startY)
    local y = startY
    local anchorOptions = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM",
        "BOTTOMRIGHT" }

    if flags.aura then
        y = UI.AddSubHeader(canvas, title .. " Auras (Buffs/Debuffs)", y)
        UI.AddDropdownList(canvas, "ValUI_" .. prefix .. "AuraDD", "Aura Anchor", "uf" .. prefix .. "AuraAnchor",
            anchorOptions, 20, y, TriggerUfUpdate)
        UI.AddSlider(canvas, "ValUI_" .. prefix .. "AuraSize", "Aura Size", "uf" .. prefix .. "AuraSize", 12, 40, 1, 300,
            y - 15, TriggerUfUpdate)
        y = y - 60
        UI.AddSlider(canvas, "ValUI_" .. prefix .. "AuraX", "Aura X Offset", "uf" .. prefix .. "AuraX", -150, 150, 1, 20,
            y, TriggerUfUpdate)
        UI.AddSlider(canvas, "ValUI_" .. prefix .. "AuraY", "Aura Y Offset", "uf" .. prefix .. "AuraY", -150, 150, 1, 300,
            y, TriggerUfUpdate)
        y = y - 50
    end

    if flags.class then
        y = UI.AddSubHeader(canvas, title .. " Class Icon", y)
        UI.AddDropdownList(canvas, "ValUI_" .. prefix .. "ClassDD", "Class Anchor", "uf" .. prefix .. "ClassAnchor",
            anchorOptions, 20, y, TriggerUfUpdate)
        UI.AddSlider(canvas, "ValUI_" .. prefix .. "ClassSize", "Class Size", "uf" .. prefix .. "ClassSize", 12, 40, 1,
            300, y - 15, TriggerUfUpdate)
        y = y - 60
        UI.AddSlider(canvas, "ValUI_" .. prefix .. "ClassX", "Class X Offset", "uf" .. prefix .. "ClassX", -150, 150, 1,
            20, y, TriggerUfUpdate)
        UI.AddSlider(canvas, "ValUI_" .. prefix .. "ClassY", "Class Y Offset", "uf" .. prefix .. "ClassY", -150, 150, 1,
            300, y, TriggerUfUpdate)
        y = y - 50
    end

    if flags.status then
        y = UI.AddSubHeader(canvas, title .. " Status Icon (Combat/Resting)", y)
        UI.AddDropdownList(canvas, "ValUI_" .. prefix .. "StatusDD", "Status Anchor", "uf" .. prefix .. "StatusAnchor",
            anchorOptions, 20, y, TriggerUfUpdate)
        UI.AddSlider(canvas, "ValUI_" .. prefix .. "StatusSize", "Status Size", "uf" .. prefix .. "StatusSize", 12, 40, 1,
            300, y - 15, TriggerUfUpdate)
        y = y - 60
        UI.AddSlider(canvas, "ValUI_" .. prefix .. "StatusX", "Status X Offset", "uf" .. prefix .. "StatusX", -150, 150,
            1, 20, y, TriggerUfUpdate)
        UI.AddSlider(canvas, "ValUI_" .. prefix .. "StatusY", "Status Y Offset", "uf" .. prefix .. "StatusY", -150, 150,
            1, 300, y, TriggerUfUpdate)
        y = y - 50
    end

    if flags.group then
        y = UI.AddSubHeader(canvas, title .. " Group Icons (Leader/Role/Loot)", y)
        UI.AddDropdownList(canvas, "ValUI_" .. prefix .. "GroupDD", "Group Anchor", "uf" .. prefix .. "GroupAnchor",
            anchorOptions, 20, y, TriggerUfUpdate)
        UI.AddSlider(canvas, "ValUI_" .. prefix .. "GroupSize", "Group Size", "uf" .. prefix .. "GroupSize", 12, 40, 1,
            300, y - 15, TriggerUfUpdate)
        y = y - 60
        UI.AddSlider(canvas, "ValUI_" .. prefix .. "GroupX", "Group X Offset", "uf" .. prefix .. "GroupX", -150, 150, 1,
            20, y, TriggerUfUpdate)
        UI.AddSlider(canvas, "ValUI_" .. prefix .. "GroupY", "Group Y Offset", "uf" .. prefix .. "GroupY", -150, 150, 1,
            300, y, TriggerUfUpdate)
        y = y - 50
    end

    return y
end

-- ==========================================
-- 1. COMMAND CENTER (ROOT)
-- ==========================================
function Options:BuildRootPage(mainPanel)
    local y = -20
    y = UI.AddHeader(mainPanel, "Valorian UI Command Center", y)

    local desc = mainPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", 20, y)
    desc:SetWidth(540)
    desc:SetJustifyH("LEFT")
    desc:SetText(
        "Welcome to the Valorian UI Configuration panel. Use the sub-categories on the left to customize your dark-fantasy interface.")

    y = y - 40
    local charKey = ns.charKey
    local profileCb = UI.AddCheckbox(mainPanel, "|cffFFD100Enable Private Character Profile|r", "useProfile_" .. charKey,
        false, 20, y, nil, function(isChecked)
            if not ValorianUIDB.useProfile then ValorianUIDB.useProfile = {} end
            ValorianUIDB.useProfile[charKey] = isChecked
            if isChecked then
                ValorianUIDB.profiles[charKey] = CopyTable(ValorianUIDB.global)
            else
                ValorianUIDB.profiles[charKey] = nil
            end
            ReloadUI()
        end)
    profileCb:SetChecked(ValorianUIDB.useProfile and ValorianUIDB.useProfile[charKey])

    y = y - 40
    local unlockArtBtn = CreateFrame("Button", nil, mainPanel, "UIPanelButtonTemplate")
    unlockArtBtn:SetSize(160, 30)
    unlockArtBtn:SetPoint("TOPLEFT", 20, y)
    unlockArtBtn:SetText(ValUI_FramesUnlocked and "Lock Art Frames" or "Unlock Art Frames")
    unlockArtBtn:SetScript("OnClick", function(btn)
        ValUI_FramesUnlocked = not ValUI_FramesUnlocked
        btn:SetText(ValUI_FramesUnlocked and "Lock Art Frames" or "Unlock Art Frames")
        for idx, name in ipairs(ValUI_MovableFrames) do
            local f = _G[name]
            if f then
                if ValUI_FramesUnlocked then
                    if not ((name == "ValorianUIHealthOrb") and InCombatLockdown()) then
                        f:EnableMouse(true); f:SetMovable(true)
                        if not f.originalStrata then
                            f.originalStrata = f:GetFrameStrata(); f.originalLevel = f:GetFrameLevel()
                        end
                        f:SetFrameStrata("TOOLTIP"); f:SetFrameLevel(9000 - idx)
                    end
                    if f.dragOverlay then f.dragOverlay:Show() end
                else
                    if name ~= "ValorianUIHealthOrb" then
                        f:EnableMouse(false)
                        if f.originalStrata then
                            f:SetFrameStrata(f.originalStrata); f:SetFrameLevel(f.originalLevel)
                        end
                    end
                    if f.dragOverlay then f.dragOverlay:Hide() end
                end
            end
        end
    end)

    local unlockUFBtn = CreateFrame("Button", nil, mainPanel, "UIPanelButtonTemplate")
    unlockUFBtn:SetSize(220, 30)
    unlockUFBtn:SetPoint("LEFT", unlockArtBtn, "RIGHT", 10, 0)
    unlockUFBtn:SetText(ValUI_UFUnlocked and "Lock Unit Frames" or "Unlock Unit Frames (Test Mode)")
    unlockUFBtn:SetScript("OnClick", function(btn)
        if InCombatLockdown() then
            print("|cffFF0000ValorianUI:|r Cannot toggle Test Mode in combat."); return
        end
        ValUI_UFUnlocked = not ValUI_UFUnlocked
        btn:SetText(ValUI_UFUnlocked and "Lock Unit Frames" or "Unlock Unit Frames (Test Mode)")
        if ns.Modules["UnitFrames"] and ns.Modules["UnitFrames"].ToggleTestMode then
            ns.Modules["UnitFrames"]:ToggleTestMode(ValUI_UFUnlocked)
        end
    end)
end

-- ==========================================
-- 2. GENERAL SETTINGS
-- ==========================================
function Options:BuildGeneralSettings(parentCategory)
    local canvas, _ = self:CreateSubCategory("General Settings", parentCategory)
    local y = -20

    y = UI.AddHeader(canvas, "General Settings", y)
    y = UI.AddSubHeader(canvas, "Module Toggles", y)

    UI.AddCheckbox(canvas, "Main Action Bar Art", "showActionBars", true, 20, y,
        { "ValorianUIBar1", "ValorianUIBar2", "ValorianUIBar1Mask", "ValorianUIBar2Mask" })
    UI.AddCheckbox(canvas, "Extra Action Bar Art", "showExtraActionBars", true, 300, y,
        { "ValorianUIArt_MultiBarBottomRight", "ValorianUIArt_MultiBarRight", "ValorianUIArt_MultiBarLeft",
            "ValorianUIArt_MultiBar5", "ValorianUIArt_MultiBar6", "ValorianUIArt_MultiBar7" })
    y = y - 30
    UI.AddCheckbox(canvas, "Chat & Damage Backdrops", "showChatDamage", true, 20, y,
        { "ValorianUIChatArt", "ValorianUIDamageArt" })
    UI.AddCheckbox(canvas, "Seamore Spheres Angels", "showAngels", true, 300, y)
    y = y - 30
    UI.AddCheckbox(canvas, "Succubus Corner Art", "showSuccubus", true, 20, y, { "ValorianUISuccubusFrame" })
    UI.AddCheckbox(canvas, "Info Bar (Time/Ping/FPS)", "showInfoBar", true, 300, y, { "ValorianUI_InfoBar" })
    y = y - 30
    UI.AddCheckbox(canvas, "Damage Meter Skinning (Reload)", "enableDMSkinning", true, 20, y)
    UI.AddCheckbox(canvas, "Status Bar Skinning (Reload)", "enableSBSkinning", true, 300, y)
    y = y - 30
    UI.AddCheckbox(canvas, "Show Orb Numerical Text", "showOrbText", true, 20, y)
    UI.AddCheckbox(canvas, "Enable Minimap Drawer (Reload)", "showMinimapDrawer", true, 300, y, nil,
        function() print("|cff888888ValorianUI:|r Please type /reload to apply.") end)
    y = y - 30
    UI.AddCheckbox(canvas, "Action Bars Skinning (Reload)", "enableActionBarsSkinning", true, 20, y, nil,
        function() print("|cff888888ValorianUI:|r Please type /reload to apply.") end)
    UI.AddCheckbox(canvas, "Auras Skinning (Reload)", "enableAurasSkinning", true, 300, y, nil,
        function() print("|cff888888ValorianUI:|r Please type /reload to apply.") end)
    y = y - 40

    y = UI.AddSubHeader(canvas, "Art Scaling", y)
    local function ScaleCb(f)
        return function(v)
            if not ns.db.frames[f] then ns.db.frames[f] = {} end
            ns.db.frames[f].scale = v
            if _G[f] then _G[f]:SetScale(v) end
        end
    end

    UI.AddSlider(canvas, "ValUISliderChat", "Chat Art Scale", "scale_chat", 0.5, 2.5, 0.05, 20, y,
        ScaleCb("ValorianUIChatArt"))
    UI.AddSlider(canvas, "ValUISliderDmg", "Damage Art Scale", "scale_dmg", 0.5, 2.5, 0.05, 300, y,
        ScaleCb("ValorianUIDamageArt"))
    y = y - 50
    UI.AddSlider(canvas, "ValUISliderHealth", "Health Orb Scale", "scale_health", 0.5, 2.5, 0.05, 20, y,
        ScaleCb("ValorianUIHealthOrb"))
    UI.AddSlider(canvas, "ValUISliderPower", "Power Orb Scale", "scale_power", 0.5, 2.5, 0.05, 300, y,
        ScaleCb("ValorianUIPowerOrb"))
    y = y - 50
    UI.AddSlider(canvas, "ValUISliderSucc", "Succubus Art Scale", "scale_succ", 0.5, 2.5, 0.05, 20, y,
        ScaleCb("ValorianUISuccubusFrame"))
    UI.AddSlider(canvas, "ValUISliderInfo", "Info Bar Scale", "scale_info", 0.5, 2.5, 0.05, 300, y,
        ScaleCb("ValorianUI_InfoBar"))
    y = y - 50

    y = UI.AddSubHeader(canvas, "Global Fonts", y)
    UI.AddDropdownLSM(canvas, "ValUIFontDropdown", "Global UI Font", "fontChoice", "font", 20, y,
        function(v) if LSM and _G.ValorianUI_ApplyGlobalFonts then _G.ValorianUI_ApplyGlobalFonts(LSM:Fetch("font", v)) end end)
    y = y - 50
    UI.AddCheckbox(canvas, "Use Class Color for Tracker", "trackerClassColor", false, 20, y, nil,
        function() if ObjectiveTrackerFrame then ObjectiveTrackerFrame:Update() end end)
    UI.AddColorPicker(canvas, "Custom Tracker Color", "trackerColor", 0.8, 0.2, 0.2, 300, y,
        function() if ObjectiveTrackerFrame then ObjectiveTrackerFrame:Update() end end)

    canvas:SetHeight(math.abs(y) + 50)
end

-- ==========================================
-- 3. UNIT FRAMES (NESTED ARCHITECTURE)
-- ==========================================
function Options:BuildUnitFramesMaster(parentCategory)
    local canvas, category = self:CreateSubCategory("Unit Frames", parentCategory)
    local y = -20
    local function Notify() print("|cff888888ValorianUI:|r Please type /reload to apply changes.") end

    y = UI.AddHeader(canvas, "Unit Frames", y)
    y = UI.AddSubHeader(canvas, "Global Textures", y)
    UI.AddDropdownLSM(canvas, "ValUIHlthTexDD", "Global Health Bar Texture", "ufHealthTexture", "statusbar", 20, y,
        Notify)
    UI.AddDropdownLSM(canvas, "ValUIPwrTexDD", "Global Power Bar Texture", "ufPowerTexture", "statusbar", 300, y, Notify)
    y = y - 50

    y = UI.AddSubHeader(canvas, "Performance Settings", y)
    UI.AddCheckbox(canvas, "Use 2D Portraits (Saves Memory/FPS)", "ufUse2DPortraits", false, 20, y, nil, Notify)
    y = y - 40

    y = UI.AddSubHeader(canvas, "Master Enable Toggles (Requires Reload)", y)
    UI.AddCheckbox(canvas, "Enable Player Frame", "showPlayerFrame", true, 20, y, nil, Notify)
    UI.AddCheckbox(canvas, "Enable Target & Focus Frames", "showTargetFrames", true, 300, y, nil, Notify)
    y = y - 30
    UI.AddCheckbox(canvas, "Enable Target-of-Target Frame", "showToTFrames", true, 20, y, nil, Notify)
    UI.AddCheckbox(canvas, "Enable Party Frames", "showPartyFrames", true, 300, y, nil, Notify)
    y = y - 30
    UI.AddCheckbox(canvas, "Enable Raid Frames", "showRaidFrames", true, 20, y, nil, Notify)
    UI.AddCheckbox(canvas, "Enable Boss & Arena Frames", "showBossFrames", true, 300, y, nil, Notify)

    canvas:SetHeight(math.abs(y) + 50)
    return category
end

function Options:BuildUFPlayerSettings(ufCategory)
    local canvas, _ = self:CreateSubCategory("Player", ufCategory)
    local y = -20

    y = UI.AddHeader(canvas, "Player Frame", y)
    y = UI.AddSubHeader(canvas, "Frame Sizing", y)

    UI.AddSlider(canvas, "ValUI_PlayerWidth", "Width", "ufWidth", 150, 400, 5, 20, y, TriggerUfUpdate)
    UI.AddSlider(canvas, "ValUI_PlayerHeight", "Height", "ufHeight", 30, 100, 1, 300, y, TriggerUfUpdate)
    y = y - 50
    UI.AddSlider(canvas, "ValUI_PlayerPortrait", "Portrait Size", "ufPortraitSize", 20, 80, 1, 20, y, TriggerUfUpdate)
    UI.AddSlider(canvas, "ValUI_PlayerBorderInset", "Border Offset", "ufPlayerBorderOffset", 0, 10, 1, 300, y,
        TriggerUfUpdate)
    y = y - 50
    UI.AddDropdownLSM(canvas, "ValUI_PlayerBorderDD", "Border Texture", "ufPlayerBorder", "border", 20, y,
        TriggerUfUpdate)
    y = y - 60

    y = BuildIconPositioners(canvas, "Player", "Player", { aura = true, class = true, status = true, group = true }, y)

    y = UI.AddSubHeader(canvas, "Native Player Castbar Overrides", y)
    UI.AddDropdownLSM(canvas, "ValUINatCastTexDD", "Castbar Texture", "nativeCastbarTexture", "statusbar", 20, y,
        TriggerUfUpdate)
    y = y - 60
    UI.AddColorPicker(canvas, "Normal", "nativeCastNormalColor", 1.0, 0.7, 0.0, 20, y)
    UI.AddColorPicker(canvas, "Channel", "nativeCastChannelColor", 0.2, 0.8, 0.2, 140, y)
    UI.AddColorPicker(canvas, "Uninterrupt", "nativeCastUninterruptColor", 0.6, 0.6, 0.6, 260, y)
    UI.AddColorPicker(canvas, "Empower", "nativeCastEmpoweredColor", 0.3, 0.7, 1.0, 380, y)

    canvas:SetHeight(math.abs(y) + 50)
end

function Options:BuildUFTargetSettings(ufCategory)
    local canvas, _ = self:CreateSubCategory("Target & Focus", ufCategory)
    local y = -20

    y = UI.AddHeader(canvas, "Target & Focus Frames", y)
    y = UI.AddSubHeader(canvas, "Frame Sizing", y)

    UI.AddSlider(canvas, "ValUI_TarWidth", "Width", "ufTargetWidth", 150, 400, 5, 20, y, TriggerUfUpdate)
    UI.AddSlider(canvas, "ValUI_TarHeight", "Height", "ufTargetHeight", 30, 100, 1, 300, y, TriggerUfUpdate)
    y = y - 50
    UI.AddSlider(canvas, "ValUI_TarPortrait", "Portrait Size", "ufTargetPortraitSize", 20, 80, 1, 20, y, TriggerUfUpdate)
    UI.AddSlider(canvas, "ValUI_TarBorderInset", "Border Offset", "ufTargetBorderOffset", 0, 10, 1, 300, y,
        TriggerUfUpdate)
    y = y - 50
    UI.AddDropdownLSM(canvas, "ValUI_TarBorderDD", "Border Texture", "ufTargetBorder", "border", 20, y, TriggerUfUpdate)
    y = y - 60

    y = BuildIconPositioners(canvas, "Target", "Target", { aura = true, class = true, status = false, group = false }, y)

    y = UI.AddSubHeader(canvas, "Target Castbar Colors", y)
    UI.AddDropdownLSM(canvas, "ValUITarCastTexDD", "Castbar Texture", "ufCastbarTexture", "statusbar", 20, y,
        TriggerUfUpdate)
    y = y - 60
    UI.AddColorPicker(canvas, "Normal", "ufCastNormalColor", 1.0, 0.7, 0.0, 20, y)
    UI.AddColorPicker(canvas, "Channel", "ufCastChannelColor", 0.2, 0.8, 0.2, 140, y)
    UI.AddColorPicker(canvas, "Uninterrupt", "ufCastUninterruptColor", 0.6, 0.6, 0.6, 260, y)
    UI.AddColorPicker(canvas, "Empower", "ufCastEmpoweredColor", 0.3, 0.7, 1.0, 380, y)

    canvas:SetHeight(math.abs(y) + 50)
end

function Options:BuildUFGroupSettings(ufCategory)
    local canvas, _ = self:CreateSubCategory("Group Frames", ufCategory)
    local y = -20

    y = UI.AddHeader(canvas, "Party Frames", y)
    y = UI.AddSubHeader(canvas, "Party Sizing", y)
    UI.AddSlider(canvas, "ValUI_PartyWidth", "Width", "ufPartyWidth", 100, 300, 5, 20, y, TriggerUfUpdate)
    UI.AddSlider(canvas, "ValUI_PartyHeight", "Height", "ufPartyHeight", 20, 80, 1, 300, y, TriggerUfUpdate)
    y = y - 50
    UI.AddSlider(canvas, "ValUI_PartyPortrait", "Portrait Size", "ufPartyPortraitSize", 16, 60, 1, 20, y, TriggerUfUpdate)
    UI.AddSlider(canvas, "ValUI_PartySpacing", "Vertical Spacing", "ufPartySpacing", 0, 50, 1, 300, y, TriggerUfUpdate)
    y = y - 50
    UI.AddSlider(canvas, "ValUI_PartyBorderInset", "Border Offset", "ufPartyBorderOffset", 0, 10, 1, 20, y,
        TriggerUfUpdate)
    UI.AddDropdownLSM(canvas, "ValUI_PartyBorderDD", "Border Texture", "ufPartyBorder", "border", 300, y, TriggerUfUpdate)
    y = y - 60

    y = BuildIconPositioners(canvas, "Party", "Party", { aura = true, class = true, status = false, group = true }, y)

    y = UI.AddHeader(canvas, "Raid Frames", y)
    y = UI.AddSubHeader(canvas, "Raid Sizing", y)
    UI.AddSlider(canvas, "ValUI_RaidWidth", "Width", "ufRaidWidth", 40, 150, 1, 20, y, TriggerUfUpdate)
    UI.AddSlider(canvas, "ValUI_RaidHeight", "Height", "ufRaidHeight", 20, 80, 1, 300, y, TriggerUfUpdate)
    y = y - 50
    UI.AddSlider(canvas, "ValUI_RaidCols", "Columns", "ufRaidCols", 1, 8, 1, 20, y, TriggerUfUpdate)
    UI.AddSlider(canvas, "ValUI_RaidSpacing", "Vertical Spacing", "ufRaidSpacingY", 0, 20, 1, 300, y, TriggerUfUpdate)
    y = y - 50
    UI.AddSlider(canvas, "ValUI_RaidBorderInset", "Border Offset", "ufRaidBorderOffset", 0, 10, 1, 20, y, TriggerUfUpdate)
    UI.AddDropdownLSM(canvas, "ValUI_RaidBorderDD", "Border Texture", "ufRaidBorder", "border", 300, y, TriggerUfUpdate)
    y = y - 60

    y = BuildIconPositioners(canvas, "Raid", "Raid", { aura = true, class = false, status = false, group = true }, y)

    canvas:SetHeight(math.abs(y) + 50)
end

function Options:BuildUFEncounterSettings(ufCategory)
    local canvas, _ = self:CreateSubCategory("Encounter Frames", ufCategory)
    local y = -20

    y = UI.AddHeader(canvas, "Boss & Arena Frames", y)
    y = UI.AddSubHeader(canvas, "Frame Sizing", y)
    UI.AddSlider(canvas, "ValUI_EncWidth", "Width", "ufEncounterWidth", 100, 300, 5, 20, y, TriggerUfUpdate)
    UI.AddSlider(canvas, "ValUI_EncHeight", "Height", "ufEncounterHeight", 20, 80, 1, 300, y, TriggerUfUpdate)
    y = y - 50
    UI.AddSlider(canvas, "ValUI_EncSpacing", "Vertical Spacing", "ufEncounterSpacing", 0, 50, 1, 20, y, TriggerUfUpdate)
    UI.AddSlider(canvas, "ValUI_EncBorderInset", "Border Offset", "ufEncounterBorderOffset", 0, 10, 1, 300, y,
        TriggerUfUpdate)
    y = y - 50
    UI.AddDropdownLSM(canvas, "ValUI_EncBorderDD", "Border Texture", "ufEncounterBorder", "border", 20, y,
        TriggerUfUpdate)
    y = y - 60

    y = BuildIconPositioners(canvas, "Encounter", "Encounter",
        { aura = true, class = true, status = false, group = false },
        y)

    canvas:SetHeight(math.abs(y) + 50)
end

-- ==========================================
-- 4. DAMAGE METER SETTINGS
-- ==========================================
function Options:BuildDamageMeterSettings(parentCategory)
    local canvas, _ = self:CreateSubCategory("Damage Meter", parentCategory)
    local y = -20
    y = UI.AddHeader(canvas, "Damage Meter", y)

    local previewLabel = canvas:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    previewLabel:SetPoint("TOP", canvas, "TOP", 0, y)
    previewLabel:SetText("Live Bar Preview")

    local combinedPreview = CreateFrame("StatusBar", nil, canvas)
    combinedPreview:SetSize(200, 24)
    combinedPreview:SetPoint("TOP", previewLabel, "BOTTOM", 0, -10)
    combinedPreview:SetMinMaxValues(0, 100)
    combinedPreview:SetValue(100)
    combinedPreview:SetStatusBarColor(0.77, 0.12, 0.23)

    local combinedPreviewText = combinedPreview:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    combinedPreviewText:SetPoint("CENTER")
    combinedPreviewText:SetText("Death Strike: 150k")

    local combinedBorder = CreateFrame("Frame", nil, combinedPreview, "BackdropTemplate")

    local previewIcon = combinedPreview:CreateTexture(nil, "ARTWORK")
    previewIcon:SetSize(24, 24)
    previewIcon:SetPoint("RIGHT", combinedPreview, "LEFT", -8, 0)

    local previewIconBorder = CreateFrame("Frame", nil, combinedPreview, "BackdropTemplate")
    previewIconBorder:SetFrameLevel(combinedPreview:GetFrameLevel() + 2)

    canvas.isDirty = true
    canvas:HookScript("OnShow", function(c) c.isDirty = true end)
    canvas:HookScript("OnUpdate", function(c)
        if c.isDirty then
            c:Layout(); c.isDirty = false
        end
    end)
    local function RequestUpdate() canvas.isDirty = true end

    function canvas:Layout()
        if not LSM then return end
        local offset = ns.db.meterBorderOffset or 2
        combinedBorder:ClearAllPoints()
        combinedBorder:SetPoint("TOPLEFT", combinedPreview, "TOPLEFT", -offset, offset)
        combinedBorder:SetPoint("BOTTOMRIGHT", combinedPreview, "BOTTOMRIGHT", offset, -offset)

        local bTex = LSM:Fetch("statusbar", ns.db.meterBarTexture)
        if bTex then combinedPreview:SetStatusBarTexture(bTex) end

        local brdTex = LSM:Fetch("border", ns.db.meterBorderTexture)
        if brdTex then
            combinedBorder:SetBackdrop({ edgeFile = brdTex, edgeSize = 10 })
            combinedBorder:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        end

        if ns.db.meterCustomIcons ~= false then
            previewIcon:SetTexture("Interface\\AddOns\\ValorianUI\\Media\\ClassIcons.tga")
            previewIcon:SetTexCoord(0.25, 0.50, 0.25, 0.50)
        else
            previewIcon:SetTexture("Interface\\Icons\\spell_deathknight_deathstrike")
            previewIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end

        if ns.db.meterIconBorders ~= false then
            previewIconBorder:Show()
            local iOffset = ns.db.meterIconBorderOffset or 1
            previewIconBorder:ClearAllPoints()
            previewIconBorder:SetPoint("TOPLEFT", previewIcon, "TOPLEFT", -iOffset, iOffset)
            previewIconBorder:SetPoint("BOTTOMRIGHT", previewIcon, "BOTTOMRIGHT", iOffset, -iOffset)
            local iBrdTex = LSM:Fetch("border", ns.db.meterIconBorderTexture or "Blizzard Tooltip")
            if iBrdTex then
                previewIconBorder:SetBackdrop({ edgeFile = iBrdTex, edgeSize = 10 })
                previewIconBorder:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
            end
        else
            previewIconBorder:Hide()
        end
    end

    y = y - 90

    y = UI.AddSubHeader(canvas, "Bar Aesthetics", y)
    UI.AddDropdownLSM(canvas, "ValUIDMBarDropdown", "Bar Texture", "meterBarTexture", "statusbar", 20, y, RequestUpdate)
    UI.AddDropdownLSM(canvas, "ValUIDMBorderDropdown", "Bar Border Texture", "meterBorderTexture", "border", 300, y,
        RequestUpdate)
    y = y - 50
    UI.AddSlider(canvas, "ValUIDMOffsetSlider", "Border Spacing Offset", "meterBorderOffset", -5, 15, 1, 20, y,
        RequestUpdate)
    y = y - 50
    UI.AddCheckbox(canvas, "Auto-Reset meter on Combat Start", "meterAutoResetOpenWorld", true, 20, y)
    y = y - 40

    y = UI.AddSubHeader(canvas, "Icon Aesthetics", y)
    UI.AddCheckbox(canvas, "Use Custom Valorian Class Icons", "meterCustomIcons", true, 20, y, nil, RequestUpdate)
    UI.AddCheckbox(canvas, "Enable Borders on Icons", "meterIconBorders", true, 300, y, nil, RequestUpdate)
    y = y - 30
    UI.AddDropdownLSM(canvas, "ValUIDMIconBorderDropdown", "Icon Border Texture", "meterIconBorderTexture", "border", 20,
        y, RequestUpdate)
    UI.AddSlider(canvas, "ValUIDMIconOffsetSlider", "Icon Border Offset", "meterIconBorderOffset", -5, 15, 1, 300, y - 15,
        RequestUpdate)

    canvas:SetHeight(math.abs(y) + 100)
end

-- ==========================================
-- 5. STATUS BARS SETTINGS
-- ==========================================
function Options:BuildStatusBarsSettings(parentCategory)
    local canvas, _ = self:CreateSubCategory("Status Bars", parentCategory)
    local y = -20
    y = UI.AddHeader(canvas, "Status Bars", y)

    local previewLabel = canvas:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    previewLabel:SetPoint("TOP", canvas, "TOP", 0, y)
    previewLabel:SetText("Live Bar Preview")

    local combinedPreview = CreateFrame("StatusBar", nil, canvas)
    combinedPreview:SetWidth(250)
    combinedPreview:SetPoint("TOP", previewLabel, "BOTTOM", 0, -10)
    combinedPreview:SetMinMaxValues(0, 100)
    combinedPreview:SetValue(65)
    combinedPreview:SetStatusBarColor(0.5, 0.2, 0.8)

    local previewText = combinedPreview:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    previewText:SetPoint("CENTER")
    previewText:SetText("Experience 65%")
    local combinedBorder = CreateFrame("Frame", nil, combinedPreview, "BackdropTemplate")

    canvas.previewColorKey = "sbExpColor"
    canvas.isDirty = true
    canvas:HookScript("OnShow", function(c) c.isDirty = true end)
    canvas:HookScript("OnUpdate", function(c)
        if c.isDirty then
            c:Layout(); c.isDirty = false
        end
    end)
    local function RequestUpdate() canvas.isDirty = true end

    function canvas:Layout()
        if not LSM then return end
        local offset = ns.db.statusBorderOffset or 2
        local thickness = ns.db.statusHeight or 14

        combinedPreview:SetHeight(thickness)
        combinedBorder:ClearAllPoints()
        combinedBorder:SetPoint("TOPLEFT", combinedPreview, "TOPLEFT", -offset, offset)
        combinedBorder:SetPoint("BOTTOMRIGHT", combinedPreview, "BOTTOMRIGHT", offset, -offset)

        local bTex = LSM:Fetch("statusbar", ns.db.statusBarTexture)
        if bTex then combinedPreview:SetStatusBarTexture(bTex) end

        local brdTex = LSM:Fetch("border", ns.db.statusBorderTexture)
        if brdTex then
            combinedBorder:SetBackdrop({ edgeFile = brdTex, edgeSize = 10 })
            combinedBorder:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        end

        local c = ns.db[self.previewColorKey] or { r = 0.5, g = 0.2, b = 0.8 }
        combinedPreview:SetStatusBarColor(c.r, c.g, c.b)

        if self.previewColorKey == "sbExpColor" then
            previewText:SetText("Experience 65%")
        elseif self.previewColorKey == "sbRepColor" then
            previewText:SetText("Reputation 65%")
        elseif self.previewColorKey == "sbHonorColor" then
            previewText:SetText("Honor 65%")
        end
    end

    y = y - 90

    y = UI.AddSubHeader(canvas, "Bar Settings", y)
    UI.AddDropdownLSM(canvas, "ValUISBBarDropdown", "Bar Texture", "statusBarTexture", "statusbar", 20, y, RequestUpdate)
    UI.AddDropdownLSM(canvas, "ValUISBBorderDropdown", "Bar Border Texture", "statusBorderTexture", "border", 300, y,
        RequestUpdate)
    y = y - 50
    UI.AddSlider(canvas, "ValUISBOffsetSlider", "Border Offset", "statusBorderOffset", -5, 15, 1, 20, y, RequestUpdate)
    UI.AddSlider(canvas, "ValUISBWidthSlider", "Bar Length", "statusWidth", 200, 1200, 1, 300, y, RequestUpdate)
    y = y - 50
    UI.AddSlider(canvas, "ValUISBHeightSlider", "Bar Thickness", "statusHeight", 5, 40, 1, 20, y, RequestUpdate)
    y = y - 60

    y = UI.AddSubHeader(canvas, "Bar Colors", y)
    UI.AddColorPicker(canvas, "Experience", "sbExpColor", 0.5, 0.2, 0.8, 20, y,
        function()
            canvas.previewColorKey = "sbExpColor"; RequestUpdate()
        end)
    UI.AddColorPicker(canvas, "Reputation", "sbRepColor", 0.2, 0.6, 0.8, 140, y,
        function()
            canvas.previewColorKey = "sbRepColor"; RequestUpdate()
        end)
    UI.AddColorPicker(canvas, "Honor", "sbHonorColor", 0.8, 0.2, 0.2, 260, y,
        function()
            canvas.previewColorKey = "sbHonorColor"; RequestUpdate()
        end)

    canvas:SetHeight(math.abs(y) + 50)
end

-- ==========================================
-- 6. CHAT SETTINGS
-- ==========================================
function Options:BuildChatSettings(parentCategory)
    local canvas, _ = self:CreateSubCategory("Chat", parentCategory)
    local y = -20
    y = UI.AddHeader(canvas, "Chat Settings", y)

    y = UI.AddSubHeader(canvas, "Chat Toggles", y)
    UI.AddCheckbox(canvas, "Enable Valorian Chat Engine (Reload)", "enableChatEngine", true, 20, y, nil,
        function() print("|cff888888ValorianUI:|r Please type /reload to apply.") end)
    UI.AddCheckbox(canvas, "Lock Chat Frame (Hides Resize Handle)", "chatLocked", false, 300, y, nil,
        function() if ns.ChatEngine then ns.ChatEngine:UpdateSettings() end end)
    y = y - 30
    UI.AddCheckbox(canvas, "Auto-Fade Tabs (Show on Mouseover)", "chatAutoFadeTabs", false, 20, y)
    UI.AddCheckbox(canvas, "Auto-Fade EditBox (Hide when not typing)", "chatAutoFadeEditBox", false, 300, y, nil,
        function() if ns.ChatEngine then ns.ChatEngine.UpdateEditBoxFade() end end)
    y = y - 30
    UI.AddCheckbox(canvas, "Show Timestamps & Separator", "chatTimestamps", true, 20, y)
    UI.AddCheckbox(canvas, "Show Player Class Icons", "chatClassIcons", true, 300, y)
    y = y - 40

    y = UI.AddSubHeader(canvas, "Chat Adjustments", y)
    UI.AddSlider(canvas, "ValUI_ChatFontSlider", "Font Size", "chatFontSize", 10, 24, 1, 20, y,
        function() if ns.ChatEngine then ns.ChatEngine:UpdateSettings() end end)
    UI.AddSlider(canvas, "ValUI_ChatAlphaSlider", "Background Opacity", "chatBgAlpha", 0, 1, 0.05, 300, y,
        function() if ns.ChatEngine then ns.ChatEngine:UpdateSettings() end end)

    canvas:SetHeight(math.abs(y) + 50)
end

-- ==========================================
-- 7. TOOLTIPS SETTINGS
-- ==========================================
function Options:BuildTooltipSettings(parentCategory)
    local canvas, _ = self:CreateSubCategory("Tooltips", parentCategory)
    local y = -20
    y = UI.AddHeader(canvas, "Tooltips Settings", y)

    y = UI.AddSubHeader(canvas, "Tooltip Toggles", y)
    UI.AddCheckbox(canvas, "Enable Tooltip Engine (Reload)", "enableTooltips", true, 20, y, nil,
        function() print("|cff888888ValorianUI:|r Please type /reload to apply.") end)
    UI.AddCheckbox(canvas, "Anchor to Cursor", "tooltipAnchorCursor", false, 300, y)
    y = y - 30
    UI.AddCheckbox(canvas, "Show Health Bar", "tooltipShowHealthBar", true, 20, y)
    y = y - 40

    y = UI.AddSubHeader(canvas, "Tooltip Styling", y)
    UI.AddDropdownLSM(canvas, "ValUITooltipBorderDD", "Border Texture", "tooltipBorderTexture", "border", 20, y)
    UI.AddDropdownLSM(canvas, "ValUITooltipBarDD", "Health Bar Texture", "tooltipBarTexture", "statusbar", 300, y)
    y = y - 50
    UI.AddSlider(canvas, "ValUITooltipAlphaSlider", "Background Opacity", "tooltipBgAlpha", 0, 1, 0.05, 20, y)
    UI.AddSlider(canvas, "ValUITooltipBodySize", "Tooltip Scale (Size)", "tooltipBodySize", 10, 24, 1, 300, y,
        function()
            if ns.Modules["Tooltips"] and ns.Modules["Tooltips"].UpdateFonts then
                ns.Modules["Tooltips"]
                    :UpdateFonts()
            end
        end)
    y = y - 60

    y = UI.AddSubHeader(canvas, "Dynamic Colors", y)
    UI.AddColorPicker(canvas, "Guild Name", "tooltipGuildColor", 1.0, 0.82, 0.0, 20, y)
    UI.AddColorPicker(canvas, "Guild Rank", "tooltipGuildRankColor", 0.62, 0.62, 0.62, 140, y)
    UI.AddColorPicker(canvas, "Mount Text", "tooltipMountColor", 0.64, 0.21, 0.93, 260, y)
    UI.AddColorPicker(canvas, "Targeting YOU", "tooltipTargetYouColor", 1.0, 0.0, 0.0, 380, y)

    canvas:SetHeight(math.abs(y) + 50)
end

-- ==========================================
-- 8. MINIMAP MENU BUTTON
-- ==========================================
function Options:BuildMinimapButton(parentCategory)
    local miniBtn = CreateFrame("Button", "ValorianUIMiniBtn", Minimap)
    miniBtn:SetSize(32, 32)
    miniBtn:SetFrameStrata("MEDIUM")
    miniBtn:SetFrameLevel(8)

    local miniTex = miniBtn:CreateTexture(nil, "ARTWORK")
    miniTex:SetTexture("Interface\\AddOns\\ValorianUI\\Textures\\MinimapIcon.tga")
    miniTex:SetAllPoints()

    local miniMask = miniBtn:CreateTexture(nil, "OVERLAY")
    miniMask:SetTexture("Interface\\Minimap\\Minimap-Border")
    miniMask:SetPoint("TOPLEFT", -2, 2)
    miniMask:SetPoint("BOTTOMRIGHT", 2, -2)

    local function UpdateMiniBtnPos()
        local angle = math.rad(ns.db.minimapAngle or 45)
        local x = math.cos(angle) * 80
        local y = math.sin(angle) * 80
        miniBtn:ClearAllPoints()
        miniBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end

    miniBtn:RegisterForDrag("LeftButton")
    miniBtn:SetScript("OnDragStart", function(btn)
        btn:SetScript("OnUpdate", function()
            local cx, cy = Minimap:GetCenter()
            local mx, my = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            local angle = math.deg(math.atan2((my / scale) - cy, (mx / scale) - cx))
            ns.db.minimapAngle = angle
            UpdateMiniBtnPos()
        end)
    end)
    miniBtn:SetScript("OnDragStop", function(btn) btn:SetScript("OnUpdate", nil) end)
    miniBtn:SetScript("OnClick", function() Settings.OpenToCategory(parentCategory.ID) end)

    UpdateMiniBtnPos()
end

-- ==========================================
-- INITIALIZE EVERYTHING
-- ==========================================
function Options:OnInit()
    local mainPanel = CreateFrame("Frame", "ValorianUIMainPanel", UIParent)
    mainPanel.name = "Valorian UI"
    local category, _ = Settings.RegisterCanvasLayoutCategory(mainPanel, mainPanel.name)
    Settings.RegisterAddOnCategory(category)
    self.MainCategory = category

    self:BuildRootPage(mainPanel)
    self:BuildGeneralSettings(category)

    local ufCategory = self:BuildUnitFramesMaster(category)
    self:BuildUFPlayerSettings(ufCategory)
    self:BuildUFTargetSettings(ufCategory)
    self:BuildUFGroupSettings(ufCategory)
    self:BuildUFEncounterSettings(ufCategory)

    self:BuildDamageMeterSettings(category)
    self:BuildStatusBarsSettings(category)
    self:BuildChatSettings(category)
    self:BuildTooltipSettings(category)

    self:BuildMinimapButton(category)
end
