-- ==========================================
-- VALORIAN UI: CHAT ENGINE
-- ==========================================
local addonName, ns = ...
local ChatEngine = ns.Engine:NewModule("ChatEngine")

ns.ChatEngine = ChatEngine
ns.ChatFrames = {}

local issecretvalue = issecretvalue or function() return false end
local function canaccessvalue(v)
    return v ~= nil and not issecretvalue(v)
end

-- ==========================================
-- 1. THE BLACK HOLE (DUMMY FRAME)
-- ==========================================
local ValUI_HiddenChatFrame = CreateFrame("Frame")
ValUI_HiddenChatFrame:Hide()

-- ==========================================
-- 2. THE OPTIONS LISTENER
-- ==========================================
function ChatEngine:UpdateSettings()
    if not self.Panel then return end
    local isLocked = ns.db.chatLocked or false
    self.Panel.resizer:SetShown(not isLocked)
    local bgAlpha = ns.db.chatBgAlpha or 0.9
    self.Panel:SetBackdropColor(0.05, 0.05, 0.05, bgAlpha)

    local fontSize = ns.db.chatFontSize or 14
    local fontPath = STANDARD_TEXT_FONT or ChatFontNormal:GetFont() or "Fonts\\FRIZQT__.TTF"

    for _, frame in pairs(ns.ChatFrames) do
        frame:SetFont(fontPath, fontSize, "OUTLINE")
        frame:SetSpacing(3)
    end
end

ChatEngine.UpdateEditBoxFade = function()
    local eb = ChatFrame1EditBox
    if not eb then return end
    if ns.db.chatAutoFadeEditBox then
        if eb:HasFocus() then
            eb:SetAlpha(1)
        else
            eb:SetAlpha(0)
        end
    else
        eb:SetAlpha(1)
    end
end

