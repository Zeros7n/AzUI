local MER, F, E, L, V, P, G = unpack(ElvUI_AzUI)
local module = MER:GetModule('MER_Reminder')
local UF = E:GetModule('UnitFrames')
local S = E:GetModule('Skins')
local LCG = E.Libs.CustomGlow

local _G = _G
local ipairs, pairs, select, type, unpack = ipairs, pairs, select, type, unpack
local tinsert = table.insert
local GameTooltip = _G.GameTooltip
local GameTooltip_Hide = _G.GameTooltip_Hide

local AuraUtil_FindAuraByName = AuraUtil.FindAuraByName
local C_PaperDollInfo_OffhandHasWeapon = C_PaperDollInfo.OffhandHasWeapon
local hooksecurefunc = hooksecurefunc
local CreateFrame = CreateFrame
local GetSpecialization = GetSpecialization
local GetSpellCooldown = GetSpellCooldown
local GetSpellInfo = GetSpellInfo
local GetWeaponEnchantInfo = GetWeaponEnchantInfo
local GetInventoryItemTexture = GetInventoryItemTexture
local InCombatLockdown = InCombatLockdown
local IsInInstance = IsInInstance
local IsUsableSpell = IsUsableSpell
local UnitInVehicle = UnitInVehicle
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitLevel = UnitLevel

local FLASK_SPELLS = {
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
}

local SPEC_FLASK_RECOMMENDATIONS = {
	[259] = 371339, -- Assassination: Elemental Chaos for crit/caster support
	[260] = 371186, -- Outlaw: Charged Phial of Alacrity for haste
	[261] = 370652, -- Subtlety: Phial of Static Empowerment for agility bursts
}

local function BuildSpellGroup(list)
	local spells = {}
	if list then
		for _, spellID in ipairs(list) do
			spells[spellID] = true
		end
		spells.defaultIcon = list[1]
	end
	return spells
end

local function GetSpecFlaskSpell(db)
	if not db then
		return nil
	end

	local specID = E.Retail and GetSpecialization()
	if specID and db.flaskSpecSpell and db.flaskSpecSpell[specID] then
		return db.flaskSpecSpell[specID]
	end

	return db.spellGroup and db.spellGroup.defaultIcon
end

module.CreatedReminders = {}

