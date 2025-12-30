local MER, F, E, L, V, P, G = unpack(ElvUI_AzUI)
local module = MER.Modules.Skins
local S = E:GetModule('Skins')

local _G = _G
local max = math.max
local min = math.min

local ClassSymbolFrame
local CharacterText
local characterIconInitialized

local function HideRegions(frame)
	if not frame or not frame.GetRegions then
		return
	end

	for i = 1, frame:GetNumRegions() do
		local region = select(i, frame:GetRegions())
		if region and region:IsObjectType("Texture") then
			region:SetTexture(nil)
			region:Hide()
		end
	end
end

local STAT_FRAME_NAMES = {
	"CharacterStatsPane",
	"CharacterAttributesFrame",
	"CharacterFrameInset",
}

local function ClearDefaultCharacterTextures()
	local frames = {
		_G.CharacterFrameInset,
		_G.CharacterFrameInsetRight,
		_G.CharacterFramePortraitFrame,
		_G.CharacterFramePortrait,
		_G.CharacterModelFrame,
		_G.CharacterModelFrameRotateLeftButton,
		_G.CharacterModelFrameRotateRightButton,
		_G.CharacterAttributesFrame,
		_G.PaperDollFrame,
		_G.CharacterStatsPane,
	}

	for _, frame in ipairs(frames) do
		HideRegions(frame)
	end
end

local function CreateMerathilisBackground()
	local CharacterFrame = _G.CharacterFrame
	if not (CharacterFrame and CharacterFrame.IsObjectType and CharacterFrame:IsObjectType("Frame")) or CharacterFrame.MERBackground then
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
	local CharacterFrame = _G.CharacterFrame
	if not (CharacterFrame and CharacterFrame.MERBackground) then
		return
	end

	local classKey = "MERATHILISUI-" .. (E.myclass or "WARRIOR")
	local texture = MER.Media.Backgrounds[classKey] or MER.Media.Backgrounds.BG1 or MER.Media.Backgrounds["BG1"]
	if texture then
		CharacterFrame.MERBackground.Texture:SetTexture(texture)
	end

	local r, g, b = 0.35, 0.35, 0.35
	local classR, classG, classB = F.ClassColor(E.myclass)
	if classR then
		r, g, b = classR, classG, classB
	end

	local lines = CharacterFrame.MERLines
	if lines then
		lines.top.Texture:SetColorTexture(min(r + 0.1, 1), min(g + 0.1, 1), min(b + 0.1, 1), 0.7)
		lines.bottom.Texture:SetColorTexture(r * 0.36, g * 0.36, b * 0.36, 0.35)
	end
end

local function SealFrame(frame)
	if not frame then
		return
	end
	if frame.MERSealed then
		return
	end
	frame:EnableMouse(false)
	frame:ClearAllPoints()
	frame:SetParent(E.HiddenFrame or _G.UIParent)
	frame:SetScale(0.0001)
	frame:SetAlpha(0)
	frame:Hide()
	frame.Show = E.noop
	frame.Hide = E.noop
	frame.SetShown = E.noop
	frame.MERSealed = true
	if frame:GetScript("OnShow") then
		frame:HookScript("OnShow", function(self)
			self:Hide()
		end)
	else
		frame:SetScript("OnShow", function(self)
			self:Hide()
		end)
	end
end

local function SuppressDefaultStats()
	for _, name in ipairs(STAT_FRAME_NAMES) do
		local frame = _G[name]
		if frame and not frame.MERSealed then
			SealFrame(frame)
		end
	end
end

local function HookSuppressOnShow(frame)
	if not frame or frame.MERSuppressHooked then
		return
	end

	frame:HookScript("OnShow", SuppressDefaultStats)
	frame.MERSuppressHooked = true
end

local function ColorTitleText()
	local title = _G.CharacterFrameTitleText
	if not title then
		return
	end

	CharacterText = title:GetText() or ""
	local gradient = CharacterText ~= "" and E:TextGradient(CharacterText, F.ClassGradient[E.myclass]["r1"], F.ClassGradient[E.myclass]["g1"], F.ClassGradient[E.myclass]["b1"], F.ClassGradient[E.myclass]["r2"], F.ClassGradient[E.myclass]["g2"], F.ClassGradient[E.myclass]["b2"]) or CharacterText
	local prefix = ""
	if ClassSymbolFrame and ClassSymbolFrame ~= "" then
		prefix = ClassSymbolFrame .. " "
	end
	local finalText = CharacterText:match("|T") and gradient or (prefix .. gradient)
	title:SetText(finalText)
