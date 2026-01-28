-- Stablemaster: Main UI Frame (Modern Style)
Stablemaster.Debug("UI/MainFrame.lua loading...")

local STYLE = StablemasterUI.Style
local mainFrame = nil

-- Track active tab ("mounts" or "pets")
local activeTab = "mounts"

-- Create a modern filter menu
local filterMenu = nil
local petFilterMenu = nil

local function CreateFilterMenu(parent, currentFilters, onFilterChange)
    if filterMenu then
        return filterMenu
    end

    local menu = CreateFrame("Frame", "StablemasterFilterMenu", UIParent, "BackdropTemplate")
    menu:SetSize(175, 140)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    StablemasterUI.CreateBackdrop(menu)
    menu:Hide()

    local yOffset = -STYLE.padding

    -- Show unowned checkbox
    local showUnownedCheck = StablemasterUI.CreateCheckbox(menu, "Show unowned mounts")
    showUnownedCheck:SetPoint("TOPLEFT", menu, "TOPLEFT", STYLE.padding, yOffset)
    showUnownedCheck.check.onClick = function(self, checked)
        currentFilters.showUnowned = checked
        onFilterChange()
    end
    menu.showUnownedCheck = showUnownedCheck
    yOffset = yOffset - 22

    -- Hide unusable checkbox
    local hideUnusableCheck = StablemasterUI.CreateCheckbox(menu, "Hide unusable mounts")
    hideUnusableCheck:SetPoint("TOPLEFT", menu, "TOPLEFT", STYLE.padding, yOffset)
    hideUnusableCheck.check.onClick = function(self, checked)
        currentFilters.hideUnusable = checked
        onFilterChange()
    end
    menu.hideUnusableCheck = hideUnusableCheck
    yOffset = yOffset - 22

    -- Flying only checkbox
    local flyingOnlyCheck = StablemasterUI.CreateCheckbox(menu, "Flying mounts only")
    flyingOnlyCheck:SetPoint("TOPLEFT", menu, "TOPLEFT", STYLE.padding, yOffset)
    flyingOnlyCheck.check.onClick = function(self, checked)
        currentFilters.flyingOnly = checked
        onFilterChange()
    end
    menu.flyingOnlyCheck = flyingOnlyCheck
    yOffset = yOffset - 28

    -- Divider
    local divider = StablemasterUI.CreateDivider(menu, 160)
    divider:SetPoint("TOP", menu, "TOP", 0, yOffset)
    yOffset = yOffset - 8

    -- Source filter label
    local sourceLabel = StablemasterUI.CreateText(menu, STYLE.fontSizeSmall, STYLE.textDim)
    sourceLabel:SetPoint("TOPLEFT", menu, "TOPLEFT", STYLE.padding, yOffset)
    sourceLabel:SetText("Source Filter:")
    yOffset = yOffset - 18

    -- Favorites only checkbox
    local favoritesCheck = StablemasterUI.CreateCheckbox(menu, "Favorites only")
    favoritesCheck:SetPoint("TOPLEFT", menu, "TOPLEFT", STYLE.padding, yOffset)
    favoritesCheck.check.onClick = function(self, checked)
        currentFilters.sourceFilter = checked and "favorites" or "all"
        onFilterChange()
    end
    menu.favoritesCheck = favoritesCheck

    -- Update function to sync checkboxes with current filter state
    menu.UpdateCheckboxes = function(self)
        self.showUnownedCheck.check:SetChecked(currentFilters.showUnowned)
        self.hideUnusableCheck.check:SetChecked(currentFilters.hideUnusable)
        self.flyingOnlyCheck.check:SetChecked(currentFilters.flyingOnly)
        self.favoritesCheck.check:SetChecked(currentFilters.sourceFilter == "favorites")
    end

    filterMenu = menu
    return menu
end

