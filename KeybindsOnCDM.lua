local addonName, private = ...

-- Saved variables - Initialize properly
KeybindsOnCDM_DB = KeybindsOnCDM_DB or {}

-- Set defaults ONLY if they don't exist
if KeybindsOnCDM_DB.enabled == nil then KeybindsOnCDM_DB.enabled = true end
if KeybindsOnCDM_DB.fontSize == nil then KeybindsOnCDM_DB.fontSize = 16 end
if KeybindsOnCDM_DB.offsetX == nil then KeybindsOnCDM_DB.offsetX = 0 end
if KeybindsOnCDM_DB.offsetY == nil then KeybindsOnCDM_DB.offsetY = 0 end
if KeybindsOnCDM_DB.fontStyle == nil then KeybindsOnCDM_DB.fontStyle = "THICKOUTLINE" end
if KeybindsOnCDM_DB.debug == nil then KeybindsOnCDM_DB.debug = false end

-- The CDM viewer frames in Midnight
local CDM_VIEWERS = {
    "EssentialCooldownViewer",
    "UtilityCooldownViewer",
    "CMCTracker1",
    "CMCTracker2"
}

-- Cache for spell ID to keybind mapping
local spellToKeybind = {}

-- Main frame for events
local frame = CreateFrame("FRAME")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("UPDATE_BINDINGS")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
frame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- Addon loaded, saved variables are ready
        print("|cff00ff00KeybindsOnCDM loaded - Font size: " .. KeybindsOnCDM_DB.fontSize)
        private.BuildSpellToKeybindMapping()
        private.UpdateAllKeybinds()
    elseif event == "UPDATE_BINDINGS" or 
           event == "PLAYER_ENTERING_WORLD" or
           event == "ACTIONBAR_PAGE_CHANGED" or
           event == "UPDATE_BONUS_ACTIONBAR" then
        -- Rebuild cache and update
        private.BuildSpellToKeybindMapping()
        private.UpdateAllKeybinds()
    end
end)

-- Scan action bars to build spell ID -> keybind mapping
function private.BuildSpellToKeybindMapping()
    if not KeybindsOnCDM_DB.enabled then return end
    
    spellToKeybind = {}
    
    -- Scan all action buttons (1-120)
    for i = 1, 120 do
        local button = _G["ActionButton" .. i]
        if not button then
            button = _G["MultiBarBottomLeftButton" .. i]
        end
        if not button then
            button = _G["MultiBarBottomRightButton" .. i]
        end
        if not button then
            button = _G["MultiBarRightButton" .. i]
        end
        if not button then
            button = _G["MultiBarLeftButton" .. i]
        end
        
        if button and button.action then
            local actionType, id = GetActionInfo(button.action)
            local keybind = button.HotKey and button.HotKey:GetText()
            
            -- Clean up keybind text
            if keybind and keybind ~= "" and keybind ~= "●" then
                keybind = private.CleanKeybind(keybind)
                
                -- If it's a spell, map it
                if actionType == "spell" and id and not spellToKeybind[id] then
                    spellToKeybind[id] = keybind
                end
            end
        end
    end
    
    -- Debug: count mappings (only if debug is enabled)
    if KeybindsOnCDM_DB.debug then
        local count = 0
        for _,_ in pairs(spellToKeybind) do count = count + 1 end
        print("|cff00ff00Found "..count.." spell keybinds")
    end
end

-- Clean up keybind text
function private.CleanKeybind(key)
    if not key then return "" end
    
    key = key:upper()
    key = key:gsub("SHIFT%-", "S")
    key = key:gsub("CTRL%-", "C")
    key = key:gsub("ALT%-", "A")
    key = key:gsub("BUTTON", "M")
    key = key:gsub("MOUSE%s?WHEEL%s?UP", "MWU")
    key = key:gsub("MOUSE%s?WHEEL%s?DOWN", "MWD")
    key = key:gsub("MIDDLE%s?MOUSE", "MM")
    key = key:gsub("NUMPAD", "N")
    key = key:gsub("PAGEUP", "PGU")
    key = key:gsub("PAGEDOWN", "PGD")
    key = key:gsub("INSERT", "INS")
    key = key:gsub("DELETE", "DEL")
    key = key:gsub("SPACEBAR", "Spc")
    key = key:gsub("ENTER", "Ent")
    key = key:gsub("ESCAPE", "Esc")
    key = key:gsub("TAB", "Tab")
    
    return key