function ChatEngine:OnEnable()
    if ns.db.enableChatEngine == false then return end
    if self.isInitialized then return end
    self.isInitialized = true

    if not ns.db.chatTabs then
        ns.db.chatTabs = {
            [1] = { name = "General", filters = { SAY = true, YELL = true, GUILD = true, OFFICER = true, PARTY = true, PARTY_LEADER = true, RAID = true, RAID_LEADER = true, INSTANCE_CHAT = true, INSTANCE_CHAT_LEADER = true, WHISPER = true, EMOTE = true, CHANNEL = true } },
            [2] = { name = "System", filters = { SYSTEM = true, LOOT = true, CURRENCY = true, MONEY = true } }
        }
    end
    ns.ActiveChatTab = ns.db.ActiveChatTab or 1
    if ns.ActiveChatTab > #ns.db.chatTabs then ns.ActiveChatTab = 1 end

    if not InCombatLockdown() then
        SetCVar("whisperMode", "inline")
        SetCVar("bnWhisperMode", "inline")
    end

    local function BanishFrame(frame)
        if not frame then return end
        frame:SetParent(ValUI_HiddenChatFrame)
        frame:Hide()
        if type(frame.SetAlpha) == "function" then frame:SetAlpha(0) end

        if not frame.ValUI_Hooked then
            hooksecurefunc(frame, "SetParent", function(self, parent)
                if parent ~= ValUI_HiddenChatFrame then self:SetParent(ValUI_HiddenChatFrame) end
            end)
            hooksecurefunc(frame, "Show", function(self) self:Hide() end)
            if type(frame.SetAlpha) == "function" then
                hooksecurefunc(frame, "SetAlpha", function(self, alpha)
                    if alpha > 0 then self:SetAlpha(0) end
                end)
            end
            frame.ValUI_Hooked = true
        end
    end

    if GeneralDockManager then
        GeneralDockManager:SetScript("OnSizeChanged", nil)
        GeneralDockManager:SetScript("OnUpdate", nil)
        BanishFrame(GeneralDockManager)
    end

    BanishFrame(ChatFrameMenuButton)
    BanishFrame(ChatFrameChannelButton)
    BanishFrame(QuickJoinToastButton)
    BanishFrame(TextToSpeechButtonFrame)

    local function BlackHoleChatWindow(frameName)
        local chatFrame = _G[frameName]
        local chatTab = _G[frameName .. "Tab"]
        if chatFrame then
            chatFrame:UnregisterEvent("UPDATE_CHAT_WINDOWS")
            chatFrame:UnregisterEvent("UPDATE_FLOATING_CHAT_WINDOWS")
            if not chatFrame.ValUI_Lobotomized then
                chatFrame.AddMessage = function() end
                chatFrame:Clear()
                chatFrame.ValUI_Lobotomized = true
            end
            BanishFrame(chatFrame)
        end
        if chatTab then BanishFrame(chatTab) end
    end

    for _, frameName in ipairs(CHAT_FRAMES) do BlackHoleChatWindow(frameName) end
    hooksecurefunc("FCF_OpenTemporaryWindow", function()
        for _, frameName in ipairs(CHAT_FRAMES) do BlackHoleChatWindow(frameName) end
    end)

    local chatPanel = CreateFrame("Frame", "ValUI_ChatPanel", UIParent, "BackdropTemplate")
    self.Panel = chatPanel

    ValorianUIDB = ValorianUIDB or {}
    if ValorianUIDB.chatSize then
        chatPanel:SetSize(ValorianUIDB.chatSize.width, ValorianUIDB.chatSize.height)
    else
        chatPanel:SetSize(450, 220)
    end
    if ValorianUIDB.chatPos then
        chatPanel:SetPoint(ValorianUIDB.chatPos.p, UIParent, ValorianUIDB.chatPos.rp,
            ValorianUIDB.chatPos.x, ValorianUIDB.chatPos.y)
    else
        chatPanel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT",
            40, 60)
    end

    chatPanel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    chatPanel:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    chatPanel:SetMovable(true)
    chatPanel.dragOverlay = CreateFrame("Frame", nil, chatPanel)
    chatPanel.dragOverlay:SetAllPoints()
    chatPanel.dragOverlay:SetFrameLevel(chatPanel:GetFrameLevel() + 10)
    chatPanel.dragOverlay:EnableMouse(true)
    chatPanel.dragOverlay:RegisterForDrag("LeftButton")
    local dragTex = chatPanel.dragOverlay:CreateTexture(nil, "OVERLAY")
    dragTex:SetAllPoints()
    dragTex:SetColorTexture(0, 1, 0, 0.3)
    local dragText = chatPanel.dragOverlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dragText:SetPoint("CENTER")
    dragText:SetText("Valorian Chat Panel\n(Drag to Move)")
    chatPanel.dragOverlay:Hide()

    chatPanel.dragOverlay:SetScript("OnDragStart", function() chatPanel:StartMoving() end)
    chatPanel.dragOverlay:SetScript("OnDragStop", function()
        chatPanel:StopMovingOrSizing()
        local p, _, rp, x, y = chatPanel:GetPoint()
        ValorianUIDB.chatPos = { p = p, rp = rp, x = x, y = y }
    end)

    chatPanel:SetResizable(true)
    chatPanel:SetResizeBounds(250, 120, 1000, 800)

    local resizer = CreateFrame("Button", nil, chatPanel)
    chatPanel.resizer = resizer
    resizer:SetSize(16, 16)
    resizer:SetPoint("BOTTOMRIGHT", chatPanel, "BOTTOMRIGHT", -2, 2)
    resizer:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizer:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizer:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizer:GetNormalTexture():SetDesaturated(true)
    resizer:GetNormalTexture():SetAlpha(0.6)
    resizer:SetScript("OnMouseDown",
        function(self, button) if button == "LeftButton" then chatPanel:StartSizing("BOTTOMRIGHT") end end)
    resizer:SetScript("OnMouseUp",
        function(self, button)
            chatPanel:StopMovingOrSizing(); local w, h = chatPanel:GetSize(); ValorianUIDB.chatSize = {
                width = w,
                height =
                    h
            }
        end)

    local jumpBtn = CreateFrame("Button", nil, chatPanel, "BackdropTemplate")
    ns.jumpBtn = jumpBtn
    jumpBtn:SetSize(32, 32)
    jumpBtn:SetPoint("BOTTOMRIGHT", chatPanel, "BOTTOMRIGHT", -15, 15)
    jumpBtn:SetFrameLevel(50)
    jumpBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    jumpBtn:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    jumpBtn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    jumpBtn:Hide()

    local jumpIcon = jumpBtn:CreateTexture(nil, "ARTWORK")
    jumpIcon:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    jumpIcon:SetSize(20, 20)
    jumpIcon:SetPoint("CENTER")

    jumpBtn:SetScript("OnClick", function() if ns.ChatDisplay then ns.ChatDisplay:ScrollToBottom() end end)
    jumpBtn:SetScript("OnEnter",
        function()
            jumpBtn:SetBackdropColor(0.15, 0.15, 0.15, 1); jumpIcon:SetTexture(
                "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
        end)
    jumpBtn:SetScript("OnLeave",
        function()
            jumpBtn:SetBackdropColor(0.05, 0.05, 0.05, 0.9); jumpIcon:SetTexture(
                "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
        end)

    local function UpdateJumpButtonVisibility()
        if ns.ChatDisplay and ns.ChatDisplay:GetScrollOffset() > 0 then ns.jumpBtn:Show() else ns.jumpBtn:Hide() end
    end

    ns.GetOrCreateChatFrame = function(index)
        if ns.ChatFrames[index] then return ns.ChatFrames[index] end

        local scrollFrame = CreateFrame("ScrollingMessageFrame", "ValUI_ChatScroll" .. index, chatPanel)
        scrollFrame:SetPoint("TOPLEFT", chatPanel, "TOPLEFT", 10, -10)
        scrollFrame:SetPoint("BOTTOMRIGHT", chatPanel, "BOTTOMRIGHT", -10, 10)
        scrollFrame:SetShadowColor(0, 0, 0, 1)
        scrollFrame:SetShadowOffset(1, -1)
        scrollFrame:SetJustifyH("LEFT")
        scrollFrame:SetIndentedWordWrap(true)
        scrollFrame:SetFading(false)
        scrollFrame:SetMaxLines(2000)
        scrollFrame:SetInsertMode("BOTTOM")

        local fontSize = ns.db.chatFontSize or 14
        local fontPath = STANDARD_TEXT_FONT or ChatFontNormal:GetFont() or "Fonts\\FRIZQT__.TTF"
        scrollFrame:SetFont(fontPath, fontSize, "OUTLINE")
        scrollFrame:SetSpacing(3)

        scrollFrame:EnableMouseWheel(true)
        scrollFrame:SetScript("OnMouseWheel", function(selfFrame, delta)
            if delta > 0 then
                if IsShiftKeyDown() then selfFrame:ScrollToTop() else selfFrame:ScrollUp() end
            elseif delta < 0 then
                if IsShiftKeyDown() then selfFrame:ScrollToBottom() else selfFrame:ScrollDown() end
            end
        end)

        scrollFrame:SetHyperlinksEnabled(true)
        scrollFrame:SetScript("OnHyperlinkEnter", function(selfFrame, linkData, link)
            local linkType = string.match(linkData, "^([^:]+)")
            if linkType and (linkType == "item" or linkType == "spell" or linkType == "enchant" or linkType == "quest" or linkType == "talent" or linkType == "achievement" or linkType == "currency" or linkType == "battlepet" or linkType == "mount") then
                GameTooltip:SetOwner(selfFrame, "ANCHOR_CURSOR")
                GameTooltip:SetHyperlink(linkData)
                GameTooltip:Show()
            end
        end)
        scrollFrame:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)
        scrollFrame:SetScript("OnHyperlinkClick", function(selfFrame, linkData, link, button)
            if IsModifiedClick("CHATLINK") then
                ChatEdit_InsertLink(link)
            else
                SetItemRef(linkData, link, button,
                    selfFrame)
            end
        end)

        hooksecurefunc(scrollFrame, "ScrollUp", UpdateJumpButtonVisibility)
        hooksecurefunc(scrollFrame, "ScrollDown", UpdateJumpButtonVisibility)
        hooksecurefunc(scrollFrame, "ScrollToTop", UpdateJumpButtonVisibility)
        hooksecurefunc(scrollFrame, "ScrollToBottom", UpdateJumpButtonVisibility)

        scrollFrame:Hide()
        ns.ChatFrames[index] = scrollFrame
        return scrollFrame
    end

    local function IsMessageAllowed(tabData, chatType, msgTarget)
        local filters = tabData.filters
        local isChannel = string.match(chatType, "CHANNEL")

        if tabData.whisperTarget then
            if chatType == "WHISPER" or chatType == "WHISPER_INFORM" then
                return (msgTarget == tabData.whisperTarget)
            end
        end

        if string.match(chatType, "INSTANCE") then
            return filters["INSTANCE_CHAT"] or filters["INSTANCE_CHAT_LEADER"]
        elseif string.match(chatType, "RAID") then
            return filters["RAID"] or filters["RAID_LEADER"]
        elseif string.match(chatType, "PARTY") then
            return filters["PARTY"] or filters["PARTY_LEADER"]
        else
            return filters[chatType] or (isChannel and filters["CHANNEL"])
        end
    end

    ns.SwitchToTab = function(index)
        ns.ActiveChatTab = index
        ns.db.ActiveChatTab = index
        if ns.db.chatTabs[index] then ns.db.chatTabs[index].unread = false end

        for i, frame in pairs(ns.ChatFrames) do
            if i == index then
                frame:Show()
                ns.ChatDisplay = frame
                frame:ScrollToBottom()
            else
                frame:Hide()
            end
        end

        UpdateJumpButtonVisibility()
        if ns.UpdateTabVisuals then ns.UpdateTabVisuals() end
    end

    ns.RefreshChatDisplay = function()
        for _, frame in pairs(ns.ChatFrames) do frame:Clear() end
        ns.db.chatHistory = ns.db.chatHistory or {}

        for _, msgData in ipairs(ns.db.chatHistory) do
            local msgType = msgData.type or "SYSTEM"
            local msgTarget = msgData.target
            for i, tabData in ipairs(ns.db.chatTabs) do
                if IsMessageAllowed(tabData, msgType, msgTarget) then
                    local frame = ns.GetOrCreateChatFrame(i)
                    frame:AddMessage(msgData.text, msgData.r, msgData.g, msgData.b)
                end
            end
        end
        ns.SwitchToTab(ns.ActiveChatTab)
    end

    ns.TabFrames = ns.TabFrames or {}

    StaticPopupDialogs["VALUI_RENAME_TAB"] = {
        text = "Enter new tab name:",
        button1 = "Accept",
        button2 = "Cancel",
        hasEditBox = true,
        OnAccept = function(self, data)
            local inputFrame = self.EditBox or _G[self:GetName() .. "EditBox"]
            local text = inputFrame and inputFrame:GetText() or ""
            if text ~= "" then
                ns.db.chatTabs[data].name = text; ns.RenderTabs()
            end
        end,
        EditBoxOnEnterPressed = function(self)
            local text = self:GetText()
            local dialogData = self:GetParent().data
            if text and text ~= "" then
                ns.db.chatTabs[dialogData].name = text; ns.RenderTabs()
            end
            self:GetParent():Hide()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    ns.UpdateTabVisuals = function()
        for i, tab in ipairs(ns.TabFrames) do
            local tabData = ns.db.chatTabs[i]
            if tabData and tab:IsShown() then
                if ns.ActiveChatTab == i then
                    tab:SetBackdropColor(0.2, 0.2, 0.2, 1)
                    tab.text:SetTextColor(1, 1, 1)
                    tabData.unread = false
                else
                    tab:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
                    if tabData.unread then tab.text:SetTextColor(1, 0.4, 0.8) else tab.text:SetTextColor(0.6, 0.6, 0.6) end
                end
            end
        end
    end

    local function CreateValorianTab(index)
        local btn = CreateFrame("Button", "ValUI_ChatTab" .. index, chatPanel, "BackdropTemplate")
        btn:SetHeight(24)
        btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = { left = 2, right = 2, top = 2, bottom = 2 } })

        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        local bFont, bSize = btn.text:GetFont()
        btn.text:SetFont(bFont, bSize, "OUTLINE")
        btn.text:SetPoint("CENTER")

        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        btn:SetScript("OnEnter", function()
            if ns.ActiveChatTab ~= btn.id then
                btn.text:SetTextColor(1, 1, 1); btn:SetBackdropColor(0.12, 0.12, 0.12, 0.9)
            end
        end)
        btn:SetScript("OnLeave", function()
            if ns.ActiveChatTab ~= btn.id then
                local tabData = ns.db.chatTabs[btn.id]
                if tabData and tabData.unread then
                    btn.text:SetTextColor(1, 0.4, 0.8)
                else
                    btn.text:SetTextColor(0.6, 0.6,
                        0.6)
                end
                btn:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
            end
        end)

        btn:SetScript("OnClick", function(self, button)
            if button == "LeftButton" then
                ns.SwitchToTab(self.id)
            elseif button == "RightButton" then
                MenuUtil.CreateContextMenu(self, function(owner, rootDescription)
                    rootDescription:CreateTitle(ns.db.chatTabs[self.id].name .. " Settings")
                    rootDescription:CreateButton("Rename Tab",
                        function() StaticPopup_Show("VALUI_RENAME_TAB", nil, nil, self.id) end)
                    local filterMenu = rootDescription:CreateButton("Message Filters")
                    local filters = ns.db.chatTabs[self.id].filters

                    local function AddFilterToggle(label, key, siblingKey)
                        filterMenu:CreateCheckbox(label, function() return filters[key] end, function()
                            filters[key] = not filters[key]
                            if siblingKey then filters[siblingKey] = filters[key] end
                            if ns.ActiveChatTab == self.id then ns.RefreshChatDisplay() end
                        end)
                    end

                    AddFilterToggle("Say", "SAY")
                    AddFilterToggle("Yell", "YELL")
                    AddFilterToggle("Guild", "GUILD")
                    AddFilterToggle("Officer", "OFFICER")
                    AddFilterToggle("Party", "PARTY", "PARTY_LEADER")
                    AddFilterToggle("Raid", "RAID", "RAID_LEADER")
                    AddFilterToggle("Instance", "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER")
                    AddFilterToggle("Whisper", "WHISPER")
                    AddFilterToggle("Emote", "EMOTE")
                    AddFilterToggle("Public Channels", "CHANNEL")
                    AddFilterToggle("System Messages", "SYSTEM")
                    AddFilterToggle("Loot", "LOOT")
                    AddFilterToggle("Currency/Money", "CURRENCY")

                    if self.id > 1 then
                        rootDescription:CreateDivider()
                        rootDescription:CreateButton("|cffFF0000Delete Tab|r", function()
                            table.remove(ns.db.chatTabs, self.id)

                            local frameToDelete = ns.ChatFrames[self.id]
                            if frameToDelete then frameToDelete:Hide() end
                            table.remove(ns.ChatFrames, self.id)

                            local btnToDelete = ns.TabFrames[self.id]
                            if btnToDelete then btnToDelete:Hide() end
                            table.remove(ns.TabFrames, self.id)

                            for i, tBtn in ipairs(ns.TabFrames) do tBtn.id = i end

                            ns.SwitchToTab(1)
                            ns.RenderTabs()
                            ns.RefreshChatDisplay()
                        end)
                    end
                end)
            end
        end)
        return btn
    end

    ns.RenderTabs = function()
        for _, tab in ipairs(ns.TabFrames) do tab:Hide() end
        local xOffset = 10
        for i, tabData in ipairs(ns.db.chatTabs) do
            local tab = ns.TabFrames[i]
            if not tab then
                tab = CreateValorianTab(i); table.insert(ns.TabFrames, tab)
            end
            tab.id = i
            tab.text:SetText(tabData.name)
            local textWidth = tab.text:GetStringWidth() + 20
            tab:SetWidth(math.max(60, textWidth))
            tab:SetPoint("BOTTOMLEFT", chatPanel, "TOPLEFT", xOffset, -2)
            tab:Show()
            xOffset = xOffset + tab:GetWidth() + 5
        end
        if not ns.AddTabBtn then
            ns.AddTabBtn = CreateFrame("Button", nil, chatPanel, "BackdropTemplate")
            ns.AddTabBtn:SetSize(24, 24)
            ns.AddTabBtn:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile =
                "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 12,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            ns.AddTabBtn:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
            ns.AddTabBtn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
            ns.AddTabBtn.text = ns.AddTabBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            local bFont, bSize = ns.AddTabBtn.text:GetFont()
            ns.AddTabBtn.text:SetFont(bFont, bSize, "OUTLINE")
            ns.AddTabBtn.text:SetPoint("CENTER")
            ns.AddTabBtn.text:SetText("+")
            ns.AddTabBtn.text:SetTextColor(0.6, 0.6, 0.6)
            ns.AddTabBtn:SetScript("OnEnter",
                function(self)
                    self.text:SetTextColor(1, 1, 1); self:SetBackdropColor(0.12, 0.12, 0.12, 0.9)
                end)
            ns.AddTabBtn:SetScript("OnLeave",
                function(self)
                    self.text:SetTextColor(0.6, 0.6, 0.6); self:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
                end)
            ns.AddTabBtn:SetScript("OnClick", function()
                if #ns.db.chatTabs < 12 then
                    table.insert(ns.db.chatTabs,
                        { name = "New Tab", filters = { SAY = true, GUILD = true, PARTY = true } }); ns
                        .RenderTabs()
                else
                    print("|cffFF0000ValorianUI:|r Maximum of 12 chat tabs allowed.")
                end
            end)
        end
        ns.AddTabBtn:SetPoint("BOTTOMLEFT", chatPanel, "TOPLEFT", xOffset, -2)
        ns.AddTabBtn:Show()
        ns.UpdateTabVisuals()
    end

    local TabFader = CreateFrame("Frame")
    local currentTabAlpha = 1
    TabFader:SetScript("OnUpdate", function(self, elapsed)
        local targetAlpha = 1
        if ns.db.chatAutoFadeTabs then
            local isOver = false
            if chatPanel:IsMouseOver() then isOver = true end
            if ns.AddTabBtn and ns.AddTabBtn:IsMouseOver() then isOver = true end
            if ns.TabFrames then
                for _, tab in ipairs(ns.TabFrames) do if tab:IsShown() and tab:IsMouseOver() then isOver = true end end
            end
            local hasUnread = false
            if ns.db.chatTabs then
                for _, t in ipairs(ns.db.chatTabs) do
                    if t.unread then
                        hasUnread = true; break
                    end
                end
            end
            if not isOver and not hasUnread then targetAlpha = 0 end
        end

        if math.abs(currentTabAlpha - targetAlpha) > 0.01 then
            local step = elapsed * 5
            if currentTabAlpha < targetAlpha then
                currentTabAlpha = math.min(1, currentTabAlpha + step)
            else
                currentTabAlpha =
                    math.max(0, currentTabAlpha - step)
            end
            if ns.TabFrames then for _, tab in ipairs(ns.TabFrames) do tab:SetAlpha(currentTabAlpha) end end
            if ns.AddTabBtn then ns.AddTabBtn:SetAlpha(currentTabAlpha) end
        end
    end)

    local MemoryLoader = CreateFrame("Frame")
    local waitFrames = 15
    MemoryLoader:SetScript("OnUpdate", function(self)
        waitFrames = waitFrames - 1
        if waitFrames <= 0 then
            self:SetScript("OnUpdate", nil)
            ChatEngine:UpdateSettings()
            ns.RenderTabs()
            ns.RefreshChatDisplay()
            if ns.ChatDisplay then ns.ChatDisplay:AddMessage("|cffFFD100Valorian UI Chat Engine loaded.|r", 1, 1, 1) end
            ChatEngine.UpdateEditBoxFade()
        end
    end)

    local editBox = ChatFrame1EditBox
    if editBox then
        editBox:SetParent(UIParent)
        editBox:ClearAllPoints()
        editBox:SetPoint("TOPLEFT", chatPanel, "BOTTOMLEFT", 0, -2)
        editBox:SetPoint("TOPRIGHT", chatPanel, "BOTTOMRIGHT", 0, -2)
        editBox:SetHeight(32)

        local left, mid, right = _G["ChatFrame1EditBoxLeft"], _G["ChatFrame1EditBoxMid"], _G["ChatFrame1EditBoxRight"]
        local focusLeft, focusMid, focusRight = _G["ChatFrame1EditBoxFocusLeft"], _G["ChatFrame1EditBoxFocusMid"],
            _G["ChatFrame1EditBoxFocusRight"]
        if left then left:SetAlpha(0) end
        if mid then mid:SetAlpha(0) end
        if right then right:SetAlpha(0) end
        if focusLeft then focusLeft:SetAlpha(0) end
        if focusMid then focusMid:SetAlpha(0) end
        if focusRight then focusRight:SetAlpha(0) end

        if not editBox.ValorianBG then
            editBox.ValorianBG = CreateFrame("Frame", nil, editBox, "BackdropTemplate")
            editBox.ValorianBG:SetAllPoints()
            editBox.ValorianBG:SetFrameLevel(editBox:GetFrameLevel() - 1)
            editBox.ValorianBG:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile =
                "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 14,
                insets = { left = 3, right = 3, top = 3, bottom = 3 }
            })
            editBox.ValorianBG:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
            editBox.ValorianBG:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        end

        editBox:SetAltArrowKeyMode(false)

        editBox:HookScript("OnEditFocusGained", function() ChatEngine.UpdateEditBoxFade() end)
        editBox:HookScript("OnEditFocusLost", function() ChatEngine.UpdateEditBoxFade() end)
        editBox:HookScript("OnShow", function() ChatEngine.UpdateEditBoxFade() end)

        ns.db.commandHistory = ns.db.commandHistory or {}
        local cmdHistory = ns.db.commandHistory
        local historyIndex = #cmdHistory
        local draftText = ""

        hooksecurefunc(editBox, "AddHistoryLine", function(self, text)
            if #cmdHistory == 0 or cmdHistory[#cmdHistory] ~= text then
                table.insert(cmdHistory, text)
                if #cmdHistory > 200 then table.remove(cmdHistory, 1) end
            end
            historyIndex = #cmdHistory
        end)

        editBox:HookScript("OnKeyDown", function(self, key)
            if key == "UP" then
                if historyIndex == #cmdHistory then draftText = self:GetText() end
                if historyIndex > 0 then
                    self:SetText(cmdHistory[historyIndex]); historyIndex = historyIndex - 1
                end
            elseif key == "DOWN" then
                if historyIndex < #cmdHistory - 1 then
                    historyIndex = historyIndex + 1; self:SetText(cmdHistory[historyIndex + 1])
                elseif historyIndex == #cmdHistory - 1 then
                    historyIndex = #cmdHistory; self:SetText(draftText)
                end
            end
        end)

        editBox:HookScript("OnEditFocusLost", function(self)
            historyIndex = #cmdHistory; draftText = ""
        end)
    end

    local ChatListener = CreateFrame("Frame")
    local chatEvents = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_PARTY",
        "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_INSTANCE_CHAT",
        "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_CHANNEL",
        "CHAT_MSG_SYSTEM", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE", "CHAT_MSG_LOOT", "CHAT_MSG_CURRENCY",
        "CHAT_MSG_MONEY" }
    for _, event in ipairs(chatEvents) do ChatListener:RegisterEvent(event) end

    ChatListener:SetScript("OnEvent",
        function(self, event, text, playerName, language, channelName, playerName2, specialFlags, zoneChannelID,
                 channelIndex, channelBaseName, languageID, lineID, guid)
            if not ns.ChatDisplay then return end

            event = canaccessvalue(event) and event or ""
            text = canaccessvalue(text) and text or ""
            playerName = canaccessvalue(playerName) and playerName or ""
            channelName = canaccessvalue(channelName) and channelName or ""
            guid = canaccessvalue(guid) and guid or ""
            channelIndex = canaccessvalue(channelIndex) and channelIndex or 0

            local chatType = string.match(event, "CHAT_MSG_(.*)")
            if not chatType then return end

            if chatType == "CHANNEL" then chatType = "CHANNEL" .. channelIndex end
            local info = ChatTypeInfo[chatType] or ChatTypeInfo["SYSTEM"]
            local finalMessage = ""

            local cleanName = ""
            if playerName and playerName ~= "" then
                cleanName = strsplit("-", playerName)
            end
            local msgTarget = nil
            if chatType == "WHISPER" or chatType == "WHISPER_INFORM" then
                msgTarget = cleanName
            end

            local classColorHex = "ffffffff"
            local classIcon = ""

            if guid and guid ~= "" then
                local _, englishClass = GetPlayerInfoByGUID(guid)
                if englishClass then
                    local color = RAID_CLASS_COLORS[englishClass]
                    if color then classColorHex = color.colorStr end
                    if ns.db.chatClassIcons ~= false then
                        classIcon = "|A:classicon-" .. string.lower(englishClass) .. ":14:14:0:0|a "
                    end
                end
            end

            if chatType == "SYSTEM" or chatType == "LOOT" or chatType == "CURRENCY" or chatType == "MONEY" or not playerName or playerName == "" then
                finalMessage = text
            else
                local coloredName = classIcon .. "|c" .. classColorHex .. cleanName .. "|r"
                local channelTag = ""

                -- VALORIAN FIX: Explicitly append channel tags so Guild chat doesn't look identical to Say/Yell
                if chatType == "GUILD" then
                    channelTag = "[Guild] "
                elseif chatType == "OFFICER" then
                    channelTag = "[Officer] "
                elseif chatType == "PARTY" or chatType == "PARTY_LEADER" then
                    channelTag = "[Party] "
                elseif chatType == "RAID" or chatType == "RAID_LEADER" then
                    channelTag = "[Raid] "
                elseif chatType == "INSTANCE_CHAT" or chatType == "INSTANCE_CHAT_LEADER" then
                    channelTag = "[Instance] "
                elseif chatType == "SAY" then
                    channelTag = "[Say] "
                elseif chatType == "YELL" then
                    channelTag = "[Yell] "
                end

                if chatType == "WHISPER" then
                    finalMessage = coloredName .. " whispers: " .. text
                elseif chatType == "WHISPER_INFORM" then
                    finalMessage = "To " .. coloredName .. ": " .. text
                elseif string.find(chatType, "CHANNEL") then
                    finalMessage = "[" .. channelIndex .. ". " .. channelName .. "] [" .. coloredName .. "]: " .. text
                else
                    finalMessage = channelTag .. "[" .. coloredName .. "]: " .. text
                end
            end

            if ns.db.chatTimestamps ~= false then
                local timeStamp = date("%H:%M")
                local prefix = "|cffA0A0A0" .. timeStamp .. "|r |cff555555|||r "
                finalMessage = prefix .. finalMessage
            end

            ns.db.chatHistory = ns.db.chatHistory or {}
            table.insert(ns.db.chatHistory,
                { text = finalMessage, r = info.r, g = info.g, b = info.b, type = chatType, target = msgTarget })
            if #ns.db.chatHistory > 500 then table.remove(ns.db.chatHistory, 1) end

            if ns.db.autoWhisperTabs ~= false and msgTarget and msgTarget ~= "" then
                local found = false
                for _, tab in ipairs(ns.db.chatTabs) do
                    if tab.whisperTarget == msgTarget then
                        found = true; break
                    end
                end
                if not found and #ns.db.chatTabs < 12 then
                    table.insert(ns.db.chatTabs, {
                        name = msgTarget,
                        filters = { WHISPER = true, WHISPER_INFORM = true },
                        whisperTarget = msgTarget,
                        unread = true
                    })
                    ns.RenderTabs()
                end
            end

            for i, tabData in ipairs(ns.db.chatTabs) do
                if IsMessageAllowed(tabData, chatType, msgTarget) then
                    local frame = ns.GetOrCreateChatFrame(i)
                    frame:AddMessage(finalMessage, info.r, info.g, info.b)

                    if i == ns.ActiveChatTab then
                        if frame:GetScrollOffset() > 0 and ns.jumpBtn then ns.jumpBtn:Show() end
                    elseif tabData.whisperTarget and (chatType == "WHISPER" or chatType == "WHISPER_INFORM") then
                        tabData.unread = true
                    end
                end
            end
            ns.UpdateTabVisuals()
        end)
end
