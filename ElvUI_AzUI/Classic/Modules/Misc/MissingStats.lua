local MER, F, E, L, V, P, G = unpack(ElvUI_AzUI)
local module = MER:GetModule('MER_Misc')

local _G = _G
local ipairs, pairs = ipairs, pairs
local CreateFrame = CreateFrame
local UIFrameFadeIn = UIFrameFadeIn
local GameTooltip = GameTooltip
local GameTooltip_Hide = GameTooltip_Hide

local format = string.format
local floor = math.floor
local ceil = math.ceil
local max = math.max
local wipe = wipe
local C_Timer = _G.C_Timer
local UnitStat = UnitStat
local UnitArmor = UnitArmor
local UnitDefense = UnitDefense
local UnitDamage = UnitDamage
local UnitAttackSpeed = UnitAttackSpeed
local UnitAttackPower = UnitAttackPower
local GetCritChance = GetCritChance
local GetDodgeChance = GetDodgeChance
local GetParryChance = GetParryChance
local GetBlockChance = GetBlockChance
local GetSpellBonusDamage = GetSpellBonusDamage
local GetSpellBonusHealing = GetSpellBonusHealing
local GetSpellCritChance = GetSpellCritChance
local GetManaRegen = GetManaRegen
local GetSpellHitModifier = GetSpellHitModifier
local GetHitModifier = GetHitModifier
local UnitRangedDamage = UnitRangedDamage
local UnitRangedAttackPower = UnitRangedAttackPower
local GetRangedCritChance = GetRangedCritChance

local PANEL_WIDTH = 210
local HEADER_HEIGHT = 22
local LINE_HEIGHT = 18
local LINE_SPACING = 4
local SECTION_SPACING = 10

local statPanel
local scrollFrame
local scrollChild
local categories = {}
local defaultWidth
local expandedWidth
local modelDefaults = {}
local hideStatsPaneFrame = nil

local function SealBlizzardFrame(frame)
	if not frame or frame.MERHidden then
		return
	end

	local hiddenParent = E.HiddenFrame or _G.UIParent
	frame:EnableMouse(false)
	frame:ClearAllPoints()
	frame:SetParent(hiddenParent)
	frame:SetPoint("CENTER", hiddenParent, "CENTER")
	frame:SetScale(0.0001)
	frame:SetAlpha(0)
	frame:Hide()
	frame.Show = E.noop
	frame.Hide = E.noop
	frame.SetShown = E.noop
	frame.MERHidden = true
	frame:HookScript("OnShow", function(self) self:Hide() end)
end

local function HideBlizzardStatsPane()
	SealBlizzardFrame(_G.CharacterStatsPane)
	SealBlizzardFrame(_G.CharacterAttributesFrame)
	SealBlizzardFrame(_G.CharacterFrameInsetRight)
end

local function QueueHideBlizzardStatsPane()
	local statsPane = _G.CharacterStatsPane
	if statsPane then
		HideBlizzardStatsPane()
		InitializePanel()
		return
	end

	if hideStatsPaneFrame then
		return
	end

	hideStatsPaneFrame = CreateFrame("Frame")
	hideStatsPaneFrame:RegisterEvent("ADDON_LOADED")
	hideStatsPaneFrame:SetScript("OnEvent", function(self, _, addon)
		if addon == "Blizzard_CharacterFrame" then
			HideBlizzardStatsPane()
			InitializePanel()
			self:UnregisterEvent("ADDON_LOADED")
			self:SetScript("OnEvent", nil)
			hideStatsPaneFrame = nil
		end
	end)
end

local function ShowTooltip(frame)
	if not (frame.tooltip or frame.tooltip2 or frame.tooltip3) then
		return
	end

	GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
	if frame.tooltip then
		GameTooltip:SetText(frame.tooltip, nil, nil, nil, nil, true)
	end
	if frame.tooltip2 then
		GameTooltip:AddLine(frame.tooltip2, nil, nil, nil, true)
	end
	if frame.tooltip3 then
		GameTooltip:AddLine(frame.tooltip3, nil, nil, nil, true)
	end
	GameTooltip:Show()
