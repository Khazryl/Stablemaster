local OutfitHook = {}

-- Store outfit data locally to avoid tainted globals
local stablemasterOutfitID = nil
local stablemasterOutfitName = nil

local function IsOutfitInPack(outfitID, packName)
    local pack = Stablemaster.GetPackByName(packName)
    if not pack or not pack.conditions then return false end
    for _, rule in ipairs(pack.conditions) do
        if rule.type == "outfit" then
            -- Check new multi-outfit format
            if rule.outfitIDs then
                for _, id in ipairs(rule.outfitIDs) do
                    if id == outfitID then return true end
                end
            -- Check legacy single-outfit format
            elseif rule.outfitID == outfitID then
                return true
            end
        end
    end
    return false
end

local function GetPacksForDropdown(outfitID)
    local packs = {}

    if StablemasterDB.sharedPacks then
        for _, pack in ipairs(StablemasterDB.sharedPacks) do
            table.insert(packs, {
                name = pack.name,
                text = pack.name .. " (Account)",
                hasRule = IsOutfitInPack(outfitID, pack.name)
            })
        end
    end

    for _, pack in ipairs(Stablemaster.GetCharacterPacks()) do
        table.insert(packs, {
            name = pack.name,
            text = pack.name .. " (Character)",
            hasRule = IsOutfitInPack(outfitID, pack.name)
        })
    end

    return packs
end

local function AddOutfitRule(packName, outfitID, outfitName)
    local pack = Stablemaster.GetPackByName(packName)
    if not pack then
        Stablemaster.Print("[-] Pack not found: " .. packName)
        return false
    end

    if IsOutfitInPack(outfitID, packName) then
        Stablemaster.Print("[!] Outfit already in pack '" .. packName .. "'")
        return false
    end

    pack.conditions = pack.conditions or {}

    local priority = StablemasterDB.settings.rulePriorities and
                     StablemasterDB.settings.rulePriorities.outfit or 100

    -- Use new multi-outfit format (array with single element)
    table.insert(pack.conditions, {
        type = "outfit",
        outfitIDs = {outfitID},
        outfitNames = {outfitName},
        priority = priority
    })

    Stablemaster.Print("[+] Added '" .. outfitName .. "' to pack '" .. packName .. "'")
    return true
end

local function RemoveOutfitRule(packName, outfitID, outfitName)
    local pack = Stablemaster.GetPackByName(packName)
    if not pack or not pack.conditions then
        Stablemaster.Print("[-] Pack not found: " .. packName)
        return false
    end

    for i, rule in ipairs(pack.conditions) do
        if rule.type == "outfit" then
            -- Handle new multi-outfit format
            if rule.outfitIDs then
                for j, id in ipairs(rule.outfitIDs) do
                    if id == outfitID then
                        -- Remove this outfit from the array
                        table.remove(rule.outfitIDs, j)
                        if rule.outfitNames and rule.outfitNames[j] then
                            table.remove(rule.outfitNames, j)
                        end
                        -- If no outfits left, remove the entire rule
                        if #rule.outfitIDs == 0 then
                            table.remove(pack.conditions, i)
                        end
                        Stablemaster.Print("[-] Removed '" .. outfitName .. "' from pack '" .. packName .. "'")
                        return true
                    end
                end
            -- Handle legacy single-outfit format
            elseif rule.outfitID == outfitID then
                table.remove(pack.conditions, i)
                Stablemaster.Print("[-] Removed '" .. outfitName .. "' from pack '" .. packName .. "'")
                return true
            end
        end
    end
    return false
end

local function CreateContextMenu(self, level, menuList)
    local outfitID = self.outfitID
    local outfitName = self.outfitName

    if level == 1 then
        if not outfitID then return end

        UIDropDownMenu_AddButton({
            text = outfitName,
            isTitle = true,
            notCheckable = true,
        }, level)

        UIDropDownMenu_AddSeparator(level)

        local packs = GetPacksForDropdown(outfitID)
        if #packs > 0 then
            UIDropDownMenu_AddButton({
                text = "|cFF00FF96Add as Stablemaster Rule|r",
                hasArrow = true,
                notCheckable = true,
                menuList = "STABLEMASTER_OUTFIT_PACKS",
            }, level)
        else
            UIDropDownMenu_AddButton({
                text = "|cFF808080No packs available|r",
                notCheckable = true,
                disabled = true,
            }, level)
        end

    elseif menuList == "STABLEMASTER_OUTFIT_PACKS" then
        -- Use our local variables to avoid accessing tainted global UIDROPDOWNMENU_INIT_MENU
        outfitID = stablemasterOutfitID or (self and self.outfitID)
        outfitName = stablemasterOutfitName or (self and self.outfitName)
        if not outfitID then return end

        for _, pack in ipairs(GetPacksForDropdown(outfitID)) do
            local text, func, tip

            if pack.hasRule then
                text = "|cFFFF4444X|r |cFF808080" .. pack.text .. "|r"
                tip = "Remove from " .. pack.name
                func = function()
                    RemoveOutfitRule(pack.name, outfitID, outfitName)
                    CloseDropDownMenus()
                end
            else
                text = pack.text
                tip = "Add to " .. pack.name
                func = function()
                    AddOutfitRule(pack.name, outfitID, outfitName)
                    CloseDropDownMenus()
                end
            end

            UIDropDownMenu_AddButton({
                text = text,
                notCheckable = true,
                func = func,
                tooltipTitle = pack.name,
                tooltipText = tip,
            }, level)
        end
    end
