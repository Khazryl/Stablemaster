-- Stablemaster: Pet List UI (Modern Style)
Stablemaster.Debug("UI/PetList.lua loading...")

local STYLE = StablemasterUI.Style

-- Pet quality colors (matches WoW's pet quality system)
local PET_QUALITY_COLORS = {
    [0] = {0.6, 0.6, 0.6, 1},  -- Poor (gray)
    [1] = {1.0, 1.0, 1.0, 1},  -- Common (white)
    [2] = {0.12, 1.0, 0.0, 1}, -- Uncommon (green)
    [3] = {0.0, 0.44, 0.87, 1}, -- Rare (blue)
    [4] = {0.64, 0.21, 0.93, 1}, -- Epic (purple)
    [5] = {1.0, 0.50, 0.0, 1},  -- Legendary (orange)
}

-- Pet type icons (battle pet family icons)
local PET_TYPE_ICONS = {
    [1] = "Interface\\PetBattles\\PetIcon-Humanoid",
    [2] = "Interface\\PetBattles\\PetIcon-Dragon",
    [3] = "Interface\\PetBattles\\PetIcon-Flying",
    [4] = "Interface\\PetBattles\\PetIcon-Undead",
    [5] = "Interface\\PetBattles\\PetIcon-Critter",
    [6] = "Interface\\PetBattles\\PetIcon-Magical",
    [7] = "Interface\\PetBattles\\PetIcon-Elemental",
    [8] = "Interface\\PetBattles\\PetIcon-Beast",
    [9] = "Interface\\PetBattles\\PetIcon-Water",
    [10] = "Interface\\PetBattles\\PetIcon-Mechanical",
}

function StablemasterUI.CreatePetList(parent)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", STYLE.padding, -85)
    scrollFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -26, STYLE.padding)

    -- Style the scrollbar
    if scrollFrame.ScrollBar then
        local scrollBar = scrollFrame.ScrollBar
        if scrollBar.ScrollUpButton then
            scrollBar.ScrollUpButton:SetAlpha(0)
            scrollBar.ScrollUpButton:EnableMouse(false)
        end
        if scrollBar.ScrollDownButton then
            scrollBar.ScrollDownButton:SetAlpha(0)
            scrollBar.ScrollDownButton:EnableMouse(false)
        end
        if scrollBar.ThumbTexture then
            scrollBar.ThumbTexture:SetTexture(STYLE.bgTexture)
            scrollBar.ThumbTexture:SetVertexColor(unpack(STYLE.accent))
            scrollBar.ThumbTexture:SetSize(6, 40)
        end
    end

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(340, 1)
    scrollFrame:SetScrollChild(content)

    scrollFrame.content = content
    scrollFrame.buttons = {}
    scrollFrame.selectedPets = {}  -- Track multi-selected pets by petGUID
    return scrollFrame
end

-- Helper to update pet button visual state based on selection
local function UpdatePetButtonSelectionVisual(button, isSelected)
    if isSelected then
        button:SetBackdropColor(0.2, 0.5, 0.2, 0.8)  -- Green for selected
        button:SetBackdropBorderColor(0.3, 0.8, 0.3, 1)
    else
        button:SetBackdropColor(STYLE.bgColor[1], STYLE.bgColor[2], STYLE.bgColor[3], 0.6)
        button:SetBackdropBorderColor(unpack(STYLE.borderColor))
    end
end

-- Helper to clear all pet selections
function StablemasterUI.ClearPetSelections(scrollFrame)
    if scrollFrame and scrollFrame.selectedPets then
        wipe(scrollFrame.selectedPets)
        -- Update visuals for all buttons
        for _, btn in ipairs(scrollFrame.buttons) do
            if btn.petData then
                UpdatePetButtonSelectionVisual(btn, false)
            end
        end
    end
end

