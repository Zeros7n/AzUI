local MER, F, E, L, V, P, G = unpack(ElvUI_AzUI)
local module = MER:GetModule('MER_RaidBuffs')
module.db = (E.db.mui and E.db.mui.raidBuffs) or {}
local LCG = E.Libs.CustomGlow

local GameTooltip = _G.GameTooltip
local GameTooltip_Hide = _G.GameTooltip_Hide

local function BuffFrame_OnEnter(frame)
	if not GameTooltip or not frame then
		return
	end

	local tooltipText = (frame.hasBuff and frame.buffName) or frame.defaultName or frame:GetName()
	if not tooltipText then
		return
	end

	GameTooltip:SetOwner(frame, "ANCHOR_BOTTOMRIGHT")
	GameTooltip:SetText(tooltipText, 1, 1, 1, true)
end

local function BuffFrame_OnLeave()
	if GameTooltip_Hide then
		GameTooltip_Hide()
	end
end

local ipairs, pairs, select, unpack = ipairs, pairs, select, unpack
local tinsert = table.insert

local CreateFrame = CreateFrame
local RegisterStateDriver = RegisterStateDriver
local UnregisterStateDriver = UnregisterStateDriver
local GetSpellInfo = GetSpellInfo
local AuraUtil_FindAuraByName = AuraUtil.FindAuraByName
local GetWeaponEnchantInfo = GetWeaponEnchantInfo
local GetInventoryItemTexture = GetInventoryItemTexture
local CancelUnitBuff = CancelUnitBuff
local UnitBuff = UnitBuff

local r, g, b = unpack(E["media"].rgbvaluecolor)
local color = {r, g, b, 1}

module.VisibilityStates = {
	["DEFAULT"] = "[noexists, nogroup] hide; show",
	["INPARTY"] = "[combat] hide; [group] show; [petbattle] hide; hide",
	["ALWAYS"] = "[petbattle] hide; show",
}

module.ReminderBuffs = {
	Flask = {
		-- Dragonflight
		370652, -- Phial of Static Empowerment
		370661, -- Phial of Icy Preservation
		371172, -- Phial of Tepid Versatility
		371186, -- Charged Phial of Alacrity
		371204, -- Phial of Still Air
		371339, -- Phial of Elemental Chaos
		371354, -- Phial of the Eye in the Storm
		371386, -- Phial of Charged Isolation
		373257, -- Phial of Glacial Fury
		374000, -- Iced Phial of Corrupting Rage

	},
	DefiledAugmentRune = {
		224001,			-- Defiled Augumentation (15 primary stat)
		270058,			-- Battle Scarred Augmentation (60 primary stat)
		347901,			-- Veiled Augmentation (18 primary stat)
		367405,			-- Eternal Augmentation (18 Agi, Strength or Int)
	},
	Food = {
		104280,	-- Well Fed

		-- Shadowlands
		259455,	-- Well Fed
		308434,	-- Well Fed
		308488,	-- Well Fed
		308506,	-- Well Fed
		308514,	-- Well Fed
		308637,	-- Well Fed
		327715,	-- Well Fed
		327851,	-- Well Fed
	},
	Intellect = {
		1459, -- Arcane Intellect
		264760, -- War-Scroll of Intellect
	},
	Stamina = {
		6307, -- Blood Pact
		21562, -- Power Word: Fortitude
		264764, -- War-Scroll of Fortitude
	},
	AttackPower = {
		6673, -- Battle Shout
		264761, -- War-Scroll of Battle
	},
	Versatility = {
		1126, -- Mark of the Wild
	},
	Cooldown_Reduce = {
		381748, -- Blessing of the Bronze
	},
	Weapon = {
		1, -- just a fallback
	},
	Custom = {
		-- spellID,	-- Spell name
	},
}