module.ReminderList = {
	DRUID = {
		[1] = { -- Mark of the Wild
			["spellGroup"] = {
				[1126] = true,
				["defaultIcon"] = 1126, -- Mark of the Wild
			},
			["enable"] = true,
			["instance"] = true,
			["pvp"] = true,
			["strictFilter"] = true,
		},
	},

	MAGE = {
		[1] = { -- Arcane Intellect
			["spellGroup"] = {
				[1459] = true,
				["defaultIcon"] = 1459,  -- Arcane Intellect
			},
			["enable"] = true,
			["instance"] = true,
			["pvp"] = true,
			["strictFilter"] = true,
		},
	},

	PRIEST = {
		[1] = { -- Power Word: Fortitude
			["spellGroup"] = {
				[21562] = true,
				["defaultIcon"] = 21562, -- Power Word: Fortitude
			},
			["enable"] = true,
			["instance"] = true,
			["pvp"] = true,
			["strictFilter"] = true,
		},
	},

	ROGUE = {
		[1] = { -- Flasks
			["spellGroup"] = BuildSpellGroup(FLASK_SPELLS),
			["flaskSpecSpell"] = SPEC_FLASK_RECOMMENDATIONS,
			["enable"] = true,
			["instance"] = true,
			["pvp"] = true,
			["strictFilter"] = true,
		},
	},

	SHAMAN = {
		[1] = { -- Lightning Shield
			["spellGroup"] = {
				[192106] = true, -- Lightning Shield
				[974] = true, -- Earth Shield
				["defaultIcon"] = 192106,
			},
			["enable"] = true,
			-- ["combat"] = true,
			["instance"] = true,
			["pvp"] = true,
			["strictFilter"] = true,
			["tree"] = 1, 2, 3
		},
		[2] = { -- Water Shield
			["spellGroup"] = {
				[52127] = true, -- Water Shield
				[974] = true, -- Earth Shield
				[192106] = true, -- Lightning Shield
				["defaultIcon"] = 52127,
			},
			["enable"] = true,
			-- ["combat"] = true,
			["instance"] = true,
			["pvp"] = true,
			["strictFilter"] = true,
			["tree"] = 3,
		},
		[3] = { -- Flametongue Weapon
			["spellGroup"] = {
				[318038] = true,
				["defaultIcon"] = 318038,
			},
			["enable"] = true,
			-- ["combat"] = true,
			["instance"] = true,
			["pvp"] = true,
			["strictFilter"] = true,
			["weaponCheck"] = true,
		},
		[4] = { -- Windfury Weapon
			["spellGroup"] = {
				[33757] = true,
				["defaultIcon"] = 33757,
			},
			["enable"] = true,
			-- ["combat"] = true,
			["instance"] = true,
			["pvp"] = true,
			["strictFilter"] = true,
			["weaponCheck"] = true,
			-- ["tree"] = 2,
		},
	},

	WARRIOR = {
		[1] = { -- Battle Shout
			["spellGroup"] = {
				[6673] = true, -- Battle Shout
				["defaultIcon"] = 6673,
			},
			["enable"] = true,
			["instance"] = true,
			["pvp"] = true,
			["strictFilter"] = true,
		},
	},

	 EVOKER = {
		[1] = { -- Blessing of the Bronze
			["spellGroup"] = {
				[381748] = true, -- Blessing of the Bronze
				["defaultIcon"] = 381748,
			},
			["enable"] = true,
			["instance"] = true,
			["pvp"] = true,
			["strictFilter"] = true,
		},
	},
}

local function ReminderFrame_OnEnter(self)
	if not GameTooltip then
		return
	end

	local specID = E.Retail and GetSpecialization()
	local flaskSpell = GetSpecFlaskSpell(self.db)
	local flaskName = flaskSpell and GetSpellInfo(flaskSpell)

	GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
	GameTooltip:SetText(flaskName or L["Flasks"], 1, 1, 1, true)

	if specID then
		local _, specName = GetSpecializationInfo(specID)
		if specName then
			GameTooltip:AddLine(specName, 0.8, 0.8, 0.8)
		end
	end

	GameTooltip:Show()
end

local function ReminderFrame_OnLeave()
	if GameTooltip_Hide then
		GameTooltip_Hide()
	end
end

function module:PlayerHasFilteredBuff(frame, db, checkPersonal)
	for buff, value in pairs(db) do
		if value == true then
			local name = GetSpellInfo(buff)
			local _, icon, _, _, _, _, unitCaster, _, _, _ = AuraUtil_FindAuraByName(name, "player", "HELPFUL")

			if checkPersonal then
				if (name and icon and unitCaster == "player") then
					return true
				end
			else
				if (name and icon) then
					return true
				end
			end
		end
	end
	return false
end

function module:PlayerHasFilteredDebuff(frame, db)
	for debuff, value in pairs(db) do
		if value == true then
			local name = GetSpellInfo(debuff)
			local _, icon, _, _, _, _, _, _, _, _ = AuraUtil_FindAuraByName(name, "player", "HARMFUL")

			if (name and icon) then
				return true
			end
		end
	end
	return false
end

function module:CanSpellBeUsed(id)
	local name = GetSpellInfo(id)
	local start, duration, enabled = GetSpellCooldown(name)
	if enabled == 0 or start == nil or duration == nil then
		return false
	elseif start > 0 and duration > 1.5 then --On Cooldown
		return false
	else --Off Cooldown
		return true
	end
end