end

-- Extract spell ID from a CDM icon
function private.GetSpellIDFromIcon(icon)
    -- Try cooldownID method (Blizzard's API)
    if icon.cooldownID then
        local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(icon.cooldownID)
        if info and info.spellID then
            return info.spellID
        end
    end
    
    -- Direct spellID
    if icon.spellID then
        return icon.spellID
    end
    
    return nil
end

-- Create or update keybind text on an icon
function private.UpdateIconKeybind(icon)
    if not icon then return end
    
    local spellID = private.GetSpellIDFromIcon(icon)
    if not spellID then return end
    
    local keybind = spellToKeybind[spellID]
    
    -- Create keybind text if needed
    if not icon.keybindText then
        icon.keybindText = icon:CreateFontString(nil, "OVERLAY")
    end
    
    -- Use saved variables for font settings
    -- Force THICKOUTLINE for visibility
    icon.keybindText:SetFont("Fonts\\FRIZQT__.TTF", KeybindsOnCDM_DB.fontSize, "THICKOUTLINE")
    
    -- Center the text
    icon.keybindText:SetPoint("CENTER", icon, "CENTER", KeybindsOnCDM_DB.offsetX, KeybindsOnCDM_DB.offsetY)
    
    if keybind then
        icon.keybindText:SetText(keybind)
        icon.keybindText:SetTextColor(1, 1, 1)
        icon.keybindText:Show()
    else
        icon.keybindText:SetText("")
        icon.keybindText:Hide()
    end
end

-- Update all CDM viewers
function private.UpdateAllKeybinds()
    if not KeybindsOnCDM_DB.enabled then return end
    
    for _, viewerName in ipairs(CDM_VIEWERS) do
        local viewer = _G[viewerName]
        if viewer then
            local children = { viewer:GetChildren() }
            for _, child in ipairs(children) do
                if child.Icon then
                    private.UpdateIconKeybind(child)
                end
            end
        end
    end
end

-- Slash commands
SLASH_KEYBINDSCDM1 = "/kbcdm"
SlashCmdList["KEYBINDSCDM"] = function(msg)
    msg = msg:lower()
    
    if msg == "enable" then
        KeybindsOnCDM_DB.enabled = true
        private.BuildSpellToKeybindMapping()
        private.UpdateAllKeybinds()
        print("|cff00ff00Keybinds on CDM enabled")
    elseif msg == "disable" then
        KeybindsOnCDM_DB.enabled = false
        -- Hide all keybind text
        for _, viewerName in ipairs(CDM_VIEWERS) do
            local viewer = _G[viewerName]
            if viewer then
                local children = { viewer:GetChildren() }
                for _, child in ipairs(children) do
                    if child.keybindText then
                        child.keybindText:Hide()
                    end
                end
            end
        end
        print("|cffff0000Keybinds on CDM disabled")
    elseif msg == "status" then
        print("|cff00ffffKeybinds on CDM: " .. (KeybindsOnCDM_DB.enabled and "Enabled" or "Disabled"))
        print("|cff00ffffFont size: " .. KeybindsOnCDM_DB.fontSize)
        print("|cff00ffffDebug mode: " .. (KeybindsOnCDM_DB.debug and "ON" or "OFF"))
    elseif msg == "debug" then
        KeybindsOnCDM_DB.debug = not KeybindsOnCDM_DB.debug
        print("|cff00ff00Debug mode: " .. (KeybindsOnCDM_DB.debug and "ON" or "OFF"))
    elseif msg:find("^size ") then
        local newSize = tonumber(msg:match("size (%d+)"))
        if newSize and newSize >= 8 and newSize <= 32 then
            KeybindsOnCDM_DB.fontSize = newSize
            private.UpdateAllKeybinds()
            print("|cff00ff00Keybind font size set to " .. newSize)
        else
            print("|cffff0000Usage: /kbcdm size [8-32]")
        end
    else
        print("Commands: enable, disable, status, debug, size [8-32]")
    end
end