if not E.Retail then
	local CLASSIC_REMINDER_BUFFS = {
		Flask = {13510, 13511, 13512, 13513, 13518, 22808, 22832, 22861, 22810, 22809},
		Intellect = {1460, 1461, 10156, 10157, 27126, 1459, 23028},
		Stamina = {21562, 21564, 10938, 10937},
		AttackPower = {6673, 5242, 5212},
		Versatility = {1126, 5232, 21849},
	}
	for category, list in pairs(CLASSIC_REMINDER_BUFFS) do
		module.ReminderBuffs[category] = module.ReminderBuffs[category] or {}
		for _, spellID in ipairs(list) do
			tinsert(module.ReminderBuffs[category], spellID)
		end
	end
end

local function FilterSpellList(list)
	local filtered = {}
	if list then
		for _, spellID in ipairs(list) do
			if GetSpellInfo(spellID) then
				tinsert(filtered, spellID)
			end
		end
	end
	return filtered
end

for _, category in ipairs({"Flask", "DefiledAugmentRune", "Food", "Intellect", "Stamina", "AttackPower", "Versatility", "Cooldown_Reduce"}) do
	module.ReminderBuffs[category] = FilterSpellList(module.ReminderBuffs[category])
end

module.Weapon_Enchants = {
	6188, -- Shadowcore Oil
	6190, -- Embalmer's Oil
	6200, -- Shaded Sharpening Stone
	6201, -- Shaded Weightstone
}

local function EnchantsID(id)
	for i, v in ipairs(module.Weapon_Enchants) do
		if id == v then
			return true
		end
	end
	return false
end

local flaskbuffs = module.ReminderBuffs["Flask"]
local foodbuffs = module.ReminderBuffs["Food"]
local darunebuffs = module.ReminderBuffs["DefiledAugmentRune"]
local cooldowns = module.ReminderBuffs["Cooldown_Reduce"]
local intellectbuffs = module.ReminderBuffs["Intellect"]
local staminabuffs = module.ReminderBuffs["Stamina"]
local attackpowerbuffs = module.ReminderBuffs["AttackPower"]
local versatilitybuffs = module.ReminderBuffs["Versatility"]
local custombuffs = module.ReminderBuffs["Custom"]
local weaponEnch = module.ReminderBuffs["Weapon"]

local function GetTooltipName(spellList, fallbackSpellID)
	if fallbackSpellID then
		local name = GetSpellInfo(fallbackSpellID)
		if name then
			return name
		end
	end

	if spellList then
		for _, spellID in ipairs(spellList) do
			local name = GetSpellInfo(spellID)
			if name then
				return name
			end
		end
	end
end

local function UpdateBuffFrame(frame, spellList, fallbackSpellID)
	if not frame then
		return
	end

	frame.buffName = nil
	frame.hasBuff = false

	if not (spellList and spellList[1]) then
		return
	end

	local iconID = fallbackSpellID or spellList[1]
	local iconTexture = iconID and select(3, GetSpellInfo(iconID))
	if iconTexture then
		frame.t:SetTexture(iconTexture)
	end

	local defaultName = GetTooltipName(spellList, fallbackSpellID)
	if defaultName then
		frame.defaultName = defaultName
	end

	for _, spellID in ipairs(spellList) do
		local spellname = select(1, GetSpellInfo(spellID))
		if spellname and AuraUtil_FindAuraByName(spellname, "player") then
			frame.buffName = spellname
			frame.hasBuff = true
			local texture = select(3, GetSpellInfo(spellID))
			if texture then
				frame.t:SetTexture(texture)
			end
			frame:SetAlpha(module.db.alpha)
			LCG.PixelGlow_Stop(frame)
			return
		end
	end

	frame:SetAlpha(1)
	if module.db and module.db.glow then
		LCG.PixelGlow_Start(frame, color, nil, -0.25, nil, 1)
	end
end

local function CancelBuff(frame)
	if not (frame and frame.hasBuff and frame.buffName) then
		return
	end

	for i = 1, 40 do
		local name = UnitBuff("player", i)
		if name and name == frame.buffName then
			CancelUnitBuff("player", i)
			break
		end
	end
