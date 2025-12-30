local MER, F, E, L, V, P, G = unpack(ElvUI_AzUI)
local module = MER:GetModule('MER_Skins')
local M = E:GetModule('Misc')

local _G = _G
local CreateColor = CreateColor
local max = math.max
local CharacterFrame = _G.CharacterFrame

local ClassSymbolFrame
local CharacterText

local function CreateMerathilisBackground()
	if not (CharacterFrame and CharacterFrame:IsObjectType("Frame")) or CharacterFrame.MERBackground then
		return
	end

	local background = CreateFrame("Frame", "MER_CharacterBackground", CharacterFrame)
	background:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 0, 0)
	background:SetPoint("BOTTOMRIGHT", CharacterFrame, "BOTTOMRIGHT", 0, 0)
	background:SetFrameLevel(max(CharacterFrame:GetFrameLevel() - 2, 0))
	background.Texture = background:CreateTexture(nil, "BACKGROUND")
	background.Texture:SetAllPoints()

	local topLine = CreateFrame("Frame", nil, background)
	topLine:SetPoint("TOPLEFT", background, 0, -6)
	topLine:SetPoint("TOPRIGHT", background, 0, -6)
	topLine:SetHeight(E.mult)
	topLine.Texture = topLine:CreateTexture(nil, "OVERLAY")
	topLine.Texture:SetAllPoints()

	local bottomLine = CreateFrame("Frame", nil, background)
	bottomLine:SetPoint("BOTTOMLEFT", background, 0, 6)
	bottomLine:SetPoint("BOTTOMRIGHT", background, 0, 6)
	bottomLine:SetHeight(E.mult)
	bottomLine.Texture = bottomLine:CreateTexture(nil, "OVERLAY")
	bottomLine.Texture:SetAllPoints()

	CharacterFrame.MERBackground = background
	CharacterFrame.MERLines = { top = topLine, bottom = bottomLine }

	local watermark = background:CreateTexture(nil, "ARTWORK")
	watermark:SetSize(96, 36)
	watermark:SetPoint("BOTTOMRIGHT", CharacterFrame, -6, 6)
	watermark:SetTexture(MER.Media.Textures.merathilisLogo or MER.Media.Textures.AzUI_Banner)
	watermark:SetAlpha(0.28)
	CharacterFrame.MERWaterMark = watermark
end

local function UpdateMerathilisBackground()
	if not (CharacterFrame and CharacterFrame.MERBackground) then
		return
	end

	local classKey = "MERATHILISUI-" .. (E.myclass or "WARRIOR")
	local texture = MER.Media.Backgrounds[classKey] or MER.Media.Backgrounds.BG1 or MER.Media.Backgrounds["BG1"]
	if texture then
		CharacterFrame.MERBackground.Texture:SetTexture(texture)
	end

	local classColor = F.ClassColor(E.myclass, true)
	local r, g, b = 0.35, 0.35, 0.35
	if classColor then
		r, g, b = classColor.r, classColor.g, classColor.b
	end

	local lines = CharacterFrame.MERLines
	if lines then
		lines.top.Texture:SetColorTexture(math.min(r + 0.1, 1), math.min(g + 0.1, 1), math.min(b + 0.1, 1), 0.7)
		lines.bottom.Texture:SetColorTexture(r * 0.36, g * 0.36, b * 0.36, 0.35)
	end
end

local function SetupMerathilisCharacterFrame()
	CreateMerathilisBackground()
	UpdateMerathilisBackground()
	if CharacterFrame and CharacterFrame.DisableDrawLayer then
		CharacterFrame:DisableDrawLayer("BACKGROUND")
	end
	if CharacterFrame then
		for i = 1, CharacterFrame:GetNumRegions() do
			local region = select(i, CharacterFrame:GetRegions())
			if region and region:IsObjectType("Texture") then
				local texture = region:GetTexture()
				if texture and texture:find("CharacterFrame") and not texture:find("Portrait") then
					region:Hide()
				end
			end
		end
	end
	if CharacterFrame and not CharacterFrame.MERBackgroundHooked then
		CharacterFrame:HookScript("OnSizeChanged", UpdateMerathilisBackground)
		CharacterFrame:HookScript("OnShow", UpdateMerathilisBackground)
		CharacterFrame.MERBackgroundHooked = true
	end
