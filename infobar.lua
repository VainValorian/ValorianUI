-- ==========================================
-- VALORIAN UI: SYSTEM INFO BAR
-- ==========================================
local addonName, ns = ...
local InfoBar = ns.Engine:NewModule("InfoBar")

local infoBarFrame
local infoText

local date = date
local GetNetStats = GetNetStats
local GetFramerate = GetFramerate

-- ==========================================
-- 1. FRAME INITIALIZATION
-- ==========================================
function InfoBar:OnInit()
    infoBarFrame = CreateFrame("Frame", "ValorianUI_InfoBar", UIParent)
    infoBarFrame:SetSize(250, 20)
    infoBarFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -10)

    infoText = infoBarFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoText:SetPoint("LEFT", infoBarFrame, "LEFT", 0, 0)

    local fontPath, fontSize = infoText:GetFont()
    if fontPath then
        infoText:SetFont(fontPath, 11, "OUTLINE")
    end
    infoText:SetShadowColor(0, 0, 0, 1)
    infoText:SetShadowOffset(1, -1)

    infoBarFrame.dragOverlay = infoBarFrame:CreateTexture(nil, "OVERLAY")
    infoBarFrame.dragOverlay:SetAllPoints()
    infoBarFrame.dragOverlay:SetColorTexture(0, 1, 0, 0.4)
    infoBarFrame.dragOverlay:Hide()

    infoBarFrame:SetMovable(true)
    infoBarFrame:SetClampedToScreen(true)
    infoBarFrame:RegisterForDrag("LeftButton")

    infoBarFrame:SetScript("OnDragStart", function(self)
        if ValUI_FramesUnlocked then
            self:StartMoving()
        end
    end)

    infoBarFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, xOfs, yOfs = self:GetPoint()

        if not ns.db.frames["ValorianUI_InfoBar"] then ns.db.frames["ValorianUI_InfoBar"] = {} end
        ns.db.frames["ValorianUI_InfoBar"].point = point
        ns.db.frames["ValorianUI_InfoBar"].relativePoint = relativePoint or point
        ns.db.frames["ValorianUI_InfoBar"].xOfs = xOfs
        ns.db.frames["ValorianUI_InfoBar"].yOfs = yOfs
    end)

    if type(ValUI_MovableFrames) == "table" then
        local found = false
        for _, v in ipairs(ValUI_MovableFrames) do
            if v == "ValorianUI_InfoBar" then
                found = true
                break
            end
        end
        if not found then table.insert(ValUI_MovableFrames, "ValorianUI_InfoBar") end
    end
end

-- ==========================================
-- 2. ENABLE & EVENT LOOP
-- ==========================================
function InfoBar:OnEnable()
    local db = ns.db.frames["ValorianUI_InfoBar"]
    if db then
        if db.point then
            infoBarFrame:ClearAllPoints()
            infoBarFrame:SetPoint(db.point, UIParent, db.relativePoint or db.point, db.xOfs or db.x, db.yOfs or db.y)
        end
        if db.scale then
            infoBarFrame:SetScale(db.scale)
        end
    end

    if ns.db.showInfoBar == false then
        infoBarFrame:Hide()
    end

    local updateTimer = 0
    infoBarFrame:SetScript("OnUpdate", function(self, elapsed)
        updateTimer = updateTimer + elapsed
        if updateTimer > 1 then
            local timeStr = date("%H:%M")
            local _, _, _, latency = GetNetStats()
            local fps = math.floor(GetFramerate())

            infoText:SetText(string.format(
                "|cffA0A0A0Time:|r |cffFFFFFF%s|r   |cffA0A0A0Ping:|r |cffFFFFFF%d ms|r   |cffA0A0A0FPS:|r |cffFFFFFF%d|r",
                timeStr, latency or 0, fps
            ))
            updateTimer = 0
        end
    end)
end