function StablemasterUI.CreatePetButton(parent, index)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(320, 40)
    StablemasterUI.CreateBackdrop(button, 0.6)

    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetMovable(true)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(STYLE.iconSize, STYLE.iconSize)
    icon:SetPoint("LEFT", button, "LEFT", 4, 0)
    button.icon = icon

    -- Level indicator (small text on corner of icon)
    local levelText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    levelText:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
    levelText:SetTextColor(1, 1, 1, 1)
    button.levelText = levelText

    local name = StablemasterUI.CreateText(button, STYLE.fontSizeNormal, STYLE.text)
    name:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    name:SetPoint("RIGHT", button, "RIGHT", -8, 0)
    button.name = name

    button:SetScript("OnEnter", function(self)
        -- Check if this pet is selected
        local isSelected = self.scrollFrame and self.scrollFrame.selectedPets and
                          self.petData and self.scrollFrame.selectedPets[self.petData.petGUID]
        if isSelected then
            self:SetBackdropColor(0.25, 0.6, 0.25, 0.9)  -- Brighter green on hover when selected
            self:SetBackdropBorderColor(0.4, 0.9, 0.4, 1)
        else
            self:SetBackdropColor(STYLE.accent[1] * 0.15, STYLE.accent[2] * 0.15, STYLE.accent[3] * 0.15, 0.8)
            self:SetBackdropBorderColor(unpack(STYLE.accent))
        end

        if self.petData then
            -- Show enhanced tooltip with 3D model (same as mount list behavior)
            StablemasterUI.ShowPetTooltipWithModel(self, self.petData)
        end
    end)
    button:SetScript("OnLeave", function(self)
        -- Check if this pet is selected
        local isSelected = self.scrollFrame and self.scrollFrame.selectedPets and
                          self.petData and self.scrollFrame.selectedPets[self.petData.petGUID]
        if isSelected then
            self:SetBackdropColor(0.2, 0.5, 0.2, 0.8)  -- Green for selected
            self:SetBackdropBorderColor(0.3, 0.8, 0.3, 1)
        else
            self:SetBackdropColor(STYLE.bgColor[1], STYLE.bgColor[2], STYLE.bgColor[3], 0.6)
            self:SetBackdropBorderColor(unpack(STYLE.borderColor))
        end
        StablemasterUI.HidePetTooltip()
    end)

    button:SetScript("OnDragStart", function(self)
        if self.petData and self.petData.petGUID then
            -- Build list of pets to drag (selected ones + current if not selected)
            local petsToDrag = {}
            local hasSelections = self.scrollFrame and self.scrollFrame.selectedPets and next(self.scrollFrame.selectedPets)

            if hasSelections then
                -- If there are selections, use them (include current pet if not already selected)
                for petGUID, petData in pairs(self.scrollFrame.selectedPets) do
                    table.insert(petsToDrag, petData)
                end
                -- If current pet isn't in selection, add it
                if not self.scrollFrame.selectedPets[self.petData.petGUID] then
                    table.insert(petsToDrag, self.petData)
                end
            else
                -- No selections, just drag the current pet
                table.insert(petsToDrag, self.petData)
            end

            self.petsToDrag = petsToDrag

            local dragFrame = CreateFrame("Frame", nil, UIParent)
            dragFrame:SetFrameStrata("TOOLTIP")
            dragFrame:SetAlpha(0.8)

            if #petsToDrag == 1 then
                -- Single pet drag display
                dragFrame:SetSize(200, 30)
                local dragIcon = dragFrame:CreateTexture(nil, "ARTWORK")
                dragIcon:SetSize(24, 24)
                dragIcon:SetPoint("LEFT", dragFrame, "LEFT", 0, 0)
                dragIcon:SetTexture(petsToDrag[1].icon)

                local dragText = dragFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                dragText:SetPoint("LEFT", dragIcon, "RIGHT", 4, 0)
                dragText:SetText(petsToDrag[1].name)
                dragText:SetTextColor(1, 1, 1, 1)
            else
                -- Multi-pet drag display
                dragFrame:SetSize(200, 30)
                local dragText = dragFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                dragText:SetPoint("CENTER", dragFrame, "CENTER", 0, 0)
                dragText:SetText("|cff00ff00" .. #petsToDrag .. " pets|r")
                dragText:SetTextColor(1, 1, 1, 1)
            end

            dragFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", GetCursorPosition() / UIParent:GetEffectiveScale())

            self.dragFrame = dragFrame
            self.isDragging = true

            local function UpdateDragPosition()
                if self.isDragging then
                    local x, y = GetCursorPosition()
                    local scale = UIParent:GetEffectiveScale()
                    dragFrame:ClearAllPoints()
                    dragFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
                    C_Timer.After(0.01, UpdateDragPosition)
                end
            end
            UpdateDragPosition()
        end
    end)

    button:SetScript("OnDragStop", function(self)
        if self.isDragging then
            self.isDragging = false
            if self.dragFrame then
                self.dragFrame:Hide()
                self.dragFrame = nil
            end
            local packFrame = StablemasterUI.GetPackFrameUnderCursor()
            if packFrame and packFrame.pack then
                local pack = packFrame.pack
                local isExpandedView = packFrame.isExpanded == true
                local petsToDrag = self.petsToDrag or {self.petData}
                local successCount = 0
                local addedNames = {}

                for _, petData in ipairs(petsToDrag) do
                    local success, message = Stablemaster.AddPetToPack(pack.name, petData.petGUID)
                    if success then
                        successCount = successCount + 1
                        table.insert(addedNames, petData.name)
                    end
                end

                if successCount > 0 then
                    if successCount == 1 then
                        Stablemaster.VerbosePrint("Added " .. addedNames[1] .. " to pack " .. pack.name)
                    else
                        Stablemaster.VerbosePrint("Added " .. successCount .. " pets to pack " .. pack.name)
                    end

                    -- Clear selections after successful drop
                    if self.scrollFrame then
                        StablemasterUI.ClearPetSelections(self.scrollFrame)
                    end

                    if isExpandedView then
                        -- Refresh the expanded view by re-toggling it (close and reopen)
                        StablemasterUI.TogglePackExpansion(packFrame, pack)
                        StablemasterUI.TogglePackExpansion(packFrame, pack)
                    elseif _G.StablemasterMainFrame and _G.StablemasterMainFrame.packPanel and _G.StablemasterMainFrame.packPanel.refreshPacks then
                        _G.StablemasterMainFrame.packPanel.refreshPacks()
                    end
                end
            end
            self.petsToDrag = nil
        end
    end)

    button:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "LeftButton" then
            if self.petData and self.petData.petGUID then
                -- Ctrl+click for multi-select
                if IsControlKeyDown() and self.scrollFrame and self.scrollFrame.selectedPets then
                    local petGUID = self.petData.petGUID
                    if self.scrollFrame.selectedPets[petGUID] then
                        -- Deselect
                        self.scrollFrame.selectedPets[petGUID] = nil
                        UpdatePetButtonSelectionVisual(self, false)
                    else
                        -- Select
                        self.scrollFrame.selectedPets[petGUID] = self.petData
                        UpdatePetButtonSelectionVisual(self, true)
                    end
                else
                    -- Regular click - clear selections and debug
                    if self.scrollFrame then
                        StablemasterUI.ClearPetSelections(self.scrollFrame)
                    end
                    Stablemaster.Debug("Left-clicked pet: " .. self.petData.name)
                end
            end
        elseif mouseButton == "RightButton" then
            if self.petData and self.petData.petGUID then
                StablemasterUI.ShowPetContextMenu(self.petData, self)
            end
        end
    end)

    return button