end

local function StyleCharacterTitle()
	local title = _G.CharacterFrameTitleText
	local level = _G.CharacterLevelText
	if title then
		title:SetDrawLayer("OVERLAY")
		title:SetFont(E.LSM:Fetch('font', E.db.general.font), E.db.general.fontSize + 2, E.db.general.fontStyle)
	end
	if level then
		level:SetDrawLayer("OVERLAY")
	end
end

local function AddCharacterIcon()
	local title = _G.CharacterFrameTitleText
	local paperDoll = _G.PaperDollFrame
	if characterIconInitialized or not paperDoll or not title then
		return
	end

	characterIconInitialized = true

	local classIconPath = MER.ClassIcons[E.myclass]
	if classIconPath then
		ClassSymbolFrame = ("|T" .. classIconPath .. ".tga:0:0:0:0|t")
	else
		ClassSymbolFrame = ""
	end

	local IconHolder = CreateFrame("Frame", "MER_ClassIcon", paperDoll)
	IconHolder:SetSize(20, 20)
	IconHolder:SetPoint("LEFT", title, "RIGHT", -10, 0)

	local texture = IconHolder:CreateTexture(nil, "OVERLAY")
	texture:SetAllPoints()
	texture:SetTexture(classIconPath and (classIconPath .. ".tga") or "")

	local function RefreshTitle()
		ColorTitleText()
	end

	hooksecurefunc("PaperDollFrame_SetLevel", RefreshTitle)
	hooksecurefunc("CharacterFrame_Collapse", function()
		if paperDoll:IsShown() then
			RefreshTitle()
		end
	end)
	hooksecurefunc("CharacterFrame_Expand", function()
		if paperDoll:IsShown() then
			RefreshTitle()
		end
	end)
	hooksecurefunc("ReputationFrame_Update", function()
		if _G.ReputationFrame:IsShown() then
			RefreshTitle()
		end
	end)
	hooksecurefunc("TokenFrame_Update", function()
		if _G.TokenFrame:IsShown() then
			RefreshTitle()
		end
	end)
	local CharacterFrame = _G.CharacterFrame
	if CharacterFrame then
		hooksecurefunc(CharacterFrame, "SetTitle", RefreshTitle)
	end
end

local function SetupCharacterTitle()
	StyleCharacterTitle()
	AddCharacterIcon()
	ColorTitleText()
end

local function StyleCharacterTabs()
	for i = 1, 4 do
		module:ReskinTab(_G["CharacterFrameTab" .. i])
	end
end

local function HideModelBackground(modelFrame)
	if not modelFrame then
		return
	end

	for _, layer in ipairs({ "BACKGROUND", "BORDER", "OVERLAY" }) do
		if modelFrame.DisableDrawLayer then
			modelFrame:DisableDrawLayer(layer)
		end
	end

	if modelFrame.backdrop then
		modelFrame.backdrop:Hide()
	end
end

local function StyleGearManager()
	local GearManager = _G.GearManagerDialog
	if not GearManager then
		return
	end

	GearManager:Styling()
	module:CreateShadow(GearManager)
end

