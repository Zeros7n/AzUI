local MER, F, E, L, V, P, G = unpack(ElvUI_AzUI)
local module = MER.Modules.Skins
local S = E:GetModule('Skins')

local _G = _G
local pairs, unpack = pairs, unpack

local CreateFrame = CreateFrame
local hooksecurefunc = hooksecurefunc

local r, g, b = unpack(E["media"].rgbvaluecolor)

local function HideDefaultTextures(frame)
	if not frame then
		return
	end

	for i = 1, frame:GetNumRegions() do
		local region = select(i, frame:GetRegions())
		if region and region:IsObjectType("Texture") then
			region:SetTexture(nil)
			region:SetAlpha(0)
		end
	end
end

local function StyleHonorSpecificScrollButton(button)
	if not button then
		return
	end

	local selected = button.SelectedTexture
	if selected then
		selected:SetDrawLayer("BACKGROUND")
		selected:SetColorTexture(r, g, b, .25)
		selected:SetAllPoints(button)
	end

	local reward = button.Reward
	if reward and reward.Icon then
		reward.Icon:SetTexCoord(unpack(E.TexCoords))
		if not reward.Icon.bg then
			local bg = module:CreateBG(reward.Icon)
			if bg then
				bg:SetDrawLayer("BACKGROUND", 1)
			end
		end
	end
end

local function HonorSpecificScrollUpdate(frame)
	if not frame or not frame.ForEachFrame then
		return
	end
	frame:ForEachFrame(StyleHonorSpecificScrollButton)
end

local function LoadSkin()
	if not module:CheckDB("pvp", "pvp") then
		return
	end

	_G.PVPReadyDialog:Styling()
	module:CreateBackdropShadow(_G.PVPReadyDialog)

	local PVPQueueFrame = _G.PVPQueueFrame
	local HonorFrame = _G.HonorFrame
	local ConquestFrame = _G.ConquestFrame

	HideDefaultTextures(_G.PVPUIFrame)
	HideDefaultTextures(PVPQueueFrame)
	HideDefaultTextures(HonorFrame)
	HideDefaultTextures(HonorFrame.BonusFrame)

	HonorFrame:StripTextures()
	HonorFrame:Styling()
	module:CreateBackdropShadow(HonorFrame)

	local specificScroll = HonorFrame.SpecificScrollBox
	if specificScroll then
		specificScroll:StripTextures()
		if specificScroll.CreateBackdrop then
			specificScroll:CreateBackdrop("Transparent")
		end
		if specificScroll.ScrollBar then
			S:HandleTrimScrollBar(specificScroll.ScrollBar)
		end
		hooksecurefunc(specificScroll, "Update", HonorSpecificScrollUpdate)
		HonorSpecificScrollUpdate(specificScroll)
	end

	local iconSize = 56-2*E.mult
	for i = 1, 3 do
		local bu = PVPQueueFrame["CategoryButton"..i]
		local cu = bu.CurrencyDisplay

		bu.Name:SetTextColor(1, 1, 1)

		bu.Icon:SetSize(iconSize, iconSize)
		bu.Icon:SetDrawLayer("OVERLAY")
		bu.Icon:ClearAllPoints()
		bu.Icon:SetPoint("LEFT", bu, "LEFT", 5, 0)

		if cu then
			local ic = cu.Icon

			ic:SetSize(16, 16)
			ic:SetPoint("TOPLEFT", bu.Name, "BOTTOMLEFT", 0, -8)
			cu.Amount:SetPoint("LEFT", ic, "RIGHT", 4, 0)

			ic:SetTexCoord(unpack(E.TexCoords))
			ic.bg = module:CreateBG(ic)
			ic.bg:SetDrawLayer("BACKGROUND", 1)
		end
	end

	-- Casual - HonorFrame
	local BonusFrame = HonorFrame.BonusFrame

	BonusFrame.WorldBattlesTexture:Hide()
	BonusFrame.ShadowOverlay:Hide()

	for _, bonusButton in pairs({"RandomBGButton", "RandomEpicBGButton", "Arena1Button", "BrawlButton", "BrawlButton2"}) do
		local button = BonusFrame[bonusButton]

		button.SelectedTexture:SetDrawLayer("BACKGROUND")
		button.SelectedTexture:SetColorTexture(r, g, b, .2)
		button.SelectedTexture:SetAllPoints()

		button.Reward.Icon:SetInside(button.Reward)
	end

	-- Conquest
	for _, bu in pairs({ConquestFrame.RatedSoloShuffle, ConquestFrame.Arena2v2, ConquestFrame.Arena3v3, ConquestFrame.RatedBG }) do
		bu.SelectedTexture:SetDrawLayer("BACKGROUND")
		bu.SelectedTexture:SetColorTexture(r, g, b, .25)
		bu.SelectedTexture:SetAllPoints()
	end
	ConquestFrame.Arena3v3:SetPoint("TOP", ConquestFrame.Arena2v2, "BOTTOM", 0, -1)
end

S:AddCallbackForAddon("Blizzard_PVPUI", LoadSkin)
