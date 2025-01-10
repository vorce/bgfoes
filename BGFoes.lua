local specIcons = {
    ["DEATHKNIGHT"] = {
        ["Blood"] = "Interface\\Icons\\Spell_Deathknight_BloodPresence",
        ["Frost"] = "Interface\\Icons\\Spell_Deathknight_FrostPresence",
        ["Unholy"] = "Interface\\Icons\\Spell_Deathknight_UnholyPresence",
    },
    ["DEMONHUNTER"] = {
        ["Havoc"] = "Interface\\Icons\\Ability_DemonHunter_SpecDPS",
        ["Vengeance"] = "Interface\\Icons\\Ability_DemonHunter_SpecTank",
    },
    ["DRUID"] = {
        ["Balance"] = "Interface\\Icons\\Spell_Nature_StarFall",
        ["Feral"] = "Interface\\Icons\\Ability_Druid_CatForm",
        ["Guardian"] = "Interface\\Icons\\Ability_Racial_BearForm",
        ["Restoration"] = "Interface\\Icons\\Spell_Nature_HealingTouch",
    },
    ["EVOKER"] = {
        ["Devastation"] = "Interface\\Icons\\ABILITY_EVOKER_DEVASTATION",
        ["Preservation"] = "Interface\\Icons\\ABILITY_EVOKER_PRESERVATION",
        ["Augmentation"] = "Interface\\Icons\\ABILITY_EVOKER_AUGMENTATION",
    },
    ["HUNTER"] = {
        ["Beast Mastery"] = "Interface\\Icons\\Ability_Hunter_BeastTaming",
        ["Marksmanship"] = "Interface\\Icons\\Ability_Hunter_FocusedAim",
        ["Survival"] = "Interface\\Icons\\Ability_Hunter_SurvivalInstincts",
    },
    ["MAGE"] = {
        ["Arcane"] = "Interface\\Icons\\Spell_Holy_MagicalSentry",
        ["Fire"] = "Interface\\Icons\\Spell_Fire_FireBolt02",
        ["Frost"] = "Interface\\Icons\\Spell_Frost_FrostBolt02",
    },
    ["MONK"] = {
        ["Brewmaster"] = "Interface\\Icons\\Spell_Monk_Brewmaster_Spec",
        ["Mistweaver"] = "Interface\\Icons\\Spell_Monk_Mistweaver_Spec",
        ["Windwalker"] = "Interface\\Icons\\Spell_Monk_Windwalker_Spec",
    },
    ["PALADIN"] = {
        ["Holy"] = "Interface\\Icons\\Spell_Holy_HolyBolt",
        ["Protection"] = "Interface\\Icons\\Ability_Paladin_ShieldoftheTemplar",
        ["Retribution"] = "Interface\\Icons\\Spell_Holy_AuraOfLight",
    },
    ["PRIEST"] = {
        ["Discipline"] = "Interface\\Icons\\Spell_Holy_PowerWordShield",
        ["Holy"] = "Interface\\Icons\\Spell_Holy_GuardianSpirit",
        ["Shadow"] = "Interface\\Icons\\Spell_Shadow_ShadowWordPain",
    },
    ["ROGUE"] = {
        ["Assassination"] = "Interface\\Icons\\Ability_Rogue_DeadlyBrew",
        ["Outlaw"] = "Interface\\Icons\\Ability_Rogue_SinisterCalling",
        ["Subtlety"] = "Interface\\Icons\\Ability_Rogue_ShadowDance",
    },
    ["SHAMAN"] = {
        ["Elemental"] = "Interface\\Icons\\Spell_Nature_Lightning",
        ["Enhancement"] = "Interface\\Icons\\Spell_Shaman_ImprovedStormstrike",
        ["Restoration"] = "Interface\\Icons\\Spell_Nature_MagicImmunity",
    },
    ["WARLOCK"] = {
        ["Affliction"] = "Interface\\Icons\\Spell_Shadow_DeathCoil",
        ["Demonology"] = "Interface\\Icons\\Spell_Shadow_Metamorphosis",
        ["Destruction"] = "Interface\\Icons\\Spell_Shadow_RainOfFire",
    },
    ["WARRIOR"] = {
        ["Arms"] = "Interface\\Icons\\Ability_Warrior_SavageBlow",
        ["Fury"] = "Interface\\Icons\\Ability_Warrior_InnerRage",
        ["Protection"] = "Interface\\Icons\\INV_Shield_06",
    },
}

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
local existingFrames = { count = 0 }
local lastUpdateTimes = {}