end
local function OnAuraChange(self, event, arg1, unit)
	if (event == "UNIT_AURA" and arg1 ~= "player") then return end

	module.db = module.db or (E.db.mui and E.db.mui.raidBuffs)
	if not module.db then
		return
	end

	if flaskbuffs and flaskbuffs[1] then
		UpdateBuffFrame(FlaskFrame, flaskbuffs)
	end

	if foodbuffs and foodbuffs[1] then
		UpdateBuffFrame(FoodFrame, foodbuffs)
	end

	if module.db.class then
		if intellectbuffs and intellectbuffs[1] then
			UpdateBuffFrame(IntellectFrame, intellectbuffs, 1459)
		end
		if staminabuffs and staminabuffs[1] then
			UpdateBuffFrame(StaminaFrame, staminabuffs, 21562)
		end
		if attackpowerbuffs and attackpowerbuffs[1] then
			UpdateBuffFrame(AttackPowerFrame, attackpowerbuffs, 6673)
		end
		if versatilitybuffs and versatilitybuffs[1] then
			UpdateBuffFrame(VersatilityFrame, versatilitybuffs, 1126)
		end
		if cooldowns and cooldowns[1] then
			UpdateBuffFrame(CooldownFrame, cooldowns, 381748)
		end
	end

	if custombuffs and custombuffs[1] then
		local foundCustom
		local customDefaultName
		for _, spellID in ipairs(custombuffs) do
			local name, _, icon = GetSpellInfo(spellID)
			if name and not customDefaultName then
				customDefaultName = name
			end
			if name and icon and not CustomFrame.iconSet then
				CustomFrame.t:SetTexture(icon)
				CustomFrame.iconSet = true
			end
			if name and F.CheckPlayerBuff(name) then
				CustomFrame.buffName = name
				CustomFrame.hasBuff = true
				CustomFrame:SetAlpha(module.db.alpha)
				LCG.PixelGlow_Stop(CustomFrame)
				foundCustom = true
				break
			end
		end
		if customDefaultName then
			CustomFrame.defaultName = customDefaultName
		else
			CustomFrame.defaultName = L["Custom"]
		end
		if not foundCustom then
			CustomFrame.buffName = nil
			CustomFrame.hasBuff = false
			CustomFrame:SetAlpha(1)
			if module.db.glow then
				LCG.PixelGlow_Start(CustomFrame, color, nil, -0.25, nil, 1)
			end
		end
		CustomFrame:Show()
	else
		CustomFrame:Hide()
		CustomFrame.buffName = nil
		CustomFrame.hasBuff = false
		CustomFrame.iconSet = nil
		CustomFrame.defaultName = nil
	end
end

function module:CreateIconBuff(name, relativeTo, firstbutton, tooltipText)
	local button = CreateFrame("Button", name, module.frame)

	if firstbutton == true then
		button:CreatePanel("Transparent", E.db.mui.raidBuffs.size, E.db.mui.raidBuffs.size, "BOTTOMLEFT", relativeTo, "BOTTOMLEFT", 0, 0)
	else
		button:CreatePanel("Transparent", E.db.mui.raidBuffs.size, E.db.mui.raidBuffs.size, "LEFT", relativeTo, "RIGHT", 3, 0)
	end
	button:SetFrameLevel(RaidBuffReminder:GetFrameLevel() + 2)

	button.t = button:CreateTexture(name..".t", "OVERLAY")
	button.t:SetTexCoord(unpack(E.TexCoords))
	button.t:SetPoint("TOPLEFT", 2, -2)
	button.t:SetPoint("BOTTOMRIGHT", -2, 2)

	button:SetScript("OnEnter", BuffFrame_OnEnter)
	button:SetScript("OnLeave", BuffFrame_OnLeave)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:SetScript("OnMouseUp", function(self, button)
		if button == "RightButton" then
			CancelBuff(self)
		end
	end)
	button.defaultName = tooltipText or name
end

