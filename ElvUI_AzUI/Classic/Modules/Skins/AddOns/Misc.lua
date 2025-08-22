local MER, F, E, L, V, P, G = unpack(ElvUI_AzUI)
local module = MER.Modules.Skins
local S = E:GetModule('Skins')

local _G = _G
local getn = getn

local hooksecurefunc = hooksecurefunc
local IsAddOnLoaded = IsAddOnLoaded
local C_TimerAfter = C_Timer.After

local MAX_STATIC_POPUPS = 4

local function LoadSkin()
    if not module:CheckDB("misc", "misc") then
        return
    end

    local skins = {
        "StaticPopup1",
        "StaticPopup2",
        "StaticPopup3",
        "StaticPopup4",
        "InterfaceOptionsFrame",
        "VideoOptionsFrame",
        "AudioOptionsFrame",
        "AutoCompleteBox",
        "ReadyCheckFrame",
        "StackSplitFrame",
    }

    -- FIX STARTS HERE
    for i = 1, getn(skins) do
        local frame = _G[skins[i]] -- Get the actual frame object
        if frame then -- Check if the frame exists before trying to style it
            frame:Styling()
            module:CreateBackdropShadow(frame)
        else
        end
    end
    -- FIX ENDS HERE

    --DropDownMenu
    hooksecurefunc("UIDropDownMenu_CreateFrames", function(level, index)
        local listFrame = _G["DropDownList"..level]
        local listFrameName = listFrame:GetName()

        local Backdrop = _G[listFrameName.."Backdrop"]
        if Backdrop and not Backdrop.__MERSkin then
            Backdrop:Styling()
            module:CreateShadow(Backdrop)
            Backdrop.__MERSkin = true
        end

        local menuBackdrop = _G[listFrameName.."MenuBackdrop"]
        if menuBackdrop and not menuBackdrop.__MERSkin then
            menuBackdrop:Styling()
            menuBackdrop.__MERSkin = true
        end
    end)

    --DropDownMenu library support
    if _G.LibStub("LibUIDropDownMenu", true) then
        -- Added check for L_DropDownList1Backdrop and L_DropDownList1MenuBackdrop as they could be nil
        if _G.L_DropDownList1Backdrop then
            _G.L_DropDownList1Backdrop:Styling()
        else
        end
        if _G.L_DropDownList1MenuBackdrop then
            _G.L_DropDownList1MenuBackdrop:Styling()
        else
        end

        hooksecurefunc("L_UIDropDownMenu_CreateFrames", function()
            -- Added checks inside this hooksecurefunc for robustness
            local backdropFrame = _G["L_DropDownList".._G.L_UIDROPDOWNMENU_MAXLEVELS.."Backdrop"]
            local menuBackdropFrame = _G["L_DropDownList".._G.L_UIDROPDOWNMENU_MAXLEVELS.."MenuBackdrop"]

            if backdropFrame and not backdropFrame.template then
                backdropFrame:Styling()
                module:CreateShadow(backdropFrame)
            else
            end

            if menuBackdropFrame then -- Check for menuBackdropFrame before styling
                menuBackdropFrame:Styling()
                module:CreateShadow(menuBackdropFrame)
            else
            end
        end)
    end

    -- Added checks for other global frames
    if _G.CopyChatFrame then
        _G.CopyChatFrame:Styling()
    else
    end

    local function StylePopups()
        for i = 1, MAX_STATIC_POPUPS do
            local frame = _G["ElvUI_StaticPopup"..i]
            if frame and not frame.skinned then
                frame:Styling()
                frame.skinned = true
            else
            end
        end
    end
    C_TimerAfter(1, StylePopups)

    local TalentMicroButtonAlert = _G.TalentMicroButtonAlert
    if TalentMicroButtonAlert then
        TalentMicroButtonAlert:Styling()
    else
    end

    -- Chat Config
    if _G.ChatConfigFrame then
        _G.ChatConfigFrame:Styling()
    else
    end

    -- Mirror Timers
    if _G.MirrorTimer1StatusBar and _G.MirrorTimer1StatusBar.backdrop then
        _G.MirrorTimer1StatusBar.backdrop:Styling()
    else
    end

    if _G.MirrorTimer2StatusBar and _G.MirrorTimer2StatusBar.backdrop then
        _G.MirrorTimer2StatusBar.backdrop:Styling()
    else
    end

    if _G.MirrorTimer3StatusBar and _G.MirrorTimer3StatusBar.backdrop then
        _G.MirrorTimer3StatusBar.backdrop:Styling()
    else
    end

    -- DataStore
    if IsAddOnLoaded("DataStore") then
        local frame = _G.DataStoreFrame
        if frame then
            frame:Styling()
        else
        end
    end
end

S:AddCallback("Misc", LoadSkin)