local function StyleHonorFrame()
	if not module:CheckDB("character", "character") then
		return
	end

	local HonorFrame = _G.HonorFrame
	if not HonorFrame or HonorFrame.MERStyled then
		return
	end
	HonorFrame.MERStyled = true

	local progressBar = _G.HonorFrameProgressBar
	if progressBar then
		progressBar:StripTextures()
		progressBar:Height(22)
		progressBar:SetStatusBarTexture(E.media.normTex)
		E:RegisterStatusBar(progressBar)

		if not progressBar.backdrop then
			progressBar:CreateBackdrop("Transparent")
		end

		if progressBar.backdrop then
			progressBar.backdrop:Styling()
		end
	end

	local progressButton = _G.HonorFrameProgressButton
	if progressButton then
		progressButton:StripTextures()
		if not progressButton.backdrop then
			progressButton:CreateBackdrop("Transparent")
		end
		if progressButton.backdrop then
			progressButton.backdrop:Styling()
		end
	end

	local textElements = {
		_G.HonorFrameCurrentSessionTitle,
		_G.HonorFrameYesterdayTitle,
		_G.HonorFrameThisWeekTitle,
		_G.HonorFrameLastWeekTitle,
		_G.HonorFrameLifeTimeTitle,
		_G.HonorFrameCurrentHK,
		_G.HonorFrameYesterdayHK,
		_G.HonorFrameThisWeekHK,
		_G.HonorFrameLastWeekHK,
		_G.HonorFrameLifeTimeHK,
		_G.HonorFrameCurrentDK,
		_G.HonorFrameYesterdayDK,
		_G.HonorFrameThisWeekDK,
		_G.HonorFrameLastWeekDK,
		_G.HonorFrameLifeTimeDK,
		_G.HonorFrameCurrentCP,
		_G.HonorFrameYesterdayCP,
		_G.HonorFrameThisWeekCP,
		_G.HonorFrameLastWeekCP,
		_G.HonorFrameLifeTimeRank,
		_G.HonorFrameCurrentSession,
		_G.HonorFrameYesterdayText,
		_G.HonorFrameThisWeekText,
		_G.HonorFrameLastWeekText,
		_G.HonorFrameLifeTimeText,
	}

	for _, fontString in ipairs(textElements) do
		if fontString and fontString.SetTextColor then
			fontString:SetTextColor(1, 1, 1)
		end
	end
end

local function StyleModelRotators()
	local left = _G.CharacterModelFrameRotateLeftButton
	local right = _G.CharacterModelFrameRotateRightButton

	if left then
		left:Hide()
		left.Show = E.noop
	end
	if right then
		right:Hide()
		right.Show = E.noop
	end
end

local function SetupMerathilisCharacterFrame()
	SuppressDefaultStats()

	local CharacterFrame = _G.CharacterFrame
	local paperDoll = _G.PaperDollFrame
	HookSuppressOnShow(_G.CharacterStatsPane)
	HookSuppressOnShow(_G.CharacterAttributesFrame)
	HookSuppressOnShow(_G.CharacterFrameInset)
	HookSuppressOnShow(_G.CharacterFrame)
	HookSuppressOnShow(paperDoll)

	if CharacterFrame then
		CharacterFrame:HookScript("OnShow", SuppressDefaultStats)
	end

	if not _G.MER_CharacterStatsSuppressor then
		_G.MER_CharacterStatsSuppressor = CreateFrame("Frame")
		_G.MER_CharacterStatsSuppressor:RegisterEvent("ADDON_LOADED")
		_G.MER_CharacterStatsSuppressor:SetScript("OnEvent", function(self, event, addon)
			if addon == "Blizzard_CharacterFrame" then
				SuppressDefaultStats()
				HookSuppressOnShow(_G.CharacterStatsPane)
				HookSuppressOnShow(_G.CharacterAttributesFrame)
				HookSuppressOnShow(_G.CharacterFrameInset)
				HookSuppressOnShow(_G.CharacterFrame)
				HookSuppressOnShow(_G.PaperDollFrame)
				if _G.CharacterFrame then
					_G.CharacterFrame:HookScript("OnShow", SuppressDefaultStats)
				end
				self:UnregisterEvent("ADDON_LOADED")
			end
		end)
	end
end

local function LoadSkin()
	local CharacterFrame = _G.CharacterFrame
	if module:CheckDB("character", "character") and CharacterFrame then
		if CharacterFrame.backdrop then
			CharacterFrame.backdrop:Styling()
		end
		module:CreateBackdropShadow(CharacterFrame)
		module:CreateShadow(CharacterFrame)
		StyleCharacterTabs()
		HideModelBackground(_G.CharacterModelFrame)
		HideModelBackground(_G.CharacterModelScene)
		StyleModelRotators()
		StyleGearManager()
		StyleHonorFrame()
	end

	SetupMerathilisCharacterFrame()
	SetupCharacterTitle()
end

S:AddCallback("CharacterFrame", LoadSkin)
