local ADDON_NAME, ns = ...

local LW = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceEvent-3.0", "AceConsole-3.0")
ns.LW = LW

-- Bind type constants (from ItemBind enum)
local BIND_ON_ACQUIRE = 1 -- Soulbound / BoP
local BIND_QUEST = 4

local MAX_ENTRIES = 50
local ROW_HEIGHT = 32
local FRAME_WIDTH = 400
local FRAME_HEIGHT = 360

local lootEntries = {}
local rows = {}

-------------------------------------------------------------------------------
-- Saved variables defaults
-------------------------------------------------------------------------------
local defaults = {
    minimumQuality = 2, -- Green and above
}

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------
local function ClassColoredName(playerName, playerClass)
    if playerClass then
        local color = RAID_CLASS_COLORS[playerClass]
        if color then
            return color:WrapTextInColorCode(playerName)
        end
    end
    return playerName
end

local function ShortName(fullName)
    local name = fullName:match("^([^%-]+)")
    return name or fullName
end

-------------------------------------------------------------------------------
-- UI
-------------------------------------------------------------------------------
local frame, scrollChild

local function CreateMainFrame()
    frame = CreateFrame("Frame", "LootWhispererFrame", UIParent, "BackdropTemplate")
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -200)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)

    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.8)
    frame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

    -- Title bar
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 8, -8)
    title:SetText("Loot Whisperer")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -2, -2)

    -- Clear button
    local clearBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    clearBtn:SetSize(60, 20)
    clearBtn:SetPoint("TOPRIGHT", closeBtn, "TOPLEFT", -2, -4)
    clearBtn:SetText("Clear")
    clearBtn:SetScript("OnClick", function()
        wipe(lootEntries)
        LW:RefreshDisplay()
    end)

    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -32)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)

    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(FRAME_WIDTH - 36, 1)
    scrollFrame:SetScrollChild(scrollChild)

    frame:SetScript("OnShow", function() LW:RefreshDisplay() end)

    -- Start hidden, only show when loot comes in
    frame:Hide()
end

local function GetOrCreateRow(index)
    if rows[index] then return rows[index] end

    local row = CreateFrame("Button", nil, scrollChild)
    row:SetSize(FRAME_WIDTH - 40, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)

    -- Highlight on hover
    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.1)

    -- Item icon
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ROW_HEIGHT - 4, ROW_HEIGHT - 4)
    icon:SetPoint("LEFT", 4, 0)
    row.icon = icon

    -- Player name
    local playerText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    playerText:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    playerText:SetWidth(100)
    playerText:SetJustifyH("LEFT")
    row.playerText = playerText

    -- Item link text
    local itemText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    itemText:SetPoint("LEFT", playerText, "RIGHT", 6, 0)
    itemText:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    itemText:SetJustifyH("LEFT")
    row.itemText = itemText

    -- Click to whisper
    row:SetScript("OnClick", function(self)
        if self.playerName then
            ChatFrame_OpenChat("/w " .. self.playerName .. " ")
        end
    end)

    -- Tooltip on hover for item
    row:SetScript("OnEnter", function(self)
        if self.itemLink then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.itemLink)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    rows[index] = row
    return row
end

