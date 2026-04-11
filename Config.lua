local ADDON_NAME, ns = ...
local LW = ns.LW

-------------------------------------------------------------------------------
-- Config panel (registered in Blizzard Settings)
-------------------------------------------------------------------------------
function LW:InitConfig()
    local panel = CreateFrame("Frame", "LootWhispererConfigPanel", UIParent)
    panel:Hide()

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Loot Whisperer")

    local desc = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText("Track non-soulbound loot from your group and whisper the looter.")

    local yOffset = -70

    ---------------------------------------------------------------------------
    -- Minimum Quality dropdown
    ---------------------------------------------------------------------------
    local qualityLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    qualityLabel:SetPoint("TOPLEFT", 16, yOffset)
    qualityLabel:SetText("Minimum Item Quality")

    local QUALITY_OPTIONS = {
        { text = "|cff9d9d9dPoor|r",      value = 0 },
        { text = "|cffffffffCommon|r",     value = 1 },
        { text = "|cff1eff00Uncommon|r",   value = 2 },
        { text = "|cff0070ddRare|r",       value = 3 },
        { text = "|cffa335eeEpic|r",       value = 4 },
        { text = "|cffff8000Legendary|r",  value = 5 },
    }

    local qualityDropdown = CreateFrame("Frame", "LootWhispererQualityDropdown", panel, "UIDropDownMenuTemplate")
    qualityDropdown:SetPoint("TOPLEFT", qualityLabel, "BOTTOMLEFT", -16, -4)

    local function QualityDropdown_OnClick(self, arg1)
        LootWhispererDB.minimumQuality = arg1
        UIDropDownMenu_SetText(qualityDropdown, QUALITY_OPTIONS[arg1 + 1].text)
    end

    local function QualityDropdown_Initialize(self, level)
        for _, opt in ipairs(QUALITY_OPTIONS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = opt.text
            info.arg1 = opt.value
            info.func = QualityDropdown_OnClick
            info.checked = (LootWhispererDB.minimumQuality == opt.value)
            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_SetWidth(qualityDropdown, 150)
    UIDropDownMenu_Initialize(qualityDropdown, QualityDropdown_Initialize)

    panel:SetScript("OnShow", function()
        local q = LootWhispererDB.minimumQuality or 2
        UIDropDownMenu_SetText(qualityDropdown, QUALITY_OPTIONS[q + 1].text)
    end)

    yOffset = yOffset - 70

    ---------------------------------------------------------------------------
    -- Only Usable checkbox
    ---------------------------------------------------------------------------
    local usableCheck = CreateFrame("CheckButton", "LootWhispererUsableCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    usableCheck:SetPoint("TOPLEFT", 16, yOffset)
    usableCheck.Text:SetText("Only show items usable by my class/spec")
    usableCheck.Text:SetFontObject("GameFontHighlight")
    usableCheck:SetScript("OnClick", function(self)
        LootWhispererDB.onlyUsable = self:GetChecked()
    end)

    local usableTooltip = "When enabled, only items your current class and specialization can use will appear in the loot frame."
    usableCheck:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Only Usable Items", 1, 1, 1)
        GameTooltip:AddLine(usableTooltip, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    usableCheck:SetScript("OnLeave", GameTooltip_Hide)

    -- Refresh checkbox state when panel opens
    panel:HookScript("OnShow", function()
        usableCheck:SetChecked(LootWhispererDB.onlyUsable)
    end)

    ---------------------------------------------------------------------------
    -- Register with Blizzard Settings
    ---------------------------------------------------------------------------
    local category = Settings.RegisterCanvasLayoutCategory(panel, "Loot Whisperer")
    Settings.RegisterAddOnCategory(category)
    ns.settingsCategory = category
end