end

local function StatsPane(type)
	_G.CharacterStatsPane[type]:StripTextures()

	if _G.CharacterStatsPane[type] and _G.CharacterStatsPane[type].backdrop then
		_G.CharacterStatsPane[type].backdrop:Hide()
	end

	if _G.CharacterStatsPane[type].Title then
		_G.CharacterStatsPane[type].Title:FontTemplate(nil, 13, "OUTLINE")
	end
end

local function CharacterStatFrameCategoryTemplate(frame)
	frame:StripTextures()

	local bg = frame.Background
	bg:SetTexture([[Interface\LFGFrame\UI-LFG-SEPARATOR]])
	bg:SetTexCoord(0, 0.6640625, 0, 0.3125)
	bg:ClearAllPoints()
	bg:SetPoint("CENTER", 0, -5)
	bg:SetSize(210, 30)
	bg:SetVertexColor(F.r, F.g, F.b)
end

local function ColorizeStatPane(frame)
	if frame.leftGrad then
		frame.leftGrad:StripTextures()
	end
	if frame.rightGrad then
		frame.rightGrad:StripTextures()
	end

	frame.leftGrad = frame:CreateTexture(nil, "BORDER")
	frame.leftGrad:SetWidth(80)
	frame.leftGrad:SetHeight(frame:GetHeight())
	frame.leftGrad:SetPoint("LEFT", frame, "CENTER")
	frame.leftGrad:SetTexture(E.media.blankTex)
	frame.leftGrad:SetGradient("Horizontal", CreateColor(F.r, F.g, F.b, 0.75), CreateColor(F.r, F.g, F.b, 0))

	frame.rightGrad = frame:CreateTexture(nil, "BORDER")
	frame.rightGrad:SetWidth(80)
	frame.rightGrad:SetHeight(frame:GetHeight())
	frame.rightGrad:SetPoint("RIGHT", frame, "CENTER")
	frame.rightGrad:SetTexture(E.media.blankTex)
	frame.rightGrad:SetGradient("Horizontal", CreateColor(F.r, F.g, F.b, 0), CreateColor(F.r, F.g, F.b, 0.75))
end

-- needed for Shadow&Light
local function SkinAdditionalStats()
	if CharacterStatsPane.OffenseCategory then
		if CharacterStatsPane.OffenseCategory.Title then
			CharacterStatsPane.OffenseCategory.Title:SetText(E:TextGradient(CharacterStatsPane.OffenseCategory.Title:GetText(), F.ClassGradient[E.myclass]["r1"], F.ClassGradient[E.myclass]["g1"], F.ClassGradient[E.myclass]["b1"], F.ClassGradient[E.myclass]["r2"], F.ClassGradient[E.myclass]["g2"], F.ClassGradient[E.myclass]["b2"]))
		end
		StatsPane("OffenseCategory")
		CharacterStatFrameCategoryTemplate(CharacterStatsPane.OffenseCategory)
	end

	if CharacterStatsPane.DefenseCategory then
		if CharacterStatsPane.DefenseCategory.Title then
			CharacterStatsPane.DefenseCategory.Title:SetText(E:TextGradient(CharacterStatsPane.DefenseCategory.Title:GetText(), F.ClassGradient[E.myclass]["r1"], F.ClassGradient[E.myclass]["g1"], F.ClassGradient[E.myclass]["b1"], F.ClassGradient[E.myclass]["r2"], F.ClassGradient[E.myclass]["g2"], F.ClassGradient[E.myclass]["b2"]))
		end
		StatsPane("DefenseCategory")
		CharacterStatFrameCategoryTemplate(CharacterStatsPane.DefenseCategory)
	end
end