local function CreatePetFilterMenu(parent, currentFilters, onFilterChange)
    if petFilterMenu then
        return petFilterMenu
    end

    local menu = CreateFrame("Frame", "StablemasterPetFilterMenu", UIParent, "BackdropTemplate")
    menu:SetSize(175, 70)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    StablemasterUI.CreateBackdrop(menu)
    menu:Hide()

    local yOffset = -STYLE.padding

    -- Favorites only checkbox
    local favoritesCheck = StablemasterUI.CreateCheckbox(menu, "Favorites only")
    favoritesCheck:SetPoint("TOPLEFT", menu, "TOPLEFT", STYLE.padding, yOffset)
    favoritesCheck.check.onClick = function(self, checked)
        currentFilters.favoritesOnly = checked
        onFilterChange()
    end
    menu.favoritesCheck = favoritesCheck
    yOffset = yOffset - 22

    -- Can battle checkbox
    local canBattleCheck = StablemasterUI.CreateCheckbox(menu, "Battle pets only")
    canBattleCheck:SetPoint("TOPLEFT", menu, "TOPLEFT", STYLE.padding, yOffset)
    canBattleCheck.check.onClick = function(self, checked)
        currentFilters.canBattleOnly = checked
        onFilterChange()
    end
    menu.canBattleCheck = canBattleCheck

    -- Update function to sync checkboxes with current filter state
    menu.UpdateCheckboxes = function(self)
        self.favoritesCheck.check:SetChecked(currentFilters.favoritesOnly or false)
        self.canBattleCheck.check:SetChecked(currentFilters.canBattleOnly or false)
    end

    petFilterMenu = menu
    return menu
end

function StablemasterUI.CreateSettingsPanel(parent)
    local settingsPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    settingsPanel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", STYLE.padding, STYLE.padding + 18)
    settingsPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -STYLE.padding, STYLE.padding + 18)
    settingsPanel:SetHeight(90)
    StablemasterUI.CreateBackdrop(settingsPanel, 0.6)

    -- Settings header
    local settingsTitle = StablemasterUI.CreateHeaderText(settingsPanel, "Settings")
    settingsTitle:SetPoint("TOPLEFT", settingsPanel, "TOPLEFT", STYLE.padding, -STYLE.padding)

    -- Left column: Pack Overlap Mode
    local overlapLabel = StablemasterUI.CreateText(settingsPanel, STYLE.fontSizeSmall, STYLE.textDim)
    overlapLabel:SetPoint("TOPLEFT", settingsTitle, "BOTTOMLEFT", 0, -6)
    overlapLabel:SetText("When multiple packs match, choose a mount from:")

    local unionRadio = StablemasterUI.CreateRadioButton(settingsPanel, "Any matching pack")
    unionRadio:SetPoint("TOPLEFT", overlapLabel, "BOTTOMLEFT", 0, -2)
    unionRadio:SetSize(160, 18)

    local intersectionRadio = StablemasterUI.CreateRadioButton(settingsPanel, "Mounts common to all matching packs")
    intersectionRadio:SetPoint("TOPLEFT", unionRadio, "BOTTOMLEFT", 0, 0)
    intersectionRadio:SetSize(160, 18)

    -- Radio button behavior
    local function UpdateOverlapMode(mode)
        StablemasterDB.settings.packOverlapMode = mode
        unionRadio.radio:SetChecked(mode == "union")
        intersectionRadio.radio:SetChecked(mode == "intersection")

        -- Re-evaluate active packs
        C_Timer.After(0.1, Stablemaster.SelectActivePack)
    end

    unionRadio.radio:SetScript("OnClick", function() UpdateOverlapMode("union") end)
    intersectionRadio.radio:SetScript("OnClick", function() UpdateOverlapMode("intersection") end)

    -- Right column: Other options (aligned with left column radio buttons)
    local flyingCheck = StablemasterUI.CreateCheckbox(settingsPanel, "Prefer flying mounts")
    flyingCheck:SetPoint("LEFT", unionRadio, "LEFT", 280, 0)
    flyingCheck:SetSize(150, 18)

    flyingCheck.check.onClick = function(self, checked)
        StablemasterDB.settings.preferFlyingMounts = checked
    end

    local verboseCheck = StablemasterUI.CreateCheckbox(settingsPanel, "Show summon messages")
    verboseCheck:SetPoint("LEFT", intersectionRadio, "LEFT", 280, 0)
    verboseCheck:SetSize(160, 18)

    verboseCheck.check.onClick = function(self, checked)
        StablemasterDB.settings.verboseMode = checked
    end

    local minimapCheck = StablemasterUI.CreateCheckbox(settingsPanel, "Show minimap icon")
    minimapCheck:SetPoint("LEFT", flyingCheck, "RIGHT", 40, 0)
    minimapCheck:SetSize(150, 18)

    minimapCheck.check.onClick = function(self, checked)
        StablemasterDB.settings.showMinimapIcon = checked
        if Stablemaster.MinimapIcon then
            Stablemaster.MinimapIcon.SetVisible(checked)
        end
    end

    -- Initialize settings
    settingsPanel:SetScript("OnShow", function()
        local overlapMode = StablemasterDB.settings.packOverlapMode or "union"
        UpdateOverlapMode(overlapMode)
        flyingCheck.check:SetChecked(StablemasterDB.settings.preferFlyingMounts)
        verboseCheck.check:SetChecked(StablemasterDB.settings.verboseMode)
        -- Default to true if not set
        local showMinimap = StablemasterDB.settings.showMinimapIcon
        if showMinimap == nil then showMinimap = true end
        minimapCheck.check:SetChecked(showMinimap)
    end)

    return settingsPanel