end

local function HideTooltip()
	GameTooltip_Hide()
end

local function StatFrame_OnEnter(frame)
	if frame.onEnterFunc then
		frame.onEnterFunc(frame)
	else
		ShowTooltip(frame)
	end
end

local function StatFrame_OnLeave(frame)
	if frame.onLeaveFunc then
		frame.onLeaveFunc(frame)
	else
		HideTooltip()
	end
end

local function CreateStatRow(parent, index)
	local frame = CreateFrame("Button", "$parentStat"..index, parent)
	frame.Label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.Value = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")

	frame:SetHeight(LINE_HEIGHT)
	frame:SetWidth(PANEL_WIDTH)
	frame:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

	frame.Label:ClearAllPoints()
	frame.Label:SetPoint("LEFT", frame, "LEFT", 6, 0)
	frame.Value:ClearAllPoints()
	frame.Value:SetPoint("RIGHT", frame, "RIGHT", -6, 0)
	frame.Value:SetJustifyH("RIGHT")

	frame:SetID(index)
	frame.unit = "player"

	frame:SetScript("OnEnter", StatFrame_OnEnter)
	frame:SetScript("OnLeave", StatFrame_OnLeave)

	return frame
end

local function PositionStatRow(frame, anchor, order)
	local yOffset = -6 - ((order - 1) * (LINE_HEIGHT + LINE_SPACING))
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)
	frame:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, yOffset)
end

local function FormatNumber(value)
	if type(value) ~= "number" then
		return value or ""
	end

	if BreakUpLargeNumbers then
		return BreakUpLargeNumbers(value)
	end

	return format("%d", value)
end

local function SetSimpleStat(frame, label, value, tooltip, tooltip2)
	frame.Label:SetText(label or "")
	frame.Value:SetText(value or "")
	frame.tooltip = tooltip
	frame.tooltip2 = tooltip2
	frame.onEnterFunc = nil
	frame.onLeaveFunc = nil
	frame:Show()

	return true
end

local PRIMARY_STAT_LABELS = {
	_G.SPELL_STAT1_NAME or "Strength",
	_G.SPELL_STAT2_NAME or "Agility",
	_G.SPELL_STAT3_NAME or "Stamina",
	_G.SPELL_STAT4_NAME or "Intellect",
	_G.SPELL_STAT5_NAME or "Spirit",
}

local function UpdatePrimaryStat(frame, index)
	local label = PRIMARY_STAT_LABELS[index] or format("Stat %d", index)
	local _, effective, posBuff, negBuff = UnitStat("player", index)
	local value = FormatNumber(effective or 0)

	if (posBuff and posBuff ~= 0) or (negBuff and negBuff ~= 0) then
		local baseValue = (effective or 0) - (posBuff or 0) - (negBuff or 0)
		value = format("%s (%d)", value, baseValue)
	end

	return SetSimpleStat(frame, label, value)
end

local function UpdateArmorStat(frame)
	local _, effectiveArmor, _, posBuff, negBuff = UnitArmor("player")
	local value = FormatNumber(effectiveArmor or 0)

	if (posBuff and posBuff ~= 0) or (negBuff and negBuff ~= 0) then
		local baseValue = (effectiveArmor or 0) - (posBuff or 0) - (negBuff or 0)
		value = format("%s (%d)", value, baseValue)
	end

	return SetSimpleStat(frame, _G.ARMOR or "Armor", value)
end

local function UpdateDefenseStat(frame)
	local base, effective = UnitDefense("player")
	return SetSimpleStat(frame, _G.DEFENSE or "Defense", FormatNumber(effective or base or 0))
end

local function UpdateDodgeStat(frame)
	local value = GetDodgeChance and GetDodgeChance() or 0
	return SetSimpleStat(frame, _G.DODGE or "Dodge", format("%.2f%%", value))
end

