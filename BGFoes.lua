local function GenerateSpecIcons()
    local specIcons = {}
    for classID = 1, GetNumClasses() do
        local _, classToken = GetClassInfo(classID)
        if classToken then
            specIcons[classToken] = {}
            for specIndex = 1, GetNumSpecializationsForClassID(classID) do
                -- specId, specName, _, icon, role = ...
                local _, specName, _, icon, _ = GetSpecializationInfoForClassID(classID, specIndex)
                specIcons[classToken][specName] = icon
            end
        end
    end
    return specIcons
end

local specIcons = GenerateSpecIcons()

-- References to the real WoW API functions.
local WoWAPI = {
    GetUnitName = GetUnitName,
    UnitName = UnitName,
    UnitFactionGroup = UnitFactionGroup,
    GetBattlefieldScore = GetBattlefieldScore,
    GetNumBattlefieldScores = GetNumBattlefieldScores,
    RequestBattlefieldScoreData = RequestBattlefieldScoreData,
    GetTime = GetTime,
    IsInInstance = IsInInstance,
    UnitHealth = UnitHealth,
    UnitHealthMax = UnitHealthMax,
    C_Timer_NewTicker = C_Timer.NewTicker,
}

local function getRandomKey(tbl)
    local keys = {}
    for key in pairs(tbl) do
        table.insert(keys, key)
    end
    return keys[math.random(#keys)]
end

local function mock_GetBattlefieldScore(index)
    local playerFactionName = UnitFactionGroup("player")
    local enemyFaction = 0
    if playerFactionName == "Horde" then
        enemyFaction = 1
    else
        enemyFaction = 0
    end
    if index == 1 then
        local _, race = UnitRace("unit")
        local _, class = UnitClass("player")
        local currentSpec = GetSpecialization()
        local currentSpecName = currentSpec and select(2, GetSpecializationInfo(currentSpec))
        -- name, _, _, _, _, faction, race, _, classToken, _, _, _, _, _, _, specName
        return "Bad" .. UnitName("player"), 0, 0, 0, 0, enemyFaction, race, 0, class, 0, 0, 0, 0, 0, 0, currentSpecName
    else
        local mockRaces = {"Orc", "Human", "Troll", "Nightelf", "Dwarf", "Undead", "Gnome", "Tauren"}
        local classToken = getRandomKey(specIcons)
        local spec = getRandomKey(specIcons[classToken])
        return "Player" .. index, 0, 0, 0, 0, enemyFaction, mockRaces[math.random(#mockRaces)], 0, classToken, 0, 0, 0, 0, 0, 0, spec
    end
end

-- Stub version of the Wow API
local MockAPI = {
    GetUnitName = function(unitID, _) return "Player" .. unitID end,
    UnitName = function(unitID) return "Player" .. unitID end,
    UnitFactionGroup = function() return "Alliance" end,
    GetBattlefieldScore = mock_GetBattlefieldScore,
    GetNumBattlefieldScores = function() return 8 end,
    RequestBattlefieldScoreData = function() print("Mock: Requested battlefield score data") end,
    GetTime = function() return os.time() end,
    IsInInstance = function() return true, "pvp" end,
    UnitHealth = function(unitID) return math.random(1, 100) end,
    UnitHealthMax = function(unitID) return 100 end,
    C_Timer_NewTicker = function(interval, callback)
        local ticker = { cancelled = false }
        ticker.callback = function()
            if not ticker.cancelled then
                callback()
            end
        end
        return ticker
    end,
}

local API = WoWAPI

local container = CreateFrame("Frame", "BGFoes_EnemyContainer", UIParent)
container:SetSize(225, 400)  -- Set the size of the container
container:SetPoint("CENTER", UIParent, "CENTER")  -- Position it at the center of the screen

local border = CreateFrame("Frame", nil, container, "BackdropTemplate")
border:SetPoint("TOPLEFT", 0, -5)
border:SetPoint("BOTTOMRIGHT", 5, 0)
border:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = {
        left = 3,
        right = 3,
        top = 3,
        bottom = 3
    }
})
border:SetBackdropColor(0.05, 0.05, 0.05, 0.5)
border:SetBackdropBorderColor(0.4, 0.4, 0.4)

-- Show the container frame
container:Show()
container:SetMovable(true)  -- Allow it to be moved
container:EnableMouse(true)  -- Enable mouse interaction
container:SetClampedToScreen(true)  -- Prevent the frame from moving off the screen

container:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then
        self:StartMoving()  -- Start moving when left mouse button is clicked
    end
end)

container:SetScript("OnMouseUp", function(self)
    self:StopMovingOrSizing()  -- Stop moving when the mouse button is released
end)

-- Table to hold existing enemy frames
local bgFoes = { count = 0, enemyFrames = {}, availableIndices = {}, updateInterval = 5, updateHandle = nil, playerFaction = nil }
local lastUpdateTimes = {}

local function UpdateContainerHeight()
    local frameHeight = 25  -- Height of a single enemy frame
    local yPadding = 2       -- Vertical padding between frames
    local newHeight = (frameHeight + yPadding) * (bgFoes.count + 1)

    -- Ensure a minimum height
    container:SetHeight(math.max(newHeight, 50))
end

local function RemoveEnemyFrame(name)
    local frameData = bgFoes.enemyFrames[name]
    if frameData then
        -- print("BGFoes: Removing frame for ", name)
        -- print("BGFoes: New available index ", frameData.index)
        -- Hide and release the frame
        frameData.frame:Hide()
        frameData.frame = nil
        -- Remove from the bgFoes table
        bgFoes.enemyFrames[name] = nil
        table.insert(bgFoes.availableIndices, frameData.index)
        bgFoes.count = bgFoes.count - 1
        UpdateContainerHeight()
    end
end

local function ResetBGFoes()
    for key, value in pairs(bgFoes.enemyFrames) do
        RemoveEnemyFrame(key)
    end
    bgFoes = { count = 0, enemyFrames = {}, availableIndices = {}, updateInterval = 5, updateHandle = nil, playerFaction = nil }
    lastUpdateTimes = {}
end

local function StartPeriodicUpdate()
    if bgFoes.updateHandle then
        return
    end

    bgFoes.updateHandle = API.C_Timer_NewTicker(bgFoes.updateInterval, function()
        --print("BGFoes: Requesting battlefield score")
        API.RequestBattlefieldScoreData()
    end)
end

local function StopPeriodicUpdate()
    if bgFoes.updateHandle then
        bgFoes.updateHandle:Cancel()
        bgFoes.updateHandle = nil
    end
end

local function GetSpecIconByName(classToken, specName)
    return specIcons[classToken] and specIcons[classToken][specName] or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function GetFirstAvailableIndex()
    local availableCount = #bgFoes.availableIndices
    -- print("BGFoes: Available indices ", availableCount)
    if availableCount > 0 then
        return table.remove(bgFoes.availableIndices, 1)  -- Reuse the first/oldest available index
    else
        return bgFoes.count + 1
    end
end

-- Function to create an enemy frame inside the container
local function CreateEnemyFrame(name, classToken, specName)
    -- print("BGFoes: Creating frame for ", name)
    local enemyIndex = GetFirstAvailableIndex()
    local frame = CreateFrame("Frame", "BGFoes_EnemyFrame" .. enemyIndex, container)
    local font = "Fonts\\2002.ttf" -- this supports latin, koKR, ruRU but NOT chinese (zhCN, zhTW)
    local frameHeight = 25
    local padding = 2
    
    -- print("BGFoes: Num existing frames", bgFoes.count)
    local y = -(frameHeight + padding) * enemyIndex
    -- print("BGFoes: Enemy index ", enemyIndex)
    -- print("BGFoes: Frame y coordinate ", y)
    frame:SetSize(180, frameHeight)  -- Set size for each enemy frame
    frame:SetPoint("TOPLEFT", container, "TOPLEFT", (frameHeight / 2) - padding, y + (frameHeight / 2) - padding)  -- Stack frames vertically

    -- create clickable area to target the enemy
    frame.secure = CreateFrame("Button", "BGFoes_EnemyFrameSecure" .. enemyIndex, frame, "SecureActionButtonTemplate")
    frame.secure:SetSize(180, frameHeight)
    frame.secure:SetPoint("LEFT", frame, "LEFT", 0, -padding)
    frame.secure:SetID(enemyIndex)
    frame.secure:RegisterForClicks("AnyDown", "AnyUp")
    frame.secure:SetAttribute("type1", "macro")
    frame.secure:SetAttribute("type2", "macro")
    frame.secure:SetAttribute("macrotext1", string.format("/cleartarget\n/targetexact %s", name))
    frame.secure:SetAttribute("macrotext2", string.format("/targetexact %s\n/focus\n/targetlasttarget", name))

    frame.specIcon = CreateFrame("Frame", nil, frame)
    frame.specIcon:SetSize(frameHeight, frameHeight)
    frame.specIcon:SetPoint("LEFT", frame, 0, 0)
    frame.specIcon.Texture = frame.specIcon:CreateTexture(nil, "ARTWORK")
    frame.specIcon.Texture:SetAllPoints(frame.specIcon)
    frame.specIcon.Texture:SetTexture(GetSpecIconByName(classToken, specName))

    -- Create health bar inside the frame
    frame.healthBar = CreateFrame("StatusBar", nil, frame)
    frame.healthBar:SetSize(180, frameHeight)
    frame.healthBar:SetPoint("LEFT", frame.specIcon, "RIGHT", padding, 0)
    frame.healthBar:SetStatusBarTexture("Interface\\RaidFrame\\Raid-Bar-Hp-Fill")
    frame.healthBar:SetMinMaxValues(0, 100)
    frame.healthBar:SetValue(100)
    -- print("BGFoes: Frame class color for ", classToken)
    local classColor = RAID_CLASS_COLORS[classToken or "PRIEST"]
    frame.healthBar:SetStatusBarColor(classColor.r, classColor.g, classColor.b)

    -- Add the health text for health percentage
    frame.healthBar.healthText = frame.healthBar:CreateFontString(nil, "OVERLAY")
    frame.healthBar.healthText:SetPoint("RIGHT", frame.healthBar, "RIGHT", 0, 0)
    frame.healthBar.healthText:SetFont(font, 11)
    frame.healthBar.healthText:SetTextColor(1, 1, 1)
    frame.healthBar.healthText:SetText("100%")

    -- Create the name text
    frame.healthBar.nameText = frame.healthBar:CreateFontString(nil, "OVERLAY")
    frame.healthBar.nameText:SetPoint("LEFT", frame.healthBar, "LEFT", 0, 0)
    frame.healthBar.nameText:SetFont(font, 11)
    frame.healthBar.nameText:SetTextColor(1, 1, 1)
    frame.healthBar.nameText:SetText(name)

    -- Store the frame, health bar, and text in the bgFoes table
    bgFoes.enemyFrames[name] = {frame = frame, index = enemyIndex}
    bgFoes.count = bgFoes.count + 1

    -- print("BGFoes: Frame created for ", name)

    UpdateContainerHeight()
end

-- Function to update an enemy frame's health
local function UpdateEnemyHealth(name, health, maxHealth)
    local frameData = bgFoes.enemyFrames[name]
    if frameData then
        -- print("BGFoes: Updating enemy health ", name)
        frameData.frame.healthBar:SetMinMaxValues(0, maxHealth)
        frameData.frame.healthBar:SetValue(health)

        -- Update the health text
        frameData.frame.healthBar.healthText:SetText(string.format("%d%%", (health / maxHealth) * 100))
    end
end

local function ThrottleUpdate(name)
    local currentTime = API.GetTime()
    local lastUpdateTime = lastUpdateTimes[name] or 0
    if currentTime - lastUpdateTime >= 0.3 then  -- Update at most every 0.3 seconds for each enemy player
        lastUpdateTimes[name] = currentTime
        return true
    end
    return false
end

-- Function to handle unit health changes
local function OnUnitHealthChange(event, unitID)
    local name = API.GetUnitName(unitID, true)
    --print("BGFoes: OnUnitHealthChange for name: ", name)
    if name and bgFoes.enemyFrames[name] then
        local health = API.UnitHealth(unitID)
        local maxHealth = API.UnitHealthMax(unitID)
        if ThrottleUpdate(name) then
            UpdateEnemyHealth(name, health, maxHealth)
        end
    end
end

-- Get Player Faction
local function GetPlayerFaction(numBattleFieldScores)
    if bgFoes.playerFaction then
        return bgFoes.playerFaction
    else
        local playerName = API.UnitName("player")

        for i = 1, numBattleFieldScores do
            local name, _, _, _, _, faction = API.GetBattlefieldScore(i)
            if name == playerName then
                bgFoes.playerFaction = faction
                return bgFoes.playerFaction  -- 0 for Horde, 1 for Alliance
            end
        end
    end
end

-- Populate Enemies with correct data
local function PopulateEnemies()
    local numScores = API.GetNumBattlefieldScores()
    local playerFaction = GetPlayerFaction(numScores)

    local activeEnemies = {}

    -- print("BGFoes: Battleground participants detected ", numScores)
    for i = 1, numScores do
        -- https://wowpedia.fandom.com/wiki/API_GetBattlefieldScore
        local name, _, _, _, _, faction, race, _, classToken, _, _, _, _, _, _, specName = API.GetBattlefieldScore(i)
        if faction ~= playerFaction then
            activeEnemies[name] = true
            if not bgFoes.enemyFrames[name] then
                CreateEnemyFrame(name, classToken, specName)
            end
        end
    end

    for key, value in pairs(bgFoes.enemyFrames) do
        if not activeEnemies[key] then
            RemoveEnemyFrame(key)
        end
    end
end

-- Event handling for tracking enemy units
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("UNIT_HEALTH")
frame:RegisterEvent("UNIT_MAXHEALTH")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_LOGIN" then
        -- Start tracking enemies when logged in
        print("BGFoes: Loaded")
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        local inInstance, instanceType = API.IsInInstance()
        if instanceType == "pvp" then
            print("BGFoes: Populating due to event: ", event)
            container:Show()
            PopulateEnemies()
            StartPeriodicUpdate()
        else
            print("BGFoes: Outside of BG, hiding")
            container:Hide()
            StopPeriodicUpdate()
            ResetBGFoes()
        end
    elseif event == "UPDATE_BATTLEFIELD_SCORE" then
        -- print("BGFoes: Populating due to event: ", event)
        PopulateEnemies()
    elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        OnUnitHealthChange(event, arg1)
    end
end)

local testMode = false
SLASH_BGFOES1 = "/bgfoes"
SlashCmdList["BGFOES"] = function(arg)
    if arg == "test" then
        testMode = not testMode
        print("BGFoes: Test mode", testMode)
        if testMode then
            API = MockAPI
            container:Show() -- Show the frame for testing
            PopulateEnemies()
        else
            API = WoWAPI
            container:Hide() -- Hide the frame when not testing
            ResetBGFoes()
        end
    else
        print("BGFoes: Usage: /bgfoes test")
    end
end