end

function OutfitHook.ShowContextMenu(outfitID, outfitName)
    if not outfitID then return end

    -- Store in local variables to avoid taint
    stablemasterOutfitID = outfitID
    stablemasterOutfitName = outfitName

    -- Use C_Timer to break the taint chain
    C_Timer.After(0, function()
        CloseDropDownMenus()
        local menu = CreateFrame("Frame", "StablemasterOutfitMenu", UIParent, "UIDropDownMenuTemplate")
        menu.outfitID = stablemasterOutfitID
        menu.outfitName = stablemasterOutfitName
        UIDropDownMenu_Initialize(menu, CreateContextMenu, "MENU")
        ToggleDropDownMenu(1, nil, menu, "cursor", 3, -3)
    end)
end

function OutfitHook.ShowCurrentOutfitMenu()
    local outfitID = Stablemaster.GetCurrentOutfitID()
    if not outfitID then
        Stablemaster.Print("No outfit currently active")
        return
    end

    local info = Stablemaster.GetOutfitInfo(outfitID)
    if info then
        OutfitHook.ShowContextMenu(outfitID, info.name)
    else
        Stablemaster.Print("Could not get outfit info")
    end
end

function OutfitHook.DebugWardrobeUI()
    Stablemaster.Print("=== Wardrobe UI ===")

    -- Check if Blizzard_Collections is loaded
    local loaded = C_AddOns.IsAddOnLoaded("Blizzard_Collections")
    Stablemaster.Print("Blizzard_Collections loaded: " .. tostring(loaded))

    -- Check known frames
    local frames = {
        "WardrobeFrame", "WardrobeTransmogFrame", "WardrobeCollectionFrame",
        "WardrobeOutfitDropdown", "WardrobeOutfitFrame", "TransmogFrame",
        "DressUpFrame", "CollectionsJournal"
    }

    local found = false
    for _, name in ipairs(frames) do
        local f = _G[name]
        if f then
            found = true
            local extras = {}
            if f.OutfitDropdown then table.insert(extras, "OutfitDropdown") end
            if f.outfitButtons then table.insert(extras, #f.outfitButtons .. " buttons") end
            if f.SetupMenu then table.insert(extras, "SetupMenu") end
            if f.GetOutfitID then table.insert(extras, "GetOutfitID") end

            local suffix = #extras > 0 and " (" .. table.concat(extras, ", ") .. ")" or ""
            Stablemaster.Print("  " .. name .. suffix)
        end
    end

    if not found then
        Stablemaster.Print("  No known frames found - try opening the transmog window first")
    end

    -- Search _G for anything wardrobe/outfit/transmog related
    Stablemaster.Print("Searching globals...")
    local count = 0
    for key, val in pairs(_G) do
        if type(key) == "string" and type(val) == "table" then
            local k = key:lower()
            if k:find("wardrobe") or k:find("outfit") or k:find("transmog") then
                count = count + 1
                if count <= 15 then
                    Stablemaster.Print("  " .. key .. " (" .. type(val) .. ")")
                end
            end
        end
    end
    if count > 15 then
        Stablemaster.Print("  ... and " .. (count - 15) .. " more")
    elseif count == 0 then
        Stablemaster.Print("  No wardrobe/outfit/transmog globals found")
    end

    -- Show TransmogFrame children
    if TransmogFrame then
        Stablemaster.Print("TransmogFrame keys:")
        for key, val in pairs(TransmogFrame) do
            if type(key) == "string" then
                local k = key:lower()
                if k:find("outfit") or k:find("dropdown") or k:find("button") then
                    Stablemaster.Print("  " .. key .. " (" .. type(val) .. ")")
                end
            end
        end

        -- Dig into OutfitCollection
        if TransmogFrame.OutfitCollection then
            Stablemaster.Print("OutfitCollection keys:")
            for key, val in pairs(TransmogFrame.OutfitCollection) do
                if type(key) == "string" then
                    Stablemaster.Print("  " .. key .. " (" .. type(val) .. ")")
                end
            end

            -- Dig into OutfitList
            local outfitList = TransmogFrame.OutfitCollection.OutfitList
            if outfitList then
                Stablemaster.Print("OutfitList keys:")
                for key, val in pairs(outfitList) do
                    if type(key) == "string" then
                        Stablemaster.Print("  " .. key .. " (" .. type(val) .. ")")
                    end
                end
            end
        end
    end
end

Stablemaster.OutfitHook = OutfitHook