local function ResetBGFoes()
    existingFrames = { count = 0 }
    lastUpdateTimes = {}
end

function hash(str)
    local h = 5381

    for i = 1, #str do
       h = math.fmod(h*32 + h + str:byte(i), 2147483648)
    end
    return h
end

local function GetSpecIconByName(classToken, specName)
    return specIcons[classToken] and specIcons[classToken][specName] or "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- Function to create an enemy frame inside the container
local function CreateEnemyFrame(name, classToken, specName)
    print("BGFoes: Creating frame for ", name)
    local nameHash = hash(name)
    local frame = CreateFrame("Frame", "BGFoes_EnemyFrame" .. nameHash, container)
    local font = "Fonts\\FRIZQT__.TTF"
    local frameHeight = 25
    local padding = 2
    -- print("BGFoes: Num existing frames", existingFrames.count)
    local y = -(frameHeight + padding) * (existingFrames.count + 1)
    print("BGFoes: Frame y coordinate ", y)
    frame:SetSize(180, frameHeight)  -- Set size for each enemy frame
    frame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, y)  -- Stack frames vertically

    -- create clickable area to target the enemy
    frame.secure = CreateFrame("Button", "BGFoes_EnemyFrameSecure" .. nameHash, frame, "SecureActionButtonTemplate")
    frame.secure:SetSize(180, frameHeight)
    frame.secure:SetPoint("LEFT", frame, "LEFT", 0, -padding)
    frame.secure:SetID(nameHash)
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

    -- Store the frame, health bar, and text in the existingFrames table
    existingFrames[nameHash] = {frame = frame}
    existingFrames.count = existingFrames.count + 1

    print("BGFoes: Frame created and stored under ", nameHash)
end

-- Function to update an enemy frame's health
local function UpdateEnemyHealth(nameHash, health, maxHealth)
    local frameData = existingFrames[nameHash]
    if frameData then
        print("BGFoes: Updating enemy health ", nameHash)
        frameData.frame.healthBar:SetMinMaxValues(0, maxHealth)
        frameData.frame.healthBar:SetValue(health)

        -- Update the health text
        frameData.frame.healthBar.healthText:SetText(string.format("%d%%", (health / maxHealth) * 100))
    end
end

local function ThrottleUpdate(nameHash)
    local currentTime = GetTime()
    local lastUpdateTime = lastUpdateTimes[nameHash] or 0
    if currentTime - lastUpdateTime >= 0.5 then  -- Update every 0.5 seconds
        lastUpdateTimes[nameHash] = currentTime
        return true
    end
    return false
end

-- Function to handle unit health changes
local function OnUnitHealthChange(event, unitID)
    local name = GetUnitName(unitID, true)
    --print("BGFoes: OnUnitHealthChange for name: ", name)
    local nameHash = hash(name)
    if name and existingFrames[nameHash] then
        local health = UnitHealth(unitID)
        local maxHealth = UnitHealthMax(unitID)
        if ThrottleUpdate(nameHash) then
            UpdateEnemyHealth(nameHash, health, maxHealth)
        end
    end
end

-- Get Player Faction
local function GetPlayerFaction()
    local playerFactionName = UnitFactionGroup("player")
    if playerFactionName == "Horde" then
        return 0
    else
        return 1
    end
end

-- Populate Enemies with correct data
local function PopulateEnemies()
    local playerFaction = GetPlayerFaction()
    local numScores = GetNumBattlefieldScores()
    print("BGFoes: Battleground participants detected ", numScores)
    for i = 1, numScores do
        -- https://wowpedia.fandom.com/wiki/API_GetBattlefieldScore
        local name, _, _, _, _, faction, race, _, classToken, _, _, _, _, _, _, specName = GetBattlefieldScore(i)
        local nameHash = hash(name)
        if faction ~= playerFaction and not existingFrames[nameHash] then
            CreateEnemyFrame(name, classToken, specName)
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
        local inInstance, instanceType = IsInInstance()
        if instanceType == "pvp" then
            print("BGFoes: Populating due to event: ", event)
            container:Show()
            PopulateEnemies()
        else
            print("BGFoes: Outside of BG, hiding")
            ResetBGFoes()
            container:Hide()
        end
    elseif event == "UPDATE_BATTLEFIELD_SCORE" then
        print("BGFoes: Populating due to event: ", event)
        PopulateEnemies()
    elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        OnUnitHealthChange(event, arg1)
    end
end)