local function UpdateParryStat(frame)
	local value = GetParryChance and GetParryChance() or 0
	return SetSimpleStat(frame, _G.PARRY or "Parry", format("%.2f%%", value))
end

local function UpdateBlockStat(frame)
	local value = GetBlockChance and GetBlockChance() or 0
	return SetSimpleStat(frame, _G.BLOCK or "Block", format("%.2f%%", value))
end

local function UpdateMeleeDamageStat(frame)
	local speed = select(1, UnitAttackSpeed("player"))
	local minDamage, maxDamage, _, _, physicalBonusPos, physicalBonusNeg, percent = UnitDamage("player")

	minDamage = minDamage or 0
	maxDamage = maxDamage or 0
	physicalBonusPos = physicalBonusPos or 0
	physicalBonusNeg = physicalBonusNeg or 0
	percent = percent or 1

	local damageSpread = format("%d - %d", max(floor(minDamage), 1), max(ceil(maxDamage), 1))
	local tooltip = nil

	if speed and speed > 0 then
		local baseDamage = (minDamage + maxDamage) * 0.5
		local fullDamage = (baseDamage + physicalBonusPos + physicalBonusNeg) * percent
		local dps = fullDamage / speed
		tooltip = format("%s: %.2f\n%s: %.2f", _G.WEAPON_SPEED or "Speed", speed, _G.DAMAGE_PER_SECOND or "DPS", dps)
	end

	return SetSimpleStat(frame, _G.DAMAGE or "Damage", damageSpread, tooltip)
end

local function UpdateMeleeSpeedStat(frame)
	local mainSpeed, offSpeed = UnitAttackSpeed("player")
	local value

	if offSpeed and offSpeed > 0 then
		value = format("%.2f / %.2f", mainSpeed or 0, offSpeed)
	else
		value = format("%.2f", mainSpeed or 0)
	end

	return SetSimpleStat(frame, _G.STAT_ATTACK_SPEED or "Attack Speed", value)
end

local function UpdateMeleeAttackPowerStat(frame)
	local base, posBuff, negBuff = UnitAttackPower("player")
	local effective = (base or 0) + (posBuff or 0) + (negBuff or 0)
	return SetSimpleStat(frame, _G.ATTACK_POWER or "Attack Power", FormatNumber(effective))
end

local function UpdateMeleeHitStat(frame)
	if not GetHitModifier then
		return SetSimpleStat(frame, _G.MELEE_HIT_CHANCE or "Hit Chance", "N/A")
	end

	local hit = GetHitModifier("player") or 0
	return SetSimpleStat(frame, _G.MELEE_HIT_CHANCE or "Hit Chance", format("%.2f%%", hit))
end

local function UpdateMeleeCritStat(frame)
	local value = GetCritChance and GetCritChance() or 0
	return SetSimpleStat(frame, _G.MELEE_CRIT_CHANCE or "Melee Crit", format("%.2f%%", value))
end

local function UpdateSpellPowerStat(frame)
	local bonus = 0

	if GetSpellBonusDamage then
		for school = 2, 7 do
			local schoolBonus = GetSpellBonusDamage(school)
			if schoolBonus then
				bonus = max(bonus, schoolBonus)
			end
		end
	end

	return SetSimpleStat(frame, _G.STAT_SPELLPOWER or "Spell Power", FormatNumber(bonus))
end

local function UpdateSpellHealingStat(frame)
	local bonus = GetSpellBonusHealing and GetSpellBonusHealing() or 0
	return SetSimpleStat(frame, _G.HEALING_POWER or "Healing Power", FormatNumber(bonus))
end

local function UpdateSpellCritStat(frame)
	local total = 0
	local count = 0

	if GetSpellCritChance then
		for school = 2, 7 do
			local crit = GetSpellCritChance(school)
			if crit then
				total = total + crit
				count = count + 1
			end
		end
	end

	local value = count > 0 and (total / count) or 0
	return SetSimpleStat(frame, _G.SPELL_CRIT_CHANCE or "Spell Crit", format("%.2f%%", value))
end