function module:ReminderIcon_OnUpdate(elapsed)
	if self.ForceShow and self.icon:GetTexture() then
		return
	end

	if(self.elapsed and self.elapsed > 0.2) then
		local db = module.ReminderList[E.myclass][self.groupName]
		if not db or not db.enable or UnitIsDeadOrGhost("player") then return; end
		if db.CDSpell then
			local filterCheck = module:FilterCheck(self)
			local name = GetSpellInfo(db.CDSpell)
			local start, duration = GetSpellCooldown(name)
			if(duration and duration > 0) then
				self.cooldown:SetCooldown(start, duration)
				self.cooldown:Show()
			else
				self.cooldown:Hide()
			end

			if module:CanSpellBeUsed(db.CDSpell) and filterCheck then
				if db.OnCooldown == "HIDE" then
					module:UpdateColors(self, db.CDSpell)
					module.ReminderIcon_OnEvent(self)
				else
					self:SetAlpha(db.cdFade or 0)
				end
			elseif filterCheck then
				if db.OnCooldown == "HIDE" then
					self:SetAlpha(db.cdFade or 0)
				else
					module:UpdateColors(self, db.CDSpell)
					module.ReminderIcon_OnEvent(self)
				end
			else
				self:SetAlpha(0)
			end

			self.elapsed = 0
			return
		end

		if db.spellGroup then
			for buff, value in pairs(db.spellGroup) do
				if value == true and module:CanSpellBeUsed(buff) then
					self:SetScript("OnUpdate", nil)
					module.ReminderIcon_OnEvent(self)
				end
			end
		end

		self.elapsed = 0
	else
		self.elapsed = (self.elapsed or 0) + elapsed
	end
end

function module:FilterCheck(frame, isReverse)
	local _, instanceType = IsInInstance()
	local roleCheck, treeCheck, combatCheck, instanceCheck, PVPCheck

	local db = module.ReminderList[E.myclass][frame.groupName]

	if db.role then
		if db.role == E:GetPlayerRole() or db.role == "ANY" then
			roleCheck = true
		else
			roleCheck = nil
		end
	else
		roleCheck = true
	end

	if db.tree then
		if db.tree == GetSpecialization() or db.tree == "ANY" then
			treeCheck = true
		else
			treeCheck = nil
		end
	else
		treeCheck = true
	end

	if db.combat then
		if InCombatLockdown() then
			combatCheck = true
		else
			combatCheck = nil
		end
	else
		combatCheck = true
	end

	if db.instance and (instanceType == "party" or instanceType == "raid") then
		instanceCheck = true
	else
		instanceCheck = nil
	end

	if db.pvp and (instanceType == "arena" or instanceType == "pvp") then
		PVPCheck = true
	else
		PVPCheck = nil
	end

	if not db.pvp and not db.instance then
		PVPCheck = true
		instanceCheck = true
	end

	if isReverse and (combatCheck or instanceCheck or PVPCheck) then
		return true
	elseif roleCheck and treeCheck and (combatCheck or instanceCheck or PVPCheck) then
		return true
	else
		return false
	end
end