function LW:RefreshDisplay()
    if not frame or not frame:IsShown() then return end

    -- Hide all existing rows
    for _, row in ipairs(rows) do
        row:Hide()
    end

    -- Show entries (newest first)
    for i = #lootEntries, 1, -1 do
        local displayIndex = #lootEntries - i + 1
        local entry = lootEntries[i]
        local row = GetOrCreateRow(displayIndex)

        row.playerName = entry.playerName
        row.itemLink = entry.itemLink
        row.playerText:SetText(entry.coloredName or ShortName(entry.playerName))
        row.itemText:SetText(entry.itemLink)
        row.icon:SetTexture(entry.itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
        row:Show()
    end

    scrollChild:SetHeight(math.max(1, #lootEntries * ROW_HEIGHT))
end

-------------------------------------------------------------------------------
-- Loot parsing
-------------------------------------------------------------------------------
-- CHAT_MSG_LOOT patterns:
-- LOOT_ITEM = "%s receives loot: %s."
-- LOOT_ITEM_MULTIPLE = "%s receives loot: %sx%d."
-- LOOT_ITEM_SELF = "You receive loot: %s."
-- LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."

local LOOT_PATTERNS = {}

local function BuildPatterns()
    -- Escape the global string patterns and convert %s / %d to captures
    local function PatternFromGlobal(globalStr)
        local pattern = globalStr
        pattern = pattern:gsub("%%", "%%%%")
        pattern = pattern:gsub("%%%%s", "(.+)")
        pattern = pattern:gsub("%%%%d", "(%%d+)")
        return pattern
    end

    -- Other player loot
    if LOOT_ITEM then
        LOOT_PATTERNS[#LOOT_PATTERNS + 1] = { pattern = PatternFromGlobal(LOOT_ITEM), selfLoot = false, hasCount = false }
    end
    if LOOT_ITEM_MULTIPLE then
        LOOT_PATTERNS[#LOOT_PATTERNS + 1] = { pattern = PatternFromGlobal(LOOT_ITEM_MULTIPLE), selfLoot = false, hasCount = true }
    end
    -- Self loot
    if LOOT_ITEM_SELF then
        LOOT_PATTERNS[#LOOT_PATTERNS + 1] = { pattern = PatternFromGlobal(LOOT_ITEM_SELF), selfLoot = true, hasCount = false }
    end
    if LOOT_ITEM_SELF_MULTIPLE then
        LOOT_PATTERNS[#LOOT_PATTERNS + 1] = { pattern = PatternFromGlobal(LOOT_ITEM_SELF_MULTIPLE), selfLoot = true, hasCount = true }
    end
end

local function ParseLootMessage(message)
    for _, info in ipairs(LOOT_PATTERNS) do
        if info.selfLoot then
            local itemLink = message:match(info.pattern)
            if itemLink then
                local playerName = UnitName("player")
                return playerName, itemLink
            end
        else
            local playerName, itemLink = message:match(info.pattern)
            if playerName and itemLink then
                return playerName, itemLink
            end
        end
    end
    return nil, nil
end

local function IsInGroupWith(name)
    local shortName = ShortName(name)
    if shortName == UnitName("player") then return true end

    local numGroup = GetNumGroupMembers()
    if numGroup == 0 then return false end

    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, numGroup do
        local unitName = UnitName(prefix .. i)
        if unitName and unitName == shortName then
            return true
        end
    end
    return false
end

local function GetUnitClass(name)
    local shortName = ShortName(name)
    if shortName == UnitName("player") then
        local _, class = UnitClass("player")
        return class
    end

    local numGroup = GetNumGroupMembers()
    if numGroup == 0 then return nil end

    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, numGroup do
        local unitName = UnitName(prefix .. i)
        if unitName and unitName == shortName then
            local _, class = UnitClass(prefix .. i)
            return class
        end
    end
    return nil
end

local pendingItems = {}

local function ProcessLootEntry(playerName, itemLink)
    local itemName, _, itemQuality, _, _, _, _, _, _, itemTexture, _, _, _, bindType =
        C_Item.GetItemInfo(itemLink)

    if not itemName then
        -- Item not cached yet, queue it
        pendingItems[itemLink] = playerName
        return
    end

    -- Filter: skip soulbound (BoP) and quest items
    if bindType == BIND_ON_ACQUIRE or bindType == BIND_QUEST then
        return
    end

    -- Filter by minimum quality
    if itemQuality < LootWhispererDB.minimumQuality then
        return
    end

    local playerClass = GetUnitClass(playerName)
    local entry = {
        playerName = playerName,
        itemLink = itemLink,
        itemTexture = itemTexture,
        itemQuality = itemQuality,
        coloredName = ClassColoredName(ShortName(playerName), playerClass),
        timestamp = time(),
    }

    lootEntries[#lootEntries + 1] = entry

    -- Cap entries
    while #lootEntries > MAX_ENTRIES do
        table.remove(lootEntries, 1)
    end

    -- Auto-show the frame when new loot comes in
    if not frame:IsShown() then
        frame:Show()
    end

    LW:RefreshDisplay()
end

-------------------------------------------------------------------------------
-- Event handlers
-------------------------------------------------------------------------------
function LW:OnInitialize()
    -- Init saved variables
    if not LootWhispererDB then
        LootWhispererDB = {}
    end
    for k, v in pairs(defaults) do
        if LootWhispererDB[k] == nil then
            LootWhispererDB[k] = v
        end
    end

    BuildPatterns()
    CreateMainFrame()

    self:RegisterChatCommand("lw", "SlashCommand")
    self:RegisterChatCommand("lootwhisperer", "SlashCommand")
end

function LW:OnEnable()
    self:RegisterEvent("CHAT_MSG_LOOT")
    self:RegisterEvent("GET_ITEM_INFO_RECEIVED")
end

function LW:CHAT_MSG_LOOT(_, message)
    local playerName, itemLink = ParseLootMessage(message)
    if not playerName or not itemLink then return end

    -- Only track group members
    if not IsInGroupWith(playerName) then return end

    ProcessLootEntry(playerName, itemLink)
end

function LW:GET_ITEM_INFO_RECEIVED(_, itemID, success)
    if not success then return end

    -- Retry any pending items that were waiting on cache
    for itemLink, playerName in pairs(pendingItems) do
        local id = tonumber(itemLink:match("item:(%d+)"))
        if id and id == itemID then
            pendingItems[itemLink] = nil
            ProcessLootEntry(playerName, itemLink)
        end
    end
end

-------------------------------------------------------------------------------
-- Slash commands
-------------------------------------------------------------------------------
function LW:SlashCommand(input)
    local cmd = (input or ""):trim():lower()

    if cmd == "show" then
        frame:Show()
    elseif cmd == "hide" then
        frame:Hide()
    elseif cmd == "clear" then
        wipe(lootEntries)
        self:RefreshDisplay()
        self:Print("Loot history cleared.")
    elseif cmd == "quality" then
        self:Print(("Minimum quality: %d (0=Poor, 1=Common, 2=Uncommon, 3=Rare, 4=Epic)"):format(LootWhispererDB.minimumQuality))
    elseif cmd:match("^quality%s+%d$") then
        local q = tonumber(cmd:match("quality%s+(%d)"))
        LootWhispererDB.minimumQuality = q
        self:Print(("Minimum quality set to %d."):format(q))
    elseif cmd == "test" then
        self:InjectTestData()
    else
        self:Print("Loot Whisperer commands:")
        self:Print("  /lw show - Show the loot frame")
        self:Print("  /lw hide - Hide the loot frame")
        self:Print("  /lw clear - Clear loot history")
        self:Print("  /lw quality [0-4] - Set/view minimum item quality")
        self:Print("  /lw test - Add sample entries for testing")
    end
end

-------------------------------------------------------------------------------
-- Test data
-------------------------------------------------------------------------------
local TEST_ITEMS = {
    -- { itemID, fakePlayer, fakeClass }
    { 19019,  "Thunderfury",  "WARRIOR" },   -- Thunderfury, Blessed Blade of the Windseeker (BoE legendary)
    { 21563,  "Healbot",      "PRIEST" },    -- Don Rodrigo's Band (BoE epic ring)
    { 14551,  "Sneakstab",    "ROGUE" },     -- Edgemaster's Handguards (BoE epic)
    { 18803,  "Frostmage",    "MAGE" },      -- Finkle's Lava Dredger (BoE epic)
    { 2589,   "Bankalt",      "WARLOCK" },   -- Linen Cloth (no bind, common trade good)
}

function LW:InjectTestData()
    if not frame:IsShown() then
        frame:Show()
    end

    local pending = 0
    for _, testItem in ipairs(TEST_ITEMS) do
        local itemID, playerName, playerClass = testItem[1], testItem[2], testItem[3]
        local itemName, itemLink, itemQuality, _, _, _, _, _, _, itemTexture = C_Item.GetItemInfo(itemID)

        if itemName then
            lootEntries[#lootEntries + 1] = {
                playerName = playerName,
                itemLink = itemLink,
                itemTexture = itemTexture,
                itemQuality = itemQuality,
                coloredName = ClassColoredName(playerName, playerClass),
                timestamp = time(),
            }
        else
            -- Item not cached yet, request it and retry after a short delay
            pending = pending + 1
            C_Timer.After(1.5, function()
                local name, link, quality, _, _, _, _, _, _, texture = C_Item.GetItemInfo(itemID)
                if name then
                    lootEntries[#lootEntries + 1] = {
                        playerName = playerName,
                        itemLink = link,
                        itemTexture = texture,
                        itemQuality = quality,
                        coloredName = ClassColoredName(playerName, playerClass),
                        timestamp = time(),
                    }
                    self:RefreshDisplay()
                end
            end)
        end
    end

    self:RefreshDisplay()
    self:Print("Injected test loot entries. Some may appear after a moment if items need caching.")
end