end

function StablemasterUI.UpdatePetList(scrollFrame, filters)
    local content = scrollFrame.content
    local buttons = scrollFrame.buttons

    -- Default filters
    filters = filters or {}
    local searchText = filters.searchText or ""
    local favoritesOnly = filters.favoritesOnly or false
    local petTypeFilter = filters.petTypeFilter or nil -- nil = all types

    -- Debug filter values
    if StablemasterDB and StablemasterDB.settings and StablemasterDB.settings.debugMode then
        Stablemaster.Debug("UpdatePetList called with filters:")
        Stablemaster.Debug("  searchText: '" .. searchText .. "'")
        Stablemaster.Debug("  favoritesOnly: " .. tostring(favoritesOnly))
        Stablemaster.Debug("  petTypeFilter: " .. tostring(petTypeFilter))
    end

    -- Get owned pets
    local pets = Stablemaster.GetOwnedPets()

    if StablemasterDB and StablemasterDB.settings and StablemasterDB.settings.debugMode then
        Stablemaster.Debug("Initial pet count: " .. #pets)
    end

    -- Apply favorites filter
    if favoritesOnly then
        local filtered = {}
        for _, p in ipairs(pets) do
            if p.isFavorite then
                table.insert(filtered, p)
            end
        end
        pets = filtered
    end

    -- Apply pet type filter
    if petTypeFilter then
        local filtered = {}
        for _, p in ipairs(pets) do
            if p.petType == petTypeFilter then
                table.insert(filtered, p)
            end
        end
        pets = filtered
    end

    -- Apply search filter
    if searchText ~= "" then
        local filtered = {}
        local searchLower = string.lower(searchText)
        for _, p in ipairs(pets) do
            if string.find(string.lower(p.name), searchLower) then
                table.insert(filtered, p)
            end
        end
        pets = filtered
    end

    -- Deduplicate by species - only show one of each pet type
    -- Prioritize: favorites first, then highest level
    local seenSpecies = {}
    local deduplicated = {}

    -- First pass: sort by priority (favorite > level) so we keep the best one
    table.sort(pets, function(a, b)
        -- Favorites first
        if a.isFavorite and not b.isFavorite then return true end
        if b.isFavorite and not a.isFavorite then return false end
        -- Then by level (higher first)
        local levelA = a.level or 0
        local levelB = b.level or 0
        if levelA ~= levelB then return levelA > levelB end
        -- Then by name
        return a.name < b.name
    end)

    -- Second pass: keep only first of each species
    for _, p in ipairs(pets) do
        if p.speciesID and not seenSpecies[p.speciesID] then
            seenSpecies[p.speciesID] = true
            table.insert(deduplicated, p)
        elseif not p.speciesID then
            -- Keep pets without speciesID (shouldn't happen, but just in case)
            table.insert(deduplicated, p)
        end
    end
    pets = deduplicated

    -- Sort alphabetically
    table.sort(pets, function(a, b) return a.name < b.name end)

    -- Create/update buttons
    for i, petData in ipairs(pets) do
        local button = buttons[i]
        if not button then
            button = StablemasterUI.CreatePetButton(content, i)
            button:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i-1) * 45)
            buttons[i] = button
        end
        button.petData = petData
        button.scrollFrame = scrollFrame  -- Reference to parent for selection tracking
        button.icon:SetTexture(petData.icon)
        button.name:SetText(petData.name)

        -- Set level text
        if petData.level then
            button.levelText:SetText(petData.level)
        else
            button.levelText:SetText("")
        end

        -- Check if this pet is currently selected
        local isSelected = scrollFrame.selectedPets and scrollFrame.selectedPets[petData.petGUID]
        if isSelected then
            UpdatePetButtonSelectionVisual(button, true)
        else
            -- Color name by quality if we have it
            -- Note: quality isn't directly available from GetPetInfoByIndex, default to white
            button.name:SetTextColor(1, 1, 1, 1)
            button:SetBackdropColor(STYLE.bgColor[1], STYLE.bgColor[2], STYLE.bgColor[3], 0.6)
            button:SetBackdropBorderColor(unpack(STYLE.borderColor))
        end

        button:Show()
    end

    -- Hide unused buttons
    for i = #pets + 1, #buttons do
        buttons[i]:Hide()
    end

    -- Update content height
    local contentHeight = math.max(#pets * 45, 1)
    content:SetHeight(contentHeight)

    -- Update the pet counter if it exists
    local mainFrame = _G.StablemasterMainFrame
    if mainFrame and mainFrame.mountPanel and mainFrame.mountPanel.petCounter then
        local counter = mainFrame.mountPanel.petCounter
        local hasFilters = searchText ~= "" or favoritesOnly or petTypeFilter
        if hasFilters then
            local word = #pets == 1 and "pet matches" or "pets match"
            counter:SetText(#pets .. " " .. word .. " your filters")
        else
            local word = #pets == 1 and "pet" or "pets"
            counter:SetText(#pets .. " " .. word)
        end
    end
end

-- Pet Context Menu
function StablemasterUI.CreatePetContextMenu()
    local menu = CreateFrame("Frame", "StablemasterPetContextMenu", UIParent, "BackdropTemplate")
    menu:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    menu:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    menu:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetFrameLevel(1000)
    menu:EnableMouse(true)

    local closeButton = CreateFrame("Button", nil, menu)
    closeButton:SetSize(16, 16)
    closeButton:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -5, -5)
    closeButton:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    closeButton:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    closeButton:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    closeButton:SetScript("OnClick", function() menu:Hide() end)

    local title = menu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", menu, "TOP", 0, -10)
    title:SetText("Add to Pack")
    title:SetTextColor(1, 1, 0.8, 1)

    menu.title = title
    menu.closeButton = closeButton
    menu.packButtons = {}
    menu.targetPet = nil

    -- Hide menu when clicking elsewhere
    local menuHideFrame = CreateFrame("Frame", "StablemasterPetMenuHideFrame", UIParent)
    menuHideFrame:SetAllPoints(UIParent)
    menuHideFrame:SetFrameStrata("BACKGROUND")
    menuHideFrame:EnableMouse(true)
    menuHideFrame:Hide()
    menuHideFrame:SetScript("OnMouseDown", function()
        menu:Hide()
        menuHideFrame:Hide()
    end)

    menu:SetScript("OnShow", function(self)
        menuHideFrame:Show()
    end)

    menu:SetScript("OnHide", function(self)
        menuHideFrame:Hide()
    end)

    menu:Hide()
    return menu
end

function StablemasterUI.UpdatePetContextMenu(menu, petData)
    local packs = Stablemaster.ListPacks()
    local packButtons = menu.packButtons

    for _, b in ipairs(packButtons) do
        b:Hide()
        b:SetParent(nil)
    end
    packButtons = {}
    menu.packButtons = packButtons

    if #packs == 0 then
        menu:SetSize(160, 60)
        local noPacks = menu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        noPacks:SetPoint("CENTER", menu, "CENTER", 0, -10)
        noPacks:SetText("No packs created yet")
        noPacks:SetTextColor(0.6, 0.6, 0.6, 1)
        return
    end

    local buttonHeight = 22
    local buttonWidth = 140
    local padding = 8
    local titleHeight = 25
    local maxPacks = 8
    local visiblePacks = math.min(#packs, maxPacks)

    local menuWidth = buttonWidth + (padding * 2)
    local menuHeight = titleHeight + (visiblePacks * buttonHeight) + padding
    menu:SetSize(menuWidth, menuHeight)

    for i = 1, visiblePacks do
        local pack = packs[i]
        local button = CreateFrame("Button", nil, menu, "BackdropTemplate")
        button:SetSize(buttonWidth, buttonHeight - 2)
        button:SetPoint("TOP", menu.title, "BOTTOM", 0, -5 - ((i-1) * buttonHeight))

        button:SetBackdrop({
            bgFile = "Interface\\Buttons\\UI-Panel-Button-Up",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        button:SetBackdropColor(0.2, 0.2, 0.2, 1)
        button:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

        local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("CENTER", button, "CENTER", 0, 0)
        text:SetJustifyH("CENTER")

        -- Check if pet is already in pack
        local isInPack = false
        if pack.pets then
            for _, existingPetGUID in ipairs(pack.pets) do
                if existingPetGUID == petData.petGUID then
                    isInPack = true
                    break
                end
            end
        end

        if isInPack then
            text:SetText(pack.name .. " +")
            text:SetTextColor(0.8, 1, 0.8, 1)
            button:SetBackdropColor(0.1, 0.3, 0.1, 1)
            button:SetAlpha(0.8)
        else
            text:SetText(pack.name)
            text:SetTextColor(1, 1, 1, 1)
            button:SetBackdropColor(0.2, 0.2, 0.2, 1)
            button:SetAlpha(1.0)
        end

        button:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.3, 0.3, 0.3, 1)
        end)
        button:SetScript("OnLeave", function(self)
            if isInPack then
                self:SetBackdropColor(0.1, 0.3, 0.1, 1)
            else
                self:SetBackdropColor(0.2, 0.2, 0.2, 1)
            end
        end)
        button:SetScript("OnClick", function()
            if not isInPack then
                local success, message = Stablemaster.AddPetToPack(pack.name, petData.petGUID)
                Stablemaster.VerbosePrint(message)
                if success then
                    menu:Hide()
                    if _G.StablemasterMainFrame and _G.StablemasterMainFrame.packPanel and _G.StablemasterMainFrame.packPanel.refreshPacks then
                        _G.StablemasterMainFrame.packPanel.refreshPacks()
                    end
                end
            else
                Stablemaster.Print("Pet is already in pack '" .. pack.name .. "'")
                menu:Hide()
            end
        end)

        packButtons[i] = button
    end

    if #packs > maxPacks then
        local moreText = menu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        moreText:SetPoint("BOTTOM", menu, "BOTTOM", 0, 5)
        moreText:SetText("... and " .. (#packs - maxPacks) .. " more")
        moreText:SetTextColor(0.6, 0.6, 0.6, 1)
    end
end

local petContextMenu = nil
function StablemasterUI.ShowPetContextMenu(petData, parentFrame)
    if not petContextMenu then
        petContextMenu = StablemasterUI.CreatePetContextMenu()
    end
    petContextMenu.targetPet = petData
    StablemasterUI.UpdatePetContextMenu(petContextMenu, petData)
    petContextMenu:ClearAllPoints()
    petContextMenu:SetPoint("LEFT", parentFrame, "RIGHT", 5, 0)
    petContextMenu:Show()
end

-- Pet Tooltip with 3D Model (mirrors ShowMountTooltipWithModel)
local petTooltip = nil

function StablemasterUI.ShowPetTooltipWithModel(parent, petData)
    if not petData or not petData.petGUID then
        return
    end

    -- Create enhanced tooltip if it doesn't exist
    if not petTooltip then
        petTooltip = CreateFrame("Frame", "StablemasterPetEnhancedTooltip", UIParent, "BackdropTemplate")
        petTooltip:SetSize(250, 200)
        petTooltip:SetFrameStrata("TOOLTIP")
        petTooltip:SetFrameLevel(1000)

        -- Set backdrop (same style as mount tooltip)
        petTooltip:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        petTooltip:SetBackdropColor(0, 0, 0, 0.9)
        petTooltip:SetBackdropBorderColor(1, 1, 1, 1)

        -- Pet name
        petTooltip.nameText = petTooltip:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        petTooltip.nameText:SetPoint("TOP", petTooltip, "TOP", 0, -10)
        petTooltip.nameText:SetTextColor(1, 1, 0.8, 1)

        -- Create 3D model frame (same as mount tooltip)
        petTooltip.model = CreateFrame("PlayerModel", nil, petTooltip)
        petTooltip.model:SetPoint("TOPLEFT", petTooltip.nameText, "BOTTOMLEFT", -50, -10)
        petTooltip.model:SetPoint("BOTTOMRIGHT", petTooltip, "BOTTOMRIGHT", -10, 10)
    end

    -- Position tooltip near the parent button (to the RIGHT, same as mount tooltip)
    petTooltip:ClearAllPoints()
    petTooltip:SetPoint("LEFT", parent, "RIGHT", 10, 0)

    -- Set pet information
    petTooltip.nameText:SetText(petData.name or "Unknown Pet")

    -- Get pet display info and set the 3D model
    local speciesID, customName, level, xp, maxXp, displayID = C_PetJournal.GetPetInfoByPetID(petData.petGUID)

    if displayID and displayID > 0 then
        -- Try different model setting methods for compatibility (same as mount tooltip)
        if petTooltip.model.SetDisplayInfo then
            petTooltip.model:SetDisplayInfo(displayID)
        elseif petTooltip.model.SetCreature then
            petTooltip.model:SetCreature(speciesID)
        end

        -- Set initial position and rotation (same as mount tooltip)
        if petTooltip.model.SetPosition then
            petTooltip.model:SetPosition(0, 0, 0)
        end
        if petTooltip.model.SetFacing then
            petTooltip.model:SetFacing(0.5) -- Slightly angled view
        end
    end

    petTooltip:Show()
end

-- Legacy tooltip function (kept for compatibility)
function StablemasterUI.ShowPetTooltip(parent, petData)
    StablemasterUI.ShowPetTooltipWithModel(parent, petData)
end

function StablemasterUI.HidePetTooltip()
    if petTooltip then
        petTooltip:Hide()
    end
end

-- Pet Model Flyout (mirrors mount model flyout exactly)
local petModelFlyout = nil

function StablemasterUI.CreatePetModelFlyout()
    if petModelFlyout then
        return petModelFlyout
    end

    -- Create the flyout frame (same as mount flyout)
    local flyout = CreateFrame("Frame", "StablemasterPetModelFlyout", UIParent, "BackdropTemplate")
    flyout:SetSize(200, 250)
    flyout:SetFrameStrata("DIALOG")
    flyout:SetFrameLevel(1000)
    StablemasterUI.CreateAccentBackdrop(flyout, 0.95)

    -- Create model viewer using PlayerModel (same as mount flyout)
    local modelFrame = CreateFrame("PlayerModel", nil, flyout)
    modelFrame:SetSize(180, 180)
    modelFrame:SetPoint("CENTER", flyout, "CENTER", 0, 10)

    -- Create pet name label
    local nameLabel = StablemasterUI.CreateText(flyout, STYLE.fontSizeHeader, STYLE.textHeader, "CENTER")
    nameLabel:SetPoint("BOTTOM", flyout, "BOTTOM", 0, STYLE.padding)
    nameLabel:SetWordWrap(true)
    nameLabel:SetWidth(180)

    flyout.modelFrame = modelFrame
    flyout.nameLabel = nameLabel
    flyout.rotationTimer = nil
    flyout.isMouseOver = false
    flyout:Hide()

    -- Add mouse tracking for persistence (same as mount flyout)
    flyout:EnableMouse(true)
    flyout:SetScript("OnEnter", function(self)
        self.isMouseOver = true
        -- Cancel any pending hide timers from the flyouts
        if self.hideTimer then
            self.hideTimer:Cancel()
            self.hideTimer = nil
        end
    end)
    flyout:SetScript("OnLeave", function(self)
        self.isMouseOver = false
        -- Hide with same timing as mount flyout
        self.hideTimer = C_Timer.After(0.1, function()
            self.hideTimer = nil
            if not self.isMouseOver then
                StablemasterUI.HidePetModelFlyout()
            end
        end)
    end)

    petModelFlyout = flyout
    return flyout
end

function StablemasterUI.ShowPetModelFlyout(petData)
    if not petData or not petData.petGUID then
        return
    end

    local flyout = StablemasterUI.CreatePetModelFlyout()

    -- Don't recreate if already showing the same pet
    if flyout:IsShown() and flyout.currentPetGUID == petData.petGUID then
        return
    end

    -- Position flyout to the left of the main frame (same as mount flyout)
    if _G.StablemasterMainFrame and _G.StablemasterMainFrame:IsShown() then
        flyout:ClearAllPoints()
        flyout:SetPoint("RIGHT", _G.StablemasterMainFrame, "LEFT", -10, 0)
    else
        -- Fallback position if main frame isn't available
        flyout:SetPoint("CENTER", UIParent, "CENTER", -400, 0)
    end

    -- Set pet name and track current pet
    flyout.nameLabel:SetText(petData.name or "Unknown Pet")
    flyout.currentPetGUID = petData.petGUID

    -- Get pet display info
    local speciesID, customName, level, xp, maxXp, displayID = C_PetJournal.GetPetInfoByPetID(petData.petGUID)

    if displayID and displayID > 0 then
        -- PlayerModel uses SetDisplayInfo (same as mount flyout)
        if flyout.modelFrame.SetDisplayInfo then
            flyout.modelFrame:SetDisplayInfo(displayID)
        end

        -- Set initial facing and start rotation (same as mount flyout)
        if flyout.modelFrame.SetFacing then
            flyout.modelFrame:SetFacing(0)
        end
    end

    -- Start slow rotation animation (same as mount flyout)
    if flyout.rotationTimer then
        flyout.rotationTimer:Cancel()
    end

    local currentRotation = 0
    flyout.rotationTimer = C_Timer.NewTicker(0.05, function() -- Update every 50ms for smooth rotation
        currentRotation = currentRotation + 0.02 -- Slow rotation speed
        if currentRotation > math.pi * 2 then
            currentRotation = 0
        end

        if flyout.modelFrame.SetFacing and flyout:IsShown() then
            flyout.modelFrame:SetFacing(currentRotation)
        else
            -- Stop rotation if flyout is hidden
            if flyout.rotationTimer then
                flyout.rotationTimer:Cancel()
                flyout.rotationTimer = nil
            end
        end
    end)

    flyout:Show()
end

function StablemasterUI.HidePetModelFlyout()
    if petModelFlyout then
        -- Stop rotation timer
        if petModelFlyout.rotationTimer then
            petModelFlyout.rotationTimer:Cancel()
            petModelFlyout.rotationTimer = nil
        end
        petModelFlyout:Hide()
    end
end

Stablemaster.Debug("UI/PetList.lua loaded")