function module:ReminderIcon_OnEvent(event, unit)
	if (event == "UNIT_AURA" and unit ~= "player") then return end

	local db = module.ReminderList[E.myclass][self.groupName]
	local activeTree = E.Retail and GetSpecialization()

	self.cooldown:Hide()
	self:SetAlpha(0)
	self.icon:SetTexture(nil)

	if not db or not db.enable or (not db.spellGroup and not db.weaponCheck and not db.CDSpell) or UnitIsDeadOrGhost("player") then
		self:SetScript("OnUpdate", nil)
		self:SetAlpha(0)
		self.icon:SetTexture(nil)

		if not db then
			module.CreatedReminders[self.groupName] = nil
		end
		return
	end

	--Level Check
	if db.level and UnitLevel("player") < db.level and not self.ForceShow then return end

	--Negate Spells Check
	if db.negateGroup and module:PlayerHasFilteredBuff(self, db.negateGroup) and not self.ForceShow then return end

	local hasOffhandWeapon = C_PaperDollInfo_OffhandHasWeapon()
	local hasMainHandEnchant, _, _, hasOffHandEnchant = GetWeaponEnchantInfo()
	local hasBuff, hasDebuff
	if db.spellGroup and not db.CDSpell then
		for buff, value in pairs(db.spellGroup) do
			if value == true then
				local name = GetSpellInfo(buff)
				local usable, nomana = IsUsableSpell(name)
				if usable and not module:CanSpellBeUsed(buff) then
					self:SetScript("OnUpdate", module.ReminderIcon_OnUpdate)
					return
				end

				if (usable or nomana) or not db.strictFilter or self.ForceShow then
					local iconSpell = db.flaskSpecSpell and db.flaskSpecSpell[activeTree] or db.spellGroup.defaultIcon
					if iconSpell then
						self.icon:SetTexture(select(3, GetSpellInfo(iconSpell)))
					end
					break
				end
			end
		end

		if (not self.icon:GetTexture() and event == "PLAYER_ENTERING_WORLD") then
			self:UnregisterAllEvents()
			self:RegisterEvent("UNIT_AURA")
			self:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
			self:RegisterEvent("PLAYER_TALENT_UPDATE")
			self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

			if db.combat then
				self:RegisterEvent("PLAYER_REGEN_ENABLED")
				self:RegisterEvent("PLAYER_REGEN_DISABLED")
			end

			if db.instance or db.pvp then
				self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
			end

			if db.role then
				self:RegisterEvent("UNIT_INVENTORY_CHANGED")
			end
			return
		end

		hasBuff, hasDebuff = module:PlayerHasFilteredBuff(self, db.spellGroup, db.personal), module:PlayerHasFilteredDebuff(self, db.spellGroup)
	end

	if db.weaponCheck then
		self:UnregisterAllEvents()
		self:RegisterEvent("UNIT_INVENTORY_CHANGED")

		if not hasOffhandWeapon and hasMainHandEnchant then
			self.icon:SetTexture(GetInventoryItemTexture("player", 16))
		else
			if not hasOffHandEnchant then
				self.icon:SetTexture(GetInventoryItemTexture("player", 17))
			end

			if not hasMainHandEnchant then
				self.icon:SetTexture(GetInventoryItemTexture("player", 16))
			end
		end

		if db.combat then
			self:RegisterEvent("PLAYER_REGEN_ENABLED")
			self:RegisterEvent("PLAYER_REGEN_DISABLED")
		end

		if db.instance or db.pvp then
			self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
		end

		if db.role then
			self:RegisterEvent("UNIT_INVENTORY_CHANGED")
		end
	end

	if db.CDSpell then
		if type(db.CDSpell) == "boolean" then return end
		local name = GetSpellInfo(db.CDSpell)
		local usable, nomana = IsUsableSpell(name)
		if not usable then return end

		self:SetScript("OnUpdate", module.ReminderIcon_OnUpdate)

		self.icon:SetTexture(select(3, GetSpellInfo(db.CDSpell)))

		self:UnregisterAllEvents()
	end

	if self.ForceShow and self.icon:GetTexture() then
		self:SetAlpha(1)
		return
	elseif self.ForceShow then
		F.Print("Attempted to show a reminder icon that does not have any spells. You must add a spell first.")
		return
	end

	if not self.icon:GetTexture() or UnitInVehicle("player") then
		return
	end

	local filterCheck = module:FilterCheck(self)
	local reverseCheck = module:FilterCheck(self, true)

	if db.CDSpell then
		if filterCheck then
			self:SetAlpha(1)
		end
		return
	end

	if db.spellGroup and not db.weaponCheck then
		if filterCheck and ((not hasBuff) and (not hasDebuff)) and not db.reverseCheck then
			self:SetAlpha(1)
		elseif reverseCheck and db.reverseCheck and (hasBuff or hasDebuff) and not (db.talentTreeException == activeTree) then
			self:SetAlpha(1)
		elseif reverseCheck and db.reverseCheck and ((not hasBuff) and (not hasDebuff)) and (db.talentTreeException == activeTree) then
			self:SetAlpha(1)
		end
	elseif db.weaponCheck then
		if filterCheck then
			if not hasOffhandWeapon and not hasMainHandEnchant then
				self:SetAlpha(1)
				self.icon:SetTexture(GetInventoryItemTexture("player", 16))
			elseif hasOffhandWeapon and (not hasMainHandEnchant or not hasOffHandEnchant) then
				if not hasMainHandEnchant then
					self.icon:SetTexture(GetInventoryItemTexture("player", 16))
				else
					self.icon:SetTexture(GetInventoryItemTexture("player", 17))
				end
				self:SetAlpha(1)
			end
		end
	end

	local r, g, b = unpack(E["media"].rgbvaluecolor)
	local color = {r, g, b, 1}
	if self:GetAlpha() == 1 then
		LCG.PixelGlow_Start(self.overlay, color, nil, 0.25, nil, 1)
	else
		LCG.PixelGlow_Stop(self.overlay)
	end
