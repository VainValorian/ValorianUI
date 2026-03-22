local _, ns = ...
local ActionBars = ns.Engine:NewModule("ActionBars")

local _G = _G
local hooksecurefunc = hooksecurefunc
local CreateFrame = CreateFrame
local STANDARD_TEXT_FONT = STANDARD_TEXT_FONT
local ipairs = ipairs
local math = math

local standardPrefixes = {
    "ActionButton",
    "MultiBarBottomLeftButton",
    "MultiBarBottomRightButton",
    "MultiBarRightButton",
    "MultiBarLeftButton",
    "MultiBar5Button",
    "MultiBar6Button",
    "MultiBar7Button"
}

local altPrefixes = {
    "PetActionButton",
    "StanceButton"
}

local function SkinButton(btn)
    if not btn or btn.isSkinned then return end

    -- 1. Icon configuration
    if btn.icon then
        btn.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    end

    -- 2. Hide Native Elements
    if btn.SlotBackground then btn.SlotBackground:Hide() end
    if btn.Border then btn.Border:SetTexture("") end
    if btn.NewActionTexture then btn.NewActionTexture:SetTexture("") end

    -- 3. Securely suppress normal texture restoration
    local normalTex = btn:GetNormalTexture()
    if normalTex then
        normalTex:SetTexture("")
        normalTex:SetAlpha(0)
    end

    hooksecurefunc(btn, "SetNormalTexture", function(self)
        if self.ignoreTexture then return end
        self.ignoreTexture = true
        self:SetNormalTexture("")
        self.ignoreTexture = false
    end)

    -- 4. Dialog Border Overlay (BackdropTemplate)
    if not btn.ValorianBorder then
        local border = CreateFrame("Frame", nil, btn, "BackdropTemplate")
        border:SetPoint("TOPLEFT", btn, "TOPLEFT", -3, 3)
        border:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 3, -3)
        border:SetFrameLevel(btn:GetFrameLevel() + 2)
        border:SetBackdrop({
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 14,
        })
        -- Set to a slightly darkened metallic state
        border:SetBackdropBorderColor(0.8, 0.8, 0.8, 1)
        btn.ValorianBorder = border
    end

    -- 4b. Optional: Add a dark background behind the icon to fill transparency
    if not btn.ValorianBG then
        local bgTex = btn:CreateTexture(nil, "BACKGROUND", nil, -7)
        bgTex:SetAllPoints(btn)
        bgTex:SetColorTexture(0.05, 0.05, 0.05, 0.9)
        btn.ValorianBG = bgTex
    end

    -- 5. Typography Formatting
    local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    if btn.HotKey then btn.HotKey:SetFont(font, 12, "OUTLINE") end
    if btn.Name then btn.Name:SetFont(font, 12, "OUTLINE") end
    if btn.Count then btn.Count:SetFont(font, 12, "OUTLINE") end

    -- 6. Flat Interaction Textures (Strictly anchored to Icon)
    btn:SetHighlightTexture("Interface\\ChatFrame\\ChatFrameBackground")
    local hl = btn:GetHighlightTexture()
    if hl and btn.icon then
        hl:ClearAllPoints()
        hl:SetPoint("TOPLEFT", btn.icon, "TOPLEFT", 0, 0)
        hl:SetPoint("BOTTOMRIGHT", btn.icon, "BOTTOMRIGHT", 0, 0)
        hl:SetVertexColor(1, 1, 1, 0.25)
    end

    btn:SetPushedTexture("Interface\\ChatFrame\\ChatFrameBackground")
    local pu = btn:GetPushedTexture()
    if pu and btn.icon then
        pu:ClearAllPoints()
        pu:SetPoint("TOPLEFT", btn.icon, "TOPLEFT", 0, 0)
        pu:SetPoint("BOTTOMRIGHT", btn.icon, "BOTTOMRIGHT", 0, 0)
        pu:SetVertexColor(0.9, 0.8, 0.1, 0.5)
    end

    btn:SetCheckedTexture("Interface\\ChatFrame\\ChatFrameBackground")
    local ch = btn:GetCheckedTexture()
    if ch and btn.icon then
        ch:ClearAllPoints()
        ch:SetPoint("TOPLEFT", btn.icon, "TOPLEFT", 0, 0)
        ch:SetPoint("BOTTOMRIGHT", btn.icon, "BOTTOMRIGHT", 0, 0)
        ch:SetVertexColor(0, 1, 0, 0.3)
    end

    -- 7. Cooldown Shadow Alignment
    if btn.cooldown and btn.icon then
        btn.cooldown:ClearAllPoints()
        btn.cooldown:SetPoint("TOPLEFT", btn.icon, "TOPLEFT", 0, 0)
        btn.cooldown:SetPoint("BOTTOMRIGHT", btn.icon, "BOTTOMRIGHT", 0, 0)
    end

    btn.isSkinned = true
end

function ActionBars:OnEnable()
    if not ns.db.enableActionBarsSkinning then return end

    for _, prefix in ipairs(standardPrefixes) do
        for i = 1, 12 do
            local btn = _G[prefix .. i]
            if btn then SkinButton(btn) end
        end
    end

    for _, prefix in ipairs(altPrefixes) do
        for i = 1, 10 do
            local btn = _G[prefix .. i]
            if btn then SkinButton(btn) end
        end
    end
end
