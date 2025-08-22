local MER, F, E, L, V, P, G = unpack(ElvUI_AzUI)
local module = MER.Modules.Skins
local S = E:GetModule('Skins')

local _G = _G

local function LoadSkin() 
    if not module:CheckDB("addonManager", "addonManager") then
        return
    end

    local AddonList = _G.AddonList
    if AddonList.backdrop then
        AddonList.backdrop:Styling()
    end
    module:CreateBackdropShadow(AddonList)

    if _G.AddonCharacterDropDown then 
        _G.AddonCharacterDropDown:SetWidth(170)
    else
    end 

end

S:AddCallback("AddonList", LoadSkin)