end

function module:CreateReminder(name, index)
	if module.CreatedReminders[name] or not E.db.unitframe.units.player.enable then return end
	local db = module.ReminderList[E.myclass][name]

	local size = module.db.size or 30
	local ElvFrame = _G.ElvUF_Player

	local holder = CreateFrame("Frame", MER.Title.."Reminder"..index, E.UIParent)
	holder:SetSize(40, 40)
	holder:ClearAllPoints()
	if ElvFrame then
		holder:SetPoint("RIGHT", ElvFrame, "LEFT", -3, 0)
	else
		holder:SetPoint("BOTTOMLEFT", E.UIParent, "BOTTOMLEFT", 573, 199)
	end
	E:CreateMover(holder, "MER_ReminderMover"..index, L["Reminders"], nil, nil, nil, "ALL,SOLO,AzUI", nil, 'mui,modules,reminder')

	local button = CreateFrame("Button", "MER_ReminderIcon"..index, holder)
	button:SetSize(size, size)
	button:ClearAllPoints()
	button:SetPoint("CENTER", holder, "CENTER", 0, 0)
	button:SetFrameStrata(ElvFrame:GetFrameStrata())
	button:EnableMouse(false)
	button:SetAlpha(0)
	button.groupName = name

	local icon = button:CreateTexture(nil, "OVERLAY")
	icon:SetAllPoints()
	S:HandleIcon(icon)
	button.icon = icon

	-- Used for Glow
	local overlay = CreateFrame("Button", nil, button)
	overlay:SetOutside(frame, 2, 2)
	button.overlay = overlay

	local cd = CreateFrame("Cooldown", nil, button)
	cd:SetAllPoints(icon)
	E:RegisterCooldown(cd)
	button.cooldown = cd

	button:RegisterUnitEvent("UNIT_AURA", "player")
	button:RegisterEvent("PLAYER_ENTERING_WORLD")
	button:SetScript("OnEvent", module.ReminderIcon_OnEvent)
	button:SetScript("OnEnter", ReminderFrame_OnEnter)
	button:SetScript("OnLeave", ReminderFrame_OnLeave)
	button.db = db

	tinsert(module.CreatedReminders, button)
end

function module:CheckForNewReminders()
	local db = module.ReminderList[E.myclass]
	if not db then return end

	local index = 0
	for groupName, _ in pairs(db) do
		module:CreateReminder(groupName, index)
		index = index + 1
	end
end

function module:Initialize()
	module.db = E.db.mui.reminder
	if not module.db.enable then return end

	hooksecurefunc(UF, 'LoadUnits', module.CheckForNewReminders)
end

MER:RegisterModule(module:GetName())