end

function StablemasterUI.CreateMainFrame()
    if mainFrame then
        return mainFrame
    end

    -- Main frame with modern style
    local frame = CreateFrame("Frame", "StablemasterMainFrame", UIParent, "BackdropTemplate")
    frame:SetSize(800, 600)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetFrameStrata("HIGH")
    StablemasterUI.CreateBackdrop(frame)

    -- Title bar
    local titleBar = StablemasterUI.CreateTitleBar(frame, "Stablemaster")
    frame.titleBar = titleBar

    -- Create settings panel first (above version/macro text)
    local settingsPanel = StablemasterUI.CreateSettingsPanel(frame)
    frame.settingsPanel = settingsPanel

    -- Version number in bottom left corner (inside the backdrop)
    local versionText = StablemasterUI.CreateText(frame, STYLE.fontSizeSmall, STYLE.textDim)
    versionText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", STYLE.padding, STYLE.padding + 2)
    versionText:SetText("v" .. (Stablemaster.version or "0.8"))

    -- Macro instructions in bottom right (inside the backdrop)
    local macroInstructions = StablemasterUI.CreateText(frame, STYLE.fontSizeSmall, STYLE.textDim)
    macroInstructions:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -STYLE.padding, STYLE.padding + 2)
    macroInstructions:SetText("Macros: |cff66cc99/sm mount|r and |cff66cc99/sm pet|r")

    -- Left panel (mounts and pets with tabs)
    local mountPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    mountPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", STYLE.padding, -STYLE.headerHeight - STYLE.padding)
    mountPanel:SetPoint("BOTTOMLEFT", settingsPanel, "TOPLEFT", 0, STYLE.padding)
    mountPanel:SetWidth(380)
    StablemasterUI.CreateBackdrop(mountPanel, 0.6)

    -- Tab buttons container
    local tabContainer = CreateFrame("Frame", nil, mountPanel)
    tabContainer:SetPoint("TOPLEFT", mountPanel, "TOPLEFT", STYLE.padding, -STYLE.padding)
    tabContainer:SetPoint("TOPRIGHT", mountPanel, "TOPRIGHT", -STYLE.padding, -STYLE.padding)
    tabContainer:SetHeight(24)

    -- Create tab buttons
    local mountsTab = CreateFrame("Button", nil, tabContainer, "BackdropTemplate")
    mountsTab:SetSize(100, 24)
    mountsTab:SetPoint("LEFT", tabContainer, "LEFT", 0, 0)
    StablemasterUI.CreateBackdrop(mountsTab, 0.8)

    local mountsTabText = mountsTab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mountsTabText:SetPoint("CENTER", mountsTab, "CENTER", 0, 0)
    mountsTabText:SetText("Mounts")
    mountsTab.text = mountsTabText

    local petsTab = CreateFrame("Button", nil, tabContainer, "BackdropTemplate")
    petsTab:SetSize(100, 24)
    petsTab:SetPoint("LEFT", mountsTab, "RIGHT", 4, 0)
    StablemasterUI.CreateBackdrop(petsTab, 0.8)

    local petsTabText = petsTab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    petsTabText:SetPoint("CENTER", petsTab, "CENTER", 0, 0)
    petsTabText:SetText("Pets")
    petsTab.text = petsTabText

    -- Counter (shared, updates based on active tab)
    local itemCounter = StablemasterUI.CreateText(mountPanel, STYLE.fontSizeNormal, STYLE.accent)
    itemCounter:SetPoint("TOP", tabContainer, "BOTTOM", 0, -4)
    itemCounter:SetText("Loading...")
    mountPanel.mountCounter = itemCounter  -- Keep this name for mount list compatibility
    mountPanel.petCounter = itemCounter    -- Also reference for pet list

    -- Search box (shared)
    local searchBox = StablemasterUI.CreateEditBox(mountPanel, 180, 22)
    searchBox:SetPoint("TOPLEFT", mountPanel, "TOPLEFT", STYLE.padding, -58)
    searchBox:SetText("Search...")
    searchBox:SetTextColor(unpack(STYLE.textDim))

    -- Filter button (shared, but behavior changes based on tab)
    local filterButton = StablemasterUI.CreateButton(mountPanel, 80, STYLE.buttonHeight, "Filters")
    filterButton:SetPoint("TOPRIGHT", mountPanel, "TOPRIGHT", -STYLE.padding, -58)

    -- Initialize mount filter state
    local mountFilters = {
        showUnowned = false,
        hideUnusable = true,
        flyingOnly = false,
        sourceFilter = "all",
        searchText = ""
    }

    -- Initialize pet filter state
    local petFilters = {
        favoritesOnly = false,
        canBattleOnly = false,
        searchText = ""
    }

    -- Create mount list (initially visible)
    local mountList = StablemasterUI.CreateMountList(mountPanel)
    mountPanel.mountList = mountList
    mountPanel.currentFilters = mountFilters

    -- Create pet list (initially hidden)
    local petList = StablemasterUI.CreatePetList(mountPanel)
    petList:Hide()
    mountPanel.petList = petList
    mountPanel.petFilters = petFilters

    -- Store references for backward compatibility
    mountPanel.filterCheck = {GetChecked = function() return mountFilters.showUnowned end}
    mountPanel.hideUnusableCheck = {GetChecked = function() return mountFilters.hideUnusable end}
    mountPanel.flyingOnlyCheck = {GetChecked = function() return mountFilters.flyingOnly end}

    -- Create mount filter menu
    local mountMenu = CreateFilterMenu(mountPanel, mountFilters, function()
        StablemasterUI.UpdateMountList(mountList, mountFilters)
    end)

    -- Create pet filter menu
    local petMenu = CreatePetFilterMenu(mountPanel, petFilters, function()
        StablemasterUI.UpdatePetList(petList, petFilters)
    end)

    -- Function to update tab appearance
    local function UpdateTabAppearance()
        if activeTab == "mounts" then
            mountsTab:SetBackdropColor(STYLE.accent[1] * 0.3, STYLE.accent[2] * 0.3, STYLE.accent[3] * 0.3, 0.9)
            mountsTab:SetBackdropBorderColor(unpack(STYLE.accent))
            mountsTabText:SetTextColor(1, 1, 1, 1)

            petsTab:SetBackdropColor(STYLE.bgColor[1], STYLE.bgColor[2], STYLE.bgColor[3], 0.6)
            petsTab:SetBackdropBorderColor(unpack(STYLE.borderColor))
            petsTabText:SetTextColor(0.6, 0.6, 0.6, 1)
        else
            petsTab:SetBackdropColor(STYLE.accent[1] * 0.3, STYLE.accent[2] * 0.3, STYLE.accent[3] * 0.3, 0.9)
            petsTab:SetBackdropBorderColor(unpack(STYLE.accent))
            petsTabText:SetTextColor(1, 1, 1, 1)

            mountsTab:SetBackdropColor(STYLE.bgColor[1], STYLE.bgColor[2], STYLE.bgColor[3], 0.6)
            mountsTab:SetBackdropBorderColor(unpack(STYLE.borderColor))
            mountsTabText:SetTextColor(0.6, 0.6, 0.6, 1)
        end
    end

    -- Function to switch tabs
    local function SwitchToTab(tabName)
        activeTab = tabName
        UpdateTabAppearance()

        -- Hide any open menus
        mountMenu:Hide()
        petMenu:Hide()

        if tabName == "mounts" then
            mountList:Show()
            petList:Hide()
            -- Update search text
            if searchBox:GetText() ~= "Search..." then
                mountFilters.searchText = searchBox:GetText()
            end
            StablemasterUI.UpdateMountList(mountList, mountFilters)
        else
            mountList:Hide()
            petList:Show()
            -- Update search text
            if searchBox:GetText() ~= "Search..." then
                petFilters.searchText = searchBox:GetText()
            end
            StablemasterUI.UpdatePetList(petList, petFilters)
        end
    end

    -- Tab click handlers
    mountsTab:SetScript("OnClick", function() SwitchToTab("mounts") end)
    petsTab:SetScript("OnClick", function() SwitchToTab("pets") end)

    -- Tab hover effects
    mountsTab:SetScript("OnEnter", function(self)
        if activeTab ~= "mounts" then
            self:SetBackdropColor(STYLE.accent[1] * 0.15, STYLE.accent[2] * 0.15, STYLE.accent[3] * 0.15, 0.8)
        end
    end)
    mountsTab:SetScript("OnLeave", function(self)
        UpdateTabAppearance()
    end)
    petsTab:SetScript("OnEnter", function(self)
        if activeTab ~= "pets" then
            self:SetBackdropColor(STYLE.accent[1] * 0.15, STYLE.accent[2] * 0.15, STYLE.accent[3] * 0.15, 0.8)
        end
    end)
    petsTab:SetScript("OnLeave", function(self)
        UpdateTabAppearance()
    end)

    -- Initialize tab appearance
    UpdateTabAppearance()

    -- Filter button click handler (shows appropriate menu based on active tab)
    filterButton:SetScript("OnClick", function(self)
        local currentMenu = activeTab == "mounts" and mountMenu or petMenu
        local otherMenu = activeTab == "mounts" and petMenu or mountMenu

        -- Hide the other menu
        otherMenu:Hide()

        if currentMenu:IsShown() then
            currentMenu:Hide()
        else
            currentMenu:UpdateCheckboxes()
            currentMenu:ClearAllPoints()
            currentMenu:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, -2)
            currentMenu:Show()
        end
    end)

    -- Hide menu when clicking elsewhere
    local menuHideFrame = CreateFrame("Frame", "StablemasterMenuHideFrame", UIParent)
    menuHideFrame:SetAllPoints(UIParent)
    menuHideFrame:SetFrameStrata("FULLSCREEN")
    menuHideFrame:EnableMouse(true)
    menuHideFrame:Hide()
    menuHideFrame:SetScript("OnMouseDown", function()
        mountMenu:Hide()
        petMenu:Hide()
        menuHideFrame:Hide()
    end)

    mountMenu:SetScript("OnShow", function(self)
        menuHideFrame:Show()
    end)
    mountMenu:SetScript("OnHide", function(self)
        if not petMenu:IsShown() then
            menuHideFrame:Hide()
        end
    end)
    petMenu:SetScript("OnShow", function(self)
        menuHideFrame:Show()
    end)
    petMenu:SetScript("OnHide", function(self)
        if not mountMenu:IsShown() then
            menuHideFrame:Hide()
        end
    end)

    -- Search box functionality
    searchBox:SetScript("OnEditFocusGained", function(self)
        if self:GetText() == "Search..." then
            self:SetText("")
            self:SetTextColor(unpack(STYLE.text))
        end
    end)
    searchBox:SetScript("OnEditFocusLost", function(self)
        if self:GetText() == "" then
            self:SetText("Search...")
            self:SetTextColor(unpack(STYLE.textDim))
        end
    end)

    searchBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        if text ~= "Search..." then
            if activeTab == "mounts" then
                mountFilters.searchText = text
                StablemasterUI.UpdateMountList(mountList, mountFilters)
            else
                petFilters.searchText = text
                StablemasterUI.UpdatePetList(petList, petFilters)
            end
        end
    end)

    -- Store tab switching function for external use
    mountPanel.switchToTab = SwitchToTab

    -- Right panel (packs)
    local packPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    packPanel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -STYLE.padding, -STYLE.headerHeight - STYLE.padding)
    packPanel:SetPoint("BOTTOMRIGHT", settingsPanel, "TOPRIGHT", 0, STYLE.padding)
    packPanel:SetWidth(380)
    StablemasterUI.CreateBackdrop(packPanel, 0.6)

    StablemasterUI.SetupPackPanel(packPanel)

    frame.mountPanel = mountPanel
    frame.packPanel = packPanel

    frame:Hide()
    table.insert(UISpecialFrames, "StablemasterMainFrame")

    mainFrame = frame
    return frame
end

function StablemasterUI.ToggleMainFrame()
    local frame = StablemasterUI.CreateMainFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        -- Reset active tab to mounts
        activeTab = "mounts"

        -- Initialize with current filters and update counter
        local mountFilters = frame.mountPanel.currentFilters
        mountFilters.searchText = ""
        StablemasterUI.UpdateMountList(frame.mountPanel.mountList, mountFilters)

        -- Also initialize pet filters (but don't show pet list yet)
        local petFilters = frame.mountPanel.petFilters
        petFilters.searchText = ""

        frame.packPanel.refreshPacks()

        -- Switch to mounts tab to ensure proper initialization
        if frame.mountPanel.switchToTab then
            frame.mountPanel.switchToTab("mounts")
        end

        -- Force counter update on first load
        C_Timer.After(0.1, function()
            if frame.mountPanel.mountCounter then
                StablemasterUI.UpdateMountList(frame.mountPanel.mountList, mountFilters)
            end
        end)
    end
end

Stablemaster.Debug("UI/MainFrame.lua loaded")