function module:AddCharacterIcon()
	local CharacterFrameTitleText = _G.CharacterFrameTitleText
	local CharacterLevelText = _G.CharacterLevelText

	-- Class Icon Holder
	local ClassIconHolder = CreateFrame("Frame", "MER_ClassIcon", _G.PaperDollFrame)
	ClassIconHolder:SetSize(20, 20)

	local ClassIconTexture = ClassIconHolder:CreateTexture()
	ClassIconTexture:SetAllPoints(ClassIconHolder)

	CharacterLevelText:SetWidth(300)

	ClassSymbolFrame = ("|T" .. (MER.ClassIcons[E.myclass] .. ".tga:0:0:0:0|t"))

	hooksecurefunc('PaperDollFrame_SetLevel', function()
		CharacterFrameTitleText:SetDrawLayer("OVERLAY")
		CharacterFrameTitleText:SetFont(E.LSM:Fetch('font', E.db.general.font), E.db.general.fontSize + 2, E.db.general.fontStyle)

		CharacterLevelText:SetDrawLayer("OVERLAY")
	end)

	local titleText, coloredTitleText

	local function colorTitleText()
		CharacterText = CharacterFrameTitleText:GetText()
		coloredTitleText = E:TextGradient(CharacterText, F.ClassGradient[E.myclass]["r1"],
		F.ClassGradient[E.myclass]["g1"], F.ClassGradient[E.myclass]["b1"], F.ClassGradient[E.myclass]["r2"],
		F.ClassGradient[E.myclass]["g2"], F.ClassGradient[E.myclass]["b2"])
		if not CharacterText:match("|T") then
			titleText = ClassSymbolFrame .. " " .. coloredTitleText
		end
		CharacterFrameTitleText:SetText(titleText)
	end

	hooksecurefunc("CharacterFrame_Collapse", function()
		if _G.PaperDollFrame:IsShown() then
			colorTitleText()
		end
	end)

	hooksecurefunc("CharacterFrame_Expand", function()
		if _G.PaperDollFrame:IsShown() then
			colorTitleText()
		end
	end)

	hooksecurefunc("ReputationFrame_Update", function()
		if _G.ReputationFrame:IsShown() then
			colorTitleText()
		end
	end)

	hooksecurefunc("TokenFrame_Update", function()
		if _G.TokenFrame:IsShown() then
			colorTitleText()
		end
	end)

	hooksecurefunc(_G.CharacterFrame, "SetTitle", function()
		colorTitleText()
	end)

	if E.db.general.itemLevel.displayCharacterInfo then
		M:UpdatePageInfo(_G.CharacterFrame, "Character")
	end
end