function module:Visibility()
	local db = module.db or (E.db.mui and E.db.mui.raidBuffs)
	if not db then
		return
	end

	module.db = db

	local frame = self.frame
	if not frame then
		return
	end

	local mover = frame.mover
	if db.enable then
		RegisterStateDriver(frame, "visibility", db.visibility == "CUSTOM" and db.customVisibility or module.VisibilityStates[db.visibility])
		if mover then
			E:EnableMover(mover:GetName())
		end
	else
		UnregisterStateDriver(frame, "visibility")
		frame:Hide()
		if mover then
			E:DisableMover(mover:GetName())
		end
	end
end

function module:Initialize()
	if not (E.Retail or E.Classic or E.TBC) then return end

	module.db = E.db.mui.raidBuffs
	if not module.db.enable then return end

	-- Anchor
	self.Anchor = CreateFrame("Frame", "RaidBuffAnchor", E.UIParent)
	self.Anchor:SetWidth((E.db.mui.raidBuffs.size * 6) + 15)
	self.Anchor:SetHeight(E.db.mui.raidBuffs.size)
	self.Anchor:SetPoint("TOPLEFT", E.UIParent, "TOPLEFT", 11, -15)

	self.frame = CreateFrame("Frame", "RaidBuffReminder", E.UIParent)
	self.frame:CreatePanel("Invisible", (E.db.mui.raidBuffs.size * 6) + 15, E.db.mui.raidBuffs.size + 4, "TOPLEFT", RaidBuffAnchor, "TOPLEFT", 0, 4)

	if module.db.class then
		self:CreateIconBuff("IntellectFrame", RaidBuffReminder, true, GetTooltipName(intellectbuffs, 1459))
		self:CreateIconBuff("StaminaFrame", IntellectFrame, false, GetTooltipName(staminabuffs, 21562))
		self:CreateIconBuff("AttackPowerFrame", StaminaFrame, false, GetTooltipName(attackpowerbuffs, 6673))
		self:CreateIconBuff("VersatilityFrame", AttackPowerFrame, false, GetTooltipName(versatilitybuffs, 1126))
		self:CreateIconBuff("FlaskFrame", VersatilityFrame, false, GetTooltipName(flaskbuffs))
		self:CreateIconBuff("FoodFrame", FlaskFrame, false, GetTooltipName(foodbuffs))
		self:CreateIconBuff("CooldownFrame", FoodFrame, false, GetTooltipName(cooldowns, 381748))
		-- self:CreateIconBuff("DARuneFrame", FoodFrame, false)
		-- self:CreateIconBuff("WeaponFrame", DARuneFrame, false)
		self:CreateIconBuff("CustomFrame", CooldownFrame, false, GetTooltipName(custombuffs) or L["Custom"])
	else
		self:CreateIconBuff("FlaskFrame", RaidBuffReminder, true, GetTooltipName(flaskbuffs))
		self:CreateIconBuff("FoodFrame", FlaskFrame, false, GetTooltipName(foodbuffs))
		-- self:CreateIconBuff("DARuneFrame", FoodFrame, false)
		-- self:CreateIconBuff("WeaponFrame", DARuneFrame, false)
		self:CreateIconBuff("CustomFrame", FoodFrame, false, GetTooltipName(custombuffs) or L["Custom"])
	end

	if E.Retail then
		self.frame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
	end
	self.frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
	self.frame:RegisterEvent("UNIT_AURA")
	self.frame:RegisterEvent("PLAYER_REGEN_ENABLED")
	self.frame:RegisterEvent("PLAYER_REGEN_DISABLED")
	self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	self.frame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
	self.frame:RegisterEvent("CHARACTER_POINTS_CHANGED")
	self.frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	self.frame:RegisterEvent("GROUP_ROSTER_UPDATE")
	self.frame:SetScript("OnEvent", OnAuraChange)

	E:CreateMover(self.frame, "MER_RaidBuffReminderMover", L["Raid Buffs Reminder"], nil, nil, nil, "ALL,SOLO,PARTY,RAID,AzUI", nil, 'mui,modules,raidBuffs')

	self:Visibility()
end

MER:RegisterModule(module:GetName())