local function UpdateSpellRegenStat(frame)
	if not GetManaRegen then
		return SetSimpleStat(frame, _G.MANA_REGEN or "Mana Regen", "N/A")
	end

	local base, casting = GetManaRegen()
	base = base or 0
	casting = casting or 0

	local value = format("%.1f / %.1f", casting * 5, base * 5)
	return SetSimpleStat(frame, _G.MANA_REGEN or "Mana Regen (per 5s)", value)
end

local function UpdateSpellHitStat(frame)
	if not GetSpellHitModifier then
		return SetSimpleStat(frame, _G.SPELL_HIT or "Spell Hit", "0%")
	end

	local hit = GetSpellHitModifier()
	hit = hit or 0
	return SetSimpleStat(frame, _G.SPELL_HIT or "Spell Hit", format("%.2f%%", hit))
end

local function UpdateRangedDamageStat(frame)
	local speed, minDamage, maxDamage, physicalBonusPos, physicalBonusNeg, percent = UnitRangedDamage("player")

	if not speed or speed == 0 then
		return SetSimpleStat(frame, _G.RANGED_DAMAGE or "Ranged Damage", "N/A")
	end

	minDamage = minDamage or 0
	maxDamage = maxDamage or 0
	physicalBonusPos = physicalBonusPos or 0
	physicalBonusNeg = physicalBonusNeg or 0
	percent = percent or 1

	local damageSpread = format("%d - %d", max(floor(minDamage), 1), max(ceil(maxDamage), 1))
	local baseDamage = (minDamage + maxDamage) * 0.5
	local fullDamage = (baseDamage + physicalBonusPos + physicalBonusNeg) * percent
	local dps = fullDamage / speed
	local tooltip = format("%s: %.2f\n%s: %.2f", _G.WEAPON_SPEED or "Speed", speed, _G.DAMAGE_PER_SECOND or "DPS", dps)

	return SetSimpleStat(frame, _G.RANGED_DAMAGE or "Ranged Damage", damageSpread, tooltip)
end

local function UpdateRangedSpeedStat(frame)
	local speed = select(1, UnitRangedDamage("player"))

	if not speed or speed == 0 then
		return SetSimpleStat(frame, _G.RANGED_ATTACK_SPEED or "Ranged Speed", "N/A")
	end

	return SetSimpleStat(frame, _G.RANGED_ATTACK_SPEED or "Ranged Speed", format("%.2f", speed))
end

local function UpdateRangedAttackPowerStat(frame)
	if not UnitRangedAttackPower then
		return SetSimpleStat(frame, _G.RANGED_ATTACK_POWER or "Ranged Attack Power", "N/A")
	end

	local base, posBuff, negBuff = UnitRangedAttackPower("player")
	local effective = (base or 0) + (posBuff or 0) + (negBuff or 0)

	return SetSimpleStat(frame, _G.RANGED_ATTACK_POWER or "Ranged Attack Power", FormatNumber(effective))
end

local function UpdateRangedCritStat(frame)
	if not GetRangedCritChance then
		return SetSimpleStat(frame, _G.RANGED_CRIT_CHANCE or "Ranged Crit", "0%")
	end

	local value = GetRangedCritChance()
	return SetSimpleStat(frame, _G.RANGED_CRIT_CHANCE or "Ranged Crit", format("%.2f%%", value or 0))
end