function module:CharacterFrame()
	if not module:CheckDB("character", "character") then
		SetupMerathilisCharacterFrame()
		return
	end

	local CharacterFrame = _G.CharacterFrame
	local r, g, b = F.r, F.g, F.b

	CharacterFrame:Styling()
	module:CreateShadow(CharacterFrame)
	module:CreateShadow(_G.EquipmentFlyoutFrameButtons)

	for i = 1, 4 do
		module:ReskinTab(_G["CharacterFrameTab" .. i])
	end

	-- Remove the background
	local modelScene = _G.CharacterModelScene
	modelScene:DisableDrawLayer("BACKGROUND")
	modelScene:DisableDrawLayer("BORDER")
	modelScene:DisableDrawLayer("OVERLAY")
	modelScene.backdrop:Kill()

	local function UpdateHighlight(self)
		local highlight = self:GetHighlightTexture()
		highlight:SetColorTexture(1, 1, 1, .25)
		highlight:SetInside(self.bg)
	end

	local function UpdateCosmetic(self)
		local itemLink = GetInventoryItemLink("player", self:GetID())
		self.IconOverlay:SetShown(itemLink and IsCosmeticItem(itemLink))
	end

	local slots = {
		"Head", "Neck", "Shoulder", "Shirt", "Chest", "Waist", "Legs", "Feet", "Wrist",
		"Hands", "Finger0", "Finger1", "Trinket0", "Trinket1", "Back", "MainHand",
		"SecondaryHand", "Tabard",
	}

	for i = 1, #slots do
		local slot = _G["Character"..slots[i].."Slot"]

		slot.ignoreTexture:SetTexture("Interface\\PaperDollInfoFrame\\UI-GearManager-LeaveItem-Transparent")
		slot.IconOverlay:SetAtlas("CosmeticIconFrame")
		slot.IconOverlay:SetInside()
	end

	hooksecurefunc("PaperDollItemSlotButton_Update", function(button)
		if button.popoutButton then
			button.icon:SetShown(GetInventoryItemTexture("player", button:GetID()) ~= nil)
		end
		UpdateCosmetic(button)
		UpdateHighlight(button)
	end)

	if _G.PaperDollSidebarTabs.DecorRight then
		_G.PaperDollSidebarTabs.DecorRight:Hide()
	end

	hooksecurefunc(_G.PaperDollFrame.EquipmentManagerPane.ScrollBox, "Update", function(self)
		for i = 1, self.ScrollTarget:GetNumChildren() do
			local child = select(i, self.ScrollTarget:GetChildren())
			if child.icon and not child.styled then
				child.HighlightBar:SetColorTexture(1, 1, 1, .25)
				child.HighlightBar:SetDrawLayer("BACKGROUND")
				child.SelectedBar:SetColorTexture(r, g, b, .25)
				child.SelectedBar:SetDrawLayer("BACKGROUND")

				child.styled = true
			end
		end
	end)

	if not IsAddOnLoaded("DejaCharacterStats") then
		local pane = CharacterStatsPane
		pane.ClassBackground:Hide()
		pane.ItemLevelFrame.Corruption:SetPoint("RIGHT", 22, -8)

		pane.ItemLevelCategory.Title:SetText(E:TextGradient(pane.ItemLevelCategory.Title:GetText(), F.ClassGradient[E.myclass]["r1"], F.ClassGradient[E.myclass]["g1"], F.ClassGradient[E.myclass]["b1"], F.ClassGradient[E.myclass]["r2"], F.ClassGradient[E.myclass]["g2"], F.ClassGradient[E.myclass]["b2"]))
		pane.AttributesCategory.Title:SetText(E:TextGradient(pane.AttributesCategory.Title:GetText(), F.ClassGradient[E.myclass]["r1"], F.ClassGradient[E.myclass]["g1"], F.ClassGradient[E.myclass]["b1"], F.ClassGradient[E.myclass]["r2"], F.ClassGradient[E.myclass]["g2"], F.ClassGradient[E.myclass]["b2"]))
		pane.EnhancementsCategory.Title:SetText(E:TextGradient(pane.EnhancementsCategory.Title:GetText(), F.ClassGradient[E.myclass]["r1"], F.ClassGradient[E.myclass]["g1"], F.ClassGradient[E.myclass]["b1"], F.ClassGradient[E.myclass]["r2"], F.ClassGradient[E.myclass]["g2"], F.ClassGradient[E.myclass]["b2"]))

		StatsPane("EnhancementsCategory")
		StatsPane("ItemLevelCategory")
		StatsPane("AttributesCategory")

		CharacterStatFrameCategoryTemplate(pane.ItemLevelCategory)
		CharacterStatFrameCategoryTemplate(pane.AttributesCategory)
		CharacterStatFrameCategoryTemplate(pane.EnhancementsCategory)

		ColorizeStatPane(pane.ItemLevelFrame)

		E:Delay(0.2, SkinAdditionalStats)

		hooksecurefunc("PaperDollFrame_UpdateStats", function()
			for _, Table in ipairs({ pane.statsFramePool:EnumerateActive() }) do
				if type(Table) == "table" then
					for statFrame in pairs(Table) do
						ColorizeStatPane(statFrame)
						if statFrame.Background:IsShown() then
							statFrame.leftGrad:Show()
							statFrame.rightGrad:Show()
						else
							statFrame.leftGrad:Hide()
							statFrame.rightGrad:Hide()
						end
					end
				end
			end
		end)
	end

	-- Token
	module:CreateShadow(_G.TokenFramePopup)

	-- Reputation
	module:CreateShadow(_G.ReputationDetailFrame)

	self:AddCharacterIcon()
	SetupMerathilisCharacterFrame()
end

module:AddCallback("CharacterFrame")
