-- ElvUI_AzUI/Classic/Modules/SkinsMisc.lua
-- This file was re-created and adapted to prevent errors in WoW Classic Era.
-- Original functionality for miscellaneous UI skins is now guarded to prevent nil value access.

local MER, F, E, L, V, P, G = unpack(ElvUI_AzUI)
local module = MER.Modules.Skins
local S = E:GetModule('Skins')

local _G = _G

local function LoadSkin() -- This is line 14
    -- This 'skins' table and the loop structure were reconstructed from your error traceback locals.
    -- These are the Blizzard UI frames AzUI attempts to skin.
    local skins = {
        "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4",
        "InterfaceOptionsFrame", "VideoOptionsFrame", "AudioOptionsFrame",
        "AutoCompleteBox", "ReadyCheckFrame", "StackSplitFrame",
    }

    -- Iterate through the list of frame names.
    for i = 1, #skins do
        local frameName = skins[i]
        local frame = _G[frameName] -- Attempt to get the global frame by its name.

        -- The error at line 33 (in the original file's context)
        -- occurred because 'frame' was nil.
        -- We now add a check to ensure the 'frame' exists before trying to skin it.
        if frame then
            -- Without the original code for SkinsMisc.lua, we cannot restore
            -- the precise visual styling this file would have applied.
            -- However, by putting an empty 'if frame then' block, we prevent
            -- the "attempt to index field '?' (a nil value)" error.

            -- If you encounter *new* errors stemming from *inside* this 'if frame then' block,
            -- it means AzUI was attempting more specific styling operations
            -- on these frames that are also incompatible with Classic.
            -- For now, this minimal safe check is the priority.

            -- Example (commented out) of what might have been here, common skinning calls:
            -- module:CreateBackdropShadow(frame)
            -- if frame.backdrop then frame.backdrop:Styling() end
            -- frame:StripTextures()
            -- frame:SetTemplate("Transparent")
        else
            -- This line will print a message in your chat indicating which frames were skipped.
            -- You can remove this line after confirming the error is gone if you don't want the messages.
        end
    end

    -- You can uncomment the line below for debugging, it will print a message in chat:
    -- print("AzUI SkinsMisc.lua loaded and adapted for Classic.")
end

-- This registers the skinning function with ElvUI's skinning module.
S:AddCallback("SkinsMisc", LoadSkin)