local STAT_GROUPS = {
	{
		key = "attributes",
		label = _G.PLAYERSTAT_BASE_STATS or _G.STAT_CATEGORY_ATTRIBUTES or "Attributes",
		stats = {
			{ key = "strength", label = PRIMARY_STAT_LABELS[1] or (_G.STRENGTH or "Strength"), updater = function(frame) return UpdatePrimaryStat(frame, 1) end },
			{ key = "agility", label = PRIMARY_STAT_LABELS[2] or (_G.AGILITY or "Agility"), updater = function(frame) return UpdatePrimaryStat(frame, 2) end },
			{ key = "stamina", label = PRIMARY_STAT_LABELS[3] or (_G.STAMINA or "Stamina"), updater = function(frame) return UpdatePrimaryStat(frame, 3) end },
			{ key = "intellect", label = PRIMARY_STAT_LABELS[4] or (_G.INTELLECT or "Intellect"), updater = function(frame) return UpdatePrimaryStat(frame, 4) end },
			{ key = "spirit", label = PRIMARY_STAT_LABELS[5] or (_G.SPIRIT or "Spirit"), updater = function(frame) return UpdatePrimaryStat(frame, 5) end },
			{ key = "armor", label = _G.ARMOR or "Armor", updater = UpdateArmorStat },
		},
	},
	{
		key = "defense",
		label = _G.PLAYERSTAT_DEFENSES or _G.STAT_CATEGORY_DEFENSE or "Defense",
		stats = {
			{ key = "defense", label = _G.DEFENSE or "Defense", updater = UpdateDefenseStat },
			{ key = "dodge", label = _G.DODGE or "Dodge", updater = UpdateDodgeStat },
			{ key = "parry", label = _G.PARRY or "Parry", updater = UpdateParryStat },
			{ key = "block", label = _G.BLOCK or "Block", updater = UpdateBlockStat },
		},
	},
	{
		key = "melee",
		label = _G.PLAYERSTAT_MELEE_COMBAT or _G.MELEE or "Melee",
	stats = {
		{ key = "meleeDamage", label = _G.DAMAGE or "Damage", updater = UpdateMeleeDamageStat },
		{ key = "meleeSpeed", label = _G.STAT_ATTACK_SPEED or "Attack Speed", updater = UpdateMeleeSpeedStat },
		{ key = "meleePower", label = _G.ATTACK_POWER or "Attack Power", updater = UpdateMeleeAttackPowerStat },
		{ key = "meleeHit", label = _G.MELEE_HIT_CHANCE or "Melee Hit", updater = UpdateMeleeHitStat },
		{ key = "meleeCrit", label = _G.MELEE_CRIT_CHANCE or "Melee Crit", updater = UpdateMeleeCritStat },
	},
	},
	{
		key = "spell",
		label = _G.PLAYERSTAT_SPELL_COMBAT or _G.SPELL or "Spell",
		stats = {
			{ key = "spellPower", label = _G.STAT_SPELLPOWER or "Spell Power", updater = UpdateSpellPowerStat },
			{ key = "spellHealing", label = _G.HEALING_POWER or "Healing Power", updater = UpdateSpellHealingStat },
			{ key = "spellCrit", label = _G.SPELL_CRIT_CHANCE or "Spell Crit", updater = UpdateSpellCritStat },
			{ key = "spellRegen", label = _G.MANA_REGEN or "Mana Regen", updater = UpdateSpellRegenStat },
			{ key = "spellHit", label = _G.SPELL_HIT or "Spell Hit", updater = UpdateSpellHitStat },
		},
	},
	{
		key = "ranged",
		label = _G.PLAYERSTAT_RANGED_COMBAT or _G.RANGED or "Ranged",
		stats = {
			{ key = "rangedDamage", label = _G.RANGED_DAMAGE or "Ranged Damage", updater = UpdateRangedDamageStat },
			{ key = "rangedSpeed", label = _G.RANGED_ATTACK_SPEED or "Ranged Speed", updater = UpdateRangedSpeedStat },
		{ key = "rangedPower", label = _G.RANGED_ATTACK_POWER or "Ranged Attack Power", updater = UpdateRangedAttackPowerStat },
		{ key = "rangedCrit", label = _G.RANGED_CRIT_CHANCE or "Ranged Crit", updater = UpdateRangedCritStat },
		},
	},
}

local DEFAULT_STAT_VISIBILITY = {}
for _, group in ipairs(STAT_GROUPS) do
	for _, statInfo in ipairs(group.stats) do
		DEFAULT_STAT_VISIBILITY[statInfo.key] = true
	end
end


local function BuildCategories()
	if #categories > 0 then
		return
	end

	local previous
	for _, info in ipairs(STAT_GROUPS) do
		local container = CreateFrame("Frame", nil, scrollChild)
		container:SetWidth(PANEL_WIDTH)
		container.unit = "player"

		if not previous then
			container:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)
		else
			container:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -SECTION_SPACING)
		end

		local header = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		header:SetPoint("TOPLEFT", container, "TOPLEFT", 4, 0)
		header:SetPoint("TOPRIGHT", container, "TOPRIGHT", -4, 0)
		header:SetJustifyH("LEFT")
		header:SetText(info.label or "")
		info.header = header

		local stats = {}
		for index = 1, #info.stats do
			stats[index] = CreateStatRow(container, index)
		end

		info.container = container
		info.frames = stats
		info.visible = 0

		previous = container
		categories[#categories + 1] = info
	end
end

local function UpdateCategory(info, previous)
	local header = info.header
	local definitions = info.stats
	local frames = info.frames
	local visible = 0
	local sequence = module.visibleSequence

	for _, frame in ipairs(frames) do
		frame:Hide()
		frame.unit = "player"
		frame.onEnterFunc = nil
		frame.onLeaveFunc = nil
	end

	for index, statInfo in ipairs(definitions) do
		local frame = frames[index]
		if frame and statInfo and module:IsStatEnabled(statInfo.key) and statInfo.updater(frame) then
			if visible == 0 and sequence then
				sequence[#sequence + 1] = info.container
			end
			visible = visible + 1
			PositionStatRow(frame, header, visible)
			frame:SetScript("OnEnter", StatFrame_OnEnter)
			frame:SetScript("OnLeave", StatFrame_OnLeave)
			if sequence then
				sequence[#sequence + 1] = frame
			end
		else
			if frame then
				frame:Hide()
			end
		end
	end

	info.visible = visible

	if visible > 0 then
		info.container:Show()
		local height = HEADER_HEIGHT + (visible > 0 and ((visible * (LINE_HEIGHT + LINE_SPACING)) + 4) or 0)
		info.container:SetHeight(height)
		return info.container
	end

	info.container:Hide()
	return nil
end

local function UpdateStats()
	if not (statPanel and statPanel:IsShown()) then
		return
	end

	local sequence = module.visibleSequence or {}
	module.visibleSequence = sequence
	wipe(sequence)

	local previous
	local totalHeight = 0

	for _, info in ipairs(categories) do
		local updatedContainer = UpdateCategory(info, previous)
		if info.visible > 0 and info.container:IsShown() then
			local anchorFrame = previous or scrollChild
			info.container:ClearAllPoints()
			if anchorFrame == scrollChild then
				info.container:SetPoint("TOPLEFT", anchorFrame, "TOPLEFT", 0, 0)
			else
				info.container:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, -SECTION_SPACING)
			end

			totalHeight = totalHeight + info.container:GetHeight() + SECTION_SPACING
			previous = info.container
		else
			if updatedContainer then
				updatedContainer:Hide()
			end
			if info.container then
				info.container:Hide()
			end
		end
	end

	totalHeight = totalHeight + HEADER_HEIGHT
	scrollChild:SetHeight(totalHeight)

	if module.playFadeNext then
		module:PlayStatsFade()
		module.playFadeNext = nil
	end
end

local function SetPanelVisibility(isVisible)
	if isVisible then
		if not statPanel:IsShown() then
			statPanel:SetAlpha(0)
			statPanel:Show()
		end
		if UIFrameFadeIn then
			UIFrameFadeIn(statPanel, 0.3, statPanel:GetAlpha(), 1)
		else
			statPanel:SetAlpha(1)
		end
		UpdateStats()
	else
		statPanel:SetAlpha(0)
		statPanel:Hide()
	end
end

function module:PlayStatsFade()
	if not self.visibleSequence then
		return
	end

	local delay = 0
	local step = 0.06
	for _, frame in ipairs(self.visibleSequence) do
		if frame and frame.SetAlpha and frame:IsShown() then
			frame:SetAlpha(0)
			local target = frame
			C_Timer.After(delay, function()
				if target and target.SetAlpha and target:IsShown() then
					UIFrameFadeIn(target, 0.25, 0, 1)
				end
			end)
			delay = delay + step
		end
	end
end

function module:EnsureEnhancedStatsFilters()
	local db = E.db.mui.misc
	if db.missingStatsFilters and not db.enhancedStatsFilters then
		db.enhancedStatsFilters = {}
		for key, value in pairs(db.missingStatsFilters) do
			db.enhancedStatsFilters[key] = value
		end
		db.missingStatsFilters = nil
	end

	db.enhancedStatsFilters = db.enhancedStatsFilters or {}
	for key, default in pairs(DEFAULT_STAT_VISIBILITY) do
		if db.enhancedStatsFilters[key] == nil then
			db.enhancedStatsFilters[key] = default
		end
	end
end

function module:IsStatEnabled(statKey)
	if not statKey then
		return true
	end

	module:EnsureEnhancedStatsFilters()
	local filters = E.db.mui.misc.enhancedStatsFilters
	local value = filters and filters[statKey]
	if value == nil then
		return true
	end

	return value
end

function module:SetStatEnabled(statKey, value)
	module:EnsureEnhancedStatsFilters()
	E.db.mui.misc.enhancedStatsFilters[statKey] = value and true or false
	module.playFadeNext = true
	UpdateStats()
end

function module:GetEnhancedStatsOptionArgs()
	module:EnsureEnhancedStatsFilters()
	local args = {}
	local order = 1
	for _, group in ipairs(STAT_GROUPS) do
		args[group.key .. "Header"] = {
			order = order,
			type = "header",
			name = group.label,
		}
		order = order + 1

		for _, statInfo in ipairs(group.stats) do
			local statKey = statInfo.key
			local statLabel = statInfo.label or statInfo.key
			args[statKey] = {
				order = order,
				type = "toggle",
				name = statLabel,
				get = function()
					return module:IsStatEnabled(statKey)
				end,
				set = function(_, value)
					module:SetStatEnabled(statKey, value)
				end,
			}
			order = order + 1
		end
	end

	return args
end

local function CacheModelDefaults()
	if modelDefaults.cached then
		return
	end

	local model = _G.CharacterModelFrame
	if not model then
		return
	end

	local point, relativeTo, relativePoint, x, y = model:GetPoint(1)
	modelDefaults.cached = true
	modelDefaults.point = point
	modelDefaults.relativeTo = relativeTo and relativeTo:GetName()
	modelDefaults.relativePoint = relativePoint
	modelDefaults.x = x
	modelDefaults.y = y
	modelDefaults.width = model:GetWidth()
	modelDefaults.height = model:GetHeight()
end

local function RestoreModelDefaults()
	if not modelDefaults.cached then
		return
	end

	local model = _G.CharacterModelFrame
	if not model then
		return
	end

	local relative = modelDefaults.relativeTo and _G[modelDefaults.relativeTo] or _G.PaperDollFrame
	model:ClearAllPoints()
	model:SetPoint(modelDefaults.point, relative, modelDefaults.relativePoint, modelDefaults.x, modelDefaults.y)
	model:SetSize(modelDefaults.width, modelDefaults.height)
end

local function UpdateStatPanelLayout()
	if not statPanel then
		return
	end

	local model = _G.CharacterModelFrame
	local parent = model and model:IsShown() and model or _G.PaperDollFrame
	local handSlot = _G.CharacterHandsSlot
	local mainHandSlot = _G.CharacterMainHandSlot
	local offHandSlot = _G.CharacterSecondaryHandSlot
	local frame = _G.CharacterFrame
	if not frame then
		return
	end

	statPanel:ClearAllPoints()
	local outerPadX, outerPadY = 18, 12
	local extraHeight = 75

	local frameLeft = frame:IsShown() and frame:GetLeft()
	local frameRight = frame:IsShown() and frame:GetRight()
	if not (frameLeft and frameRight) then
		return
	end

	local gearRight = handSlot and handSlot:IsShown() and handSlot:GetRight() or nil
	if not gearRight and parent then
		gearRight = parent:GetRight()
	end
	gearRight = gearRight or (frameLeft + 220)

	local margin = 8
	local spaceLeft = gearRight + margin
	local spaceRight = frameRight - (outerPadX + 18)
	local maxWidth = spaceRight - spaceLeft
	if maxWidth < 80 then
		maxWidth = 80
	end

	local desiredWidth = math.min(PANEL_WIDTH + 40, maxWidth)
	local leftOffset = spaceLeft - frameLeft

	local topAnchorY = -(outerPadY + extraHeight) + 15
	local bottomAnchorY = outerPadY + extraHeight

	statPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", leftOffset, topAnchorY)
	statPanel:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", leftOffset, bottomAnchorY)
	statPanel:SetWidth(desiredWidth)

	local insetX = 12
	local insetY = 6
	local bottomInset = insetY

	if scrollFrame then
		scrollFrame:ClearAllPoints()
		scrollFrame:SetPoint("TOPLEFT", statPanel, "TOPLEFT", insetX, -insetY)
		scrollFrame:SetPoint("BOTTOMRIGHT", statPanel, "BOTTOMRIGHT", -(insetX + 4), bottomInset)
	end

	if scrollChild then
		local width = desiredWidth - 36
		scrollChild:SetWidth(width > 0 and width or 1)
	end
end

local function HandlePaperDollShow()
	if not statPanel then
		return
	end

	HideBlizzardStatsPane()

	BuildCategories()
	module.playFadeNext = true
	SetPanelVisibility(true)

	local CharacterFrame = _G.CharacterFrame
	if CharacterFrame and expandedWidth then
		CharacterFrame:SetWidth(expandedWidth)
	end

	RestoreModelDefaults()
	UpdateStatPanelLayout()
end

local function HandlePaperDollHide()
	if not statPanel then
		return
	end

	SetPanelVisibility(false)

	local CharacterFrame = _G.CharacterFrame
	if CharacterFrame and defaultWidth then
		CharacterFrame:SetWidth(defaultWidth)
	end
end

local function InitializePanel()
	if statPanel then
		return
	end

	local PaperDollFrame = _G.PaperDollFrame
	local CharacterFrame = _G.CharacterFrame
	if not (PaperDollFrame and CharacterFrame) then
		return
	end

	statPanel = CreateFrame("Frame", "MERClassicStatsPanel", CharacterFrame)
	local characterModel = _G.CharacterModelFrame
	CacheModelDefaults()

	statPanel:SetFrameStrata(PaperDollFrame:GetFrameStrata())
	statPanel:Hide()
	statPanel.unit = "player"

	if statPanel.SetTemplate then
		statPanel:SetTemplate("Transparent")
	end

	scrollFrame = CreateFrame("ScrollFrame", nil, statPanel, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", statPanel, "TOPLEFT", 0, -6)
	scrollFrame:SetPoint("BOTTOMRIGHT", statPanel, "BOTTOMRIGHT", -12, 6)

	if scrollFrame.ScrollBar then
		scrollFrame.ScrollBar:Hide()
		scrollFrame.ScrollBar.Show = E.noop
	end

	scrollChild = CreateFrame("Frame", nil, scrollFrame)
	scrollChild:SetSize(PANEL_WIDTH - 31, 1)
	scrollChild:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, 0)
	scrollFrame:SetScrollChild(scrollChild)
	scrollChild.unit = "player"

	defaultWidth = CharacterFrame:GetWidth()
	expandedWidth = defaultWidth + PANEL_WIDTH + 48

	UpdateStatPanelLayout()

	PaperDollFrame:HookScript("OnShow", HandlePaperDollShow)
	PaperDollFrame:HookScript("OnHide", HandlePaperDollHide)
end

function module:EnhancedStats()
	return
end

module:AddCallback("EnhancedStats")
