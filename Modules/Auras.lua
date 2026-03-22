local _, ns = ...
local Auras = ns.Engine:NewModule("Auras")

local hooksecurefunc = hooksecurefunc
local CreateFrame = CreateFrame
local STANDARD_TEXT_FONT = STANDARD_TEXT_FONT
local DebuffTypeColor = DebuffTypeColor
local ipairs = ipairs

local function SkinAuraButton(btn, buttonInfo)
    if not btn then return end

    if not btn.isValorianSkinned then
        -- 1. Icon configuration
        if btn.Icon then
            btn.Icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        end

        -- 2. Purge native borders
        if btn.Border then
            btn.Border:SetAlpha(0); btn.Border:SetTexture("")
        end
        if btn.DebuffBorder then
            btn.DebuffBorder:SetAlpha(0); btn.DebuffBorder:SetTexture("")
        end
        if btn.TempEnchantBorder then
            btn.TempEnchantBorder:SetAlpha(0); btn.TempEnchantBorder:SetTexture("")
        end

        -- 3. Create the metallic Gothic border (Hardware-Accelerated Overlay)
        if not btn.ValorianBorder and btn.Icon then
            local borderTex = btn:CreateTexture(nil, "OVERLAY", nil, 7)
            borderTex:SetPoint("TOPLEFT", btn.Icon, "TOPLEFT", -4, 4)
            borderTex:SetPoint("BOTTOMRIGHT", btn.Icon, "BOTTOMRIGHT", 4, -4)
            borderTex:SetTexture("Interface\\AchievementFrame\\UI-Achievement-IconFrame")
            borderTex:SetTexCoord(0, 0.5625, 0, 0.5625)
            borderTex:SetDesaturated(true)
            btn.ValorianBorder = borderTex
        end

        -- 4. Typography
        local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
        if btn.Duration then btn.Duration:SetFont(font, 11, "OUTLINE") end
        if btn.Count then btn.Count:SetFont(font, 11, "OUTLINE") end

        btn.isValorianSkinned = true
    end

    -- Color Logic (Runs on Update)
    if btn.ValorianBorder then
        local info = buttonInfo or btn.buttonInfo or btn.auraData

        -- Foolproof Check: Look for harmful flag OR verify it lives inside the Debuff Container
        local isHarmful = (info and info.isHarmful) or (btn:GetParent() == _G.DebuffFrame.AuraContainer)

        if isHarmful then
            local dispelType = info and info.dispelName
            -- Default to bright pure red for debuffs, or use dispel type color if available
            local color = (dispelType and DebuffTypeColor[dispelType]) or { r = 1, g = 0, b = 0 }
            btn.ValorianBorder:SetVertexColor(color.r, color.g, color.b, 1)
        else
            -- Lock to neutral silver for standard buffs
            btn.ValorianBorder:SetVertexColor(0.8, 0.8, 0.8, 1)
        end
    end
end

-- We securely hook the frame instances directly, rather than the global Mixin
local function HookAuraInstance(btn)
    if not btn or btn.isValorianHooked then return end

    if btn.UpdateInfo then
        hooksecurefunc(btn, "UpdateInfo", SkinAuraButton)
    elseif btn.Update then
        hooksecurefunc(btn, "Update", SkinAuraButton)
    end

    btn.isValorianHooked = true
    SkinAuraButton(btn) -- Force initial skin
end

local function ProcessAuraContainer(container)
    if not container then return end
    for _, child in ipairs({ container:GetChildren() }) do
        if child.Icon then -- Basic sanity check to ensure it's an aura button
            HookAuraInstance(child)
        end
    end
end

function Auras:OnEnable()
    if not ns.db.enableAurasSkinning then return end

    -- Catch any existing buttons spawned during load
    if _G.BuffFrame and _G.BuffFrame.AuraContainer then ProcessAuraContainer(_G.BuffFrame.AuraContainer) end
    if _G.DebuffFrame and _G.DebuffFrame.AuraContainer then ProcessAuraContainer(_G.DebuffFrame.AuraContainer) end

    -- Set up an event listener to catch any new buttons created by the FramePools mid-combat
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("UNIT_AURA")
    frame:SetScript("OnEvent", function(_, _, unit)
        if unit == "player" then
            if _G.BuffFrame and _G.BuffFrame.AuraContainer then ProcessAuraContainer(_G.BuffFrame.AuraContainer) end
            if _G.DebuffFrame and _G.DebuffFrame.AuraContainer then ProcessAuraContainer(_G.DebuffFrame.AuraContainer) end
        end
    end)

    -- Handle native Temporary Enchants (e.g. Rogue Poisons, Shaman Imbues)
    for i = 1, 3 do
        local tempBtn = _G["TempEnchant" .. i]
        if tempBtn then HookAuraInstance(tempBtn) end
    end
end
