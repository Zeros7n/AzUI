local MER, F, E, L, V, P, G = unpack(ElvUI_AzUI)
local M = MER:GetModule('MER_Misc')
local IL = MER:GetModule('MER_ItemLevel')
local S = MER:GetModule('MER_Skins')

local wipe, gmatch, gsub, tinsert, ipairs, pairs, select = wipe, gmatch, gsub, tinsert, ipairs, pairs, select
local tonumber, tostring, strlower, strtrim, strfind = tonumber, tostring, strlower, strtrim, strfind
local format = format
local floor, ceil = floor, ceil
local max = max
local UIFrameFadeIn = UIFrameFadeIn
local C_Timer = _G.C_Timer
local type = type
local BreakUpLargeNumbers = BreakUpLargeNumbers
local NONE = _G.NONE or "N/A"

local UnitStat, UnitArmor, UnitDefense = UnitStat, UnitArmor, UnitDefense
local UnitDamage, UnitAttackSpeed, UnitAttackPower = UnitDamage, UnitAttackSpeed, UnitAttackPower
local GetCritChance, GetDodgeChance, GetParryChance = GetCritChance, GetDodgeChance, GetParryChance
local GetBlockChance, GetManaRegen = GetBlockChance, GetManaRegen
local GetSpellBonusDamage, GetSpellBonusHealing = GetSpellBonusDamage, GetSpellBonusHealing
local GetSpellCritChance, GetSpellHitModifier = GetSpellCritChance, GetSpellHitModifier
local GetHitModifier, GetRangedHitModifier = GetHitModifier, GetRangedHitModifier
local UnitRangedDamage, UnitRangedAttackPower = UnitRangedDamage, UnitRangedAttackPower
local GetRangedCritChance = GetRangedCritChance
local GetExpertise, GetExpertisePercent = GetExpertise, GetExpertisePercent
local GetCombatRatingBonus, GetCombatRating = GetCombatRatingBonus, GetCombatRating
local UnitSpellHaste = UnitSpellHaste

local PaperDollFrame = _G.PaperDollFrame
local CharacterFrame = _G.CharacterFrame
local CharacterNameText = _G.CharacterNameText
local EquipmentManager_EquipSet = EquipmentManager_EquipSet

local UpdateResistanceBar
local HookItemLevelUpdate

local ClassSymbolFrame
local playerILvlFrame
local hiddenParent = E.HiddenFrame or _G.UIParent
local resistanceHolder
local statLabelHooked
local statItemFrameHooked
local itemLevelHideHooked
local RESISTANCE_BAR_OFFSET_Y = 2 -- vertical offset from model
local CHARACTER_MODEL_POINT = "CENTER"
local CHARACTER_MODEL_REL_POINT = "CENTER"
local CHARACTER_MODEL_OFFSET_X = -15
local CHARACTER_MODEL_OFFSET_Y = 30
local hiddenStatLabels = {}
local DEFAULT_CHARACTER_FRAME_WIDTH
local conditionalStatLabels = {}
local statsFadeSequence = {}
local statsFadeQueued
local statsFadeArmed
local expandButtonNames = {
	"PaperDollFrameExpandButton",
	"CharacterFrameExpandButton",
}
local hideStatsToggleAttempts = 0

local function HideBlizzardExpandButton()
	for _, name in ipairs(expandButtonNames) do
		local button = _G[name]
		if button then
			button:Hide()
			button.Show = E.noop
			button:SetScript("OnClick", nil)
			button:SetScript("OnEnter", nil)
			button:SetScript("OnLeave", nil)
			button:SetAlpha(0)
			button:SetScale(0.0001)
			button:EnableMouse(false)
			if not button.__MERArmoryExpandHooked then
				button:HookScript("OnShow", HideBlizzardExpandButton)
				button.__MERArmoryExpandHooked = true
			end
		end
	end
end

local function HideExternalStatsToggleButton()
	local parent = _G.PaperDollFrame or PaperDollFrame
	if not parent or not parent.GetChildren then
		return
	end

	local found
	for i = 1, parent:GetNumChildren() do
		local child = select(i, parent:GetChildren())
		if child and child.GetObjectType and child:GetObjectType() == "Button" and child.GetNormalTexture then
			local texture = child:GetNormalTexture()
			local path = texture and texture.GetTexture and texture:GetTexture()
			if path and strfind(path, "UI%-RotationRight%-Big%-Up") then
				child:Hide()
				child.Show = E.noop
				child:SetAlpha(0)
				child:SetScale(0.0001)
				child:EnableMouse(false)
				child:SetScript("OnClick", nil)
				child:SetScript("OnEnter", nil)
				child:SetScript("OnLeave", nil)
				found = true
			end
		end
	end

	if not found and C_Timer and C_Timer.After and hideStatsToggleAttempts < 10 then
		hideStatsToggleAttempts = hideStatsToggleAttempts + 1
		C_Timer.After(0.3, HideExternalStatsToggleButton)
	else
		hideStatsToggleAttempts = 0
	end
end

local function NormalizeStatLabel(text)
	if not text or text == "" then
		return
	end

	text = gsub(text, "|c%x%x%x%x%x%x%x%x", "")
	text = gsub(text, "|r", "")
	text = gsub(text, "[:：]", "")
	text = strtrim(text)

	if text == "" then
		return
	end

	return strlower(text)
end

local function RegisterHiddenStatLabel(text)
	local cleaned = NormalizeStatLabel(text)
	if cleaned then
		hiddenStatLabels[cleaned] = true
	end
end

local function RegisterConditionalStatLabel(text)
	local cleaned = NormalizeStatLabel(text)
	if cleaned then
		conditionalStatLabels[cleaned] = true
	end
end

RegisterHiddenStatLabel(_G.STAT_AVERAGE_ITEM_LEVEL)
RegisterHiddenStatLabel(_G.COMBAT_RATING_TOTAL or _G.PAPERDOLLFRAME_TOTAL_RATING or _G.TOTAL)

local TOTAL_SCORE_LABELS = {
	"Total Score",
	L and L["Total Score"],
	_G.TOTAL_SCORE,
	_G.PAPERDOLLFRAME_TOTAL_RATING,
}
for _, label in ipairs(TOTAL_SCORE_LABELS) do
	if label then
		RegisterConditionalStatLabel(label)
	end
end

local function HideItemLevelFrame(frame)
	if not frame or frame.MERArmoryHidden then
		return
	end

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
	frame.MERArmoryHidden = true
end

local function ShouldHideStatLabel(text)
	local cleaned = NormalizeStatLabel(text)
	if not cleaned then
		return
	end

	if hiddenStatLabels[cleaned] then
		return true, true
	end

	if conditionalStatLabels[cleaned] and E.db.general.itemLevel.hideBlizzardItemScore then
		return true, false
	end
end

local function HideStatFrameIfNeeded(frame)
	if not frame then
		return
	end

	local label = frame.Label or frame.Text or frame.Title
	local labelText = label and label.GetText and label:GetText()
	if labelText then
		local shouldHide, permanent = ShouldHideStatLabel(labelText)
		if shouldHide and permanent then
			HideItemLevelFrame(frame)
		end
	end
end

local function ForEachPoolObject(pool, callback)
	if not pool or not callback then
		return
	end

	if pool.ForEachActiveObject then
		pool:ForEachActiveObject(callback)
		return
	end

	if pool.activeObjects then
		for frame in pairs(pool.activeObjects) do
			callback(frame)
		end
		return
	end

	if pool.EnumerateActive then
		local frame = pool:EnumerateActive()
		while frame do
			callback(frame)
			frame = pool:EnumerateActive(frame)
		end
	end
end

local function HideItemLevelFramesFromPool(pool)
	ForEachPoolObject(pool, HideStatFrameIfNeeded)
end

local function HideItemLevelFramesFromTable(tbl)
	if not tbl then
		return
	end

	for _, frame in pairs(tbl) do
		HideStatFrameIfNeeded(frame)
	end
end

local function HideMatchingFontStrings(frame)
	if not frame or not frame.GetRegions then
		return
	end

	for i = 1, frame:GetNumRegions() do
		local region = select(i, frame:GetRegions())
		if region and region.GetObjectType and region:GetObjectType() == "FontString" then
			local text = region.GetText and region:GetText()
			if text then
				local shouldHide, permanent = ShouldHideStatLabel(text)
				if shouldHide then
					if permanent then
						region:SetText("")
						region:Hide()
						region.Show = E.noop
					else
						region:Hide()
					end
				end
			end
		end
	end
end

local function DisableStatItemLevelByLabel(statFrame, label)
	if label ~= _G.STAT_AVERAGE_ITEM_LEVEL then
		return
	end

	HideItemLevelFrame(statFrame)
end

local function DisableStatItemLevelByFrame(statFrame)
	HideItemLevelFrame(statFrame)
end

local function EnsureStatItemLevelHook()
	if not statLabelHooked and _G.PaperDollFrame_SetLabelAndText then
		hooksecurefunc("PaperDollFrame_SetLabelAndText", DisableStatItemLevelByLabel)
		statLabelHooked = true
	end

	if not statItemFrameHooked and _G.PaperDollFrame_SetItemLevel then
		hooksecurefunc("PaperDollFrame_SetItemLevel", DisableStatItemLevelByFrame)
		statItemFrameHooked = true
	end
end

local function HideCharacterItemLevel()
	local statsPane = _G.CharacterStatsPane
	if statsPane then
		HideItemLevelFrame(statsPane.ItemLevelFrame)
		HideItemLevelFrame(statsPane.ItemLevelCategory)
	end

	local paperDoll = _G.PaperDollFrame
	if paperDoll then
		HideItemLevelFrame(paperDoll.ItemLevelFrame)
		HideItemLevelFrame(paperDoll.ItemLevelCategory)
	end

	EnsureStatItemLevelHook()
	HookItemLevelUpdate()
end

local function HideCharacterItemLevelFrames()
	HideCharacterItemLevel()

	local statsPane = _G.CharacterStatsPane
	if statsPane then
		if statsPane.ItemLevelFrame then
			statsPane.ItemLevelFrame:Hide()
			HideMatchingFontStrings(statsPane.ItemLevelFrame)
		end
		HideMatchingFontStrings(statsPane)
		HideItemLevelFramesFromPool(statsPane.statsFramePool)
		HideItemLevelFramesFromTable(statsPane.stats)
	end

	if PaperDollFrame and PaperDollFrame.ItemLevelFrame then
		PaperDollFrame.ItemLevelFrame:Hide()
		HideMatchingFontStrings(PaperDollFrame.ItemLevelFrame)
	end

	if PaperDollFrame then
		HideItemLevelFramesFromPool(PaperDollFrame.statsFramePool)
		HideMatchingFontStrings(PaperDollFrame)
	end
	HideMatchingFontStrings(CharacterFrame)
end

	HookItemLevelUpdate = function()
		if itemLevelHideHooked or not _G.PaperDollFrame_UpdateStats then
			return
	end

	hooksecurefunc("PaperDollFrame_UpdateStats", HideCharacterItemLevelFrames)
	itemLevelHideHooked = true
end

local function SuppressStatsPanel()
	local frames = {
		_G.CharacterStatsPane,
		_G.CharacterAttributesFrame,
	}

	for _, frame in ipairs(frames) do
		if frame and not frame.MERSuppressed then
			frame:EnableMouse(false)
			frame:ClearAllPoints()
			frame:SetParent(hiddenParent)
			frame:SetPoint("CENTER", hiddenParent, "CENTER")
			frame:SetScale(0.0001)
			frame:SetAlpha(0)
			frame:Hide()
			frame.Show = E.noop
			frame.Hide = E.noop
			frame.MERSuppressed = true
		end
	end

	HideCharacterItemLevelFrames()
end

local function FormatStatNumber(value)
	if type(value) ~= "number" then
		return value or ""
	end

	if BreakUpLargeNumbers and floor(value) == value then
		return BreakUpLargeNumbers(value)
	end

	return format("%.0f", value)
end

local function StatFrame_OnEnter(frame)
	if frame.onEnterFunc then
		frame.onEnterFunc(frame)
		return
	end

	if not (frame.tooltip or frame.tooltip2) then
		return
	end

	local tooltip = _G.GameTooltip
	if not tooltip then
		return
	end

	tooltip:SetOwner(frame, "ANCHOR_RIGHT")
	if frame.tooltip then
		tooltip:SetText(frame.tooltip, nil, nil, nil, nil, true)
	end

	if frame.tooltip2 then
		tooltip:AddLine(frame.tooltip2, nil, nil, nil, true)
	end

	tooltip:Show()
end

local function StatFrame_OnLeave(frame)
	if frame.onLeaveFunc then
		frame.onLeaveFunc(frame)
		return
	end

	local tooltip = _G.GameTooltip
	if tooltip and tooltip.Hide then
		tooltip:Hide()
	end
end

local function SetSimpleStat(frame, label, value, tooltip, tooltip2)
	if not frame then
		return
	end

	local labelFS = frame.Label or frame.Text or frame.Title
	if not labelFS then
		labelFS = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		labelFS:SetPoint("LEFT", frame, "LEFT", 4, 0)
		labelFS:SetJustifyH("LEFT")
		frame.Label = labelFS
		frame.Text = labelFS
	end

	local valueFS = frame.Value or frame.ValueText or frame.TextValue
	if not valueFS then
		valueFS = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		valueFS:SetPoint("RIGHT", frame, "RIGHT", -4, 0)
		valueFS:SetJustifyH("RIGHT")
		frame.Value = valueFS
		frame.ValueText = valueFS
	end

	if labelFS then
		labelFS:SetText(label or "")
	end

	if valueFS then
		valueFS:SetText(value or "")
	end

	frame.tooltip = tooltip
	frame.tooltip2 = tooltip2
	frame.onEnterFunc = nil
	frame.onLeaveFunc = nil

	if not frame.__MERArmoryTooltip then
		frame:EnableMouse(true)
		frame:SetScript("OnEnter", StatFrame_OnEnter)
		frame:SetScript("OnLeave", StatFrame_OnLeave)
		frame.__MERArmoryTooltip = true
	end

	frame:Show()

	return true
end

local function ResetStatsFadeSequence()
	wipe(statsFadeSequence)
end

local function AddCategoryFrameToFade(frame)
	if frame then
		statsFadeSequence[#statsFadeSequence + 1] = frame
	end
end

local function QueueStatsFade()
	statsFadeQueued = true
	statsFadeArmed = true
end

local function PlayStatsFade()
	if not statsFadeQueued or not statsFadeArmed or not UIFrameFadeIn then
		return
	end

	statsFadeQueued = false
	statsFadeArmed = false

	local delay = 0
	local step = 0.06
	for _, fadeFrame in ipairs(statsFadeSequence) do
		if fadeFrame and fadeFrame.SetAlpha and fadeFrame:IsShown() then
			fadeFrame:SetAlpha(0)
			local target = fadeFrame
			C_Timer.After(delay, function()
				if target and target.SetAlpha and target:IsShown() then
					UIFrameFadeIn(target, 0.25, 0, 1)
				end
			end)
			delay = delay + step
		end
	end
end

local function ApplyStatUpdate(frame, updater, ...)
	if not frame or not updater then
		return
	end

	if not updater(frame, ...) then
		frame:Hide()
	end
end

local PRIMARY_STAT_LABELS = {
	_G.SPELL_STAT1_NAME or _G.STRENGTH or "Strength",
	_G.SPELL_STAT2_NAME or _G.AGILITY or "Agility",
	_G.SPELL_STAT3_NAME or _G.STAMINA or "Stamina",
	_G.SPELL_STAT4_NAME or _G.INTELLECT or "Intellect",
	_G.SPELL_STAT5_NAME or _G.SPIRIT or "Spirit",
}

local function UpdatePrimaryStat(frame, index)
	local label = PRIMARY_STAT_LABELS[index] or format("Stat %d", index)
	local _, effective, posBuff, negBuff = UnitStat("player", index)
	local value = FormatStatNumber(effective or 0)

	if (posBuff and posBuff ~= 0) or (negBuff and negBuff ~= 0) then
		local baseValue = (effective or 0) - (posBuff or 0) - (negBuff or 0)
		value = format("%s (%s)", value, FormatStatNumber(baseValue))
	end

	return SetSimpleStat(frame, label, value)
end

local function UpdateArmorStat(frame)
	local _, effectiveArmor, _, posBuff, negBuff = UnitArmor("player")
	local value = FormatStatNumber(effectiveArmor or 0)

	if (posBuff and posBuff ~= 0) or (negBuff and negBuff ~= 0) then
		local baseValue = (effectiveArmor or 0) - (posBuff or 0) - (negBuff or 0)
		value = format("%s (%s)", value, FormatStatNumber(baseValue))
	end

	return SetSimpleStat(frame, _G.ARMOR or "Armor", value)
end

local function UpdateDefenseStat(frame)
	local base, effective = UnitDefense("player")
	return SetSimpleStat(frame, _G.DEFENSE or "Defense", FormatStatNumber(effective or base or 0))
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

local function UpdateResilienceStat(frame)
	local label = _G.STAT_RESILIENCE or _G.RESILIENCE or "Resilience"
	local rating

	if GetCombatRatingBonus then
		if _G.CR_RESILIENCE then
			rating = GetCombatRatingBonus(_G.CR_RESILIENCE)
		elseif _G.CR_CRIT_TAKEN_MELEE then
			rating = GetCombatRatingBonus(_G.CR_CRIT_TAKEN_MELEE)
		end
	end

	if rating == nil then
		return SetSimpleStat(frame, label, NONE)
	end

	return SetSimpleStat(frame, label, format("%.2f%%", rating))
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
	local tooltip

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
	return SetSimpleStat(frame, _G.ATTACK_POWER or "Attack Power", FormatStatNumber(effective))
end

local function UpdateMeleeHitStat(frame)
	local label = _G.MELEE_HIT_CHANCE or _G.MELEE_HIT or "Hit Chance"
	local hit

	if GetHitModifier then
		hit = GetHitModifier("player")
	end

	if hit == nil and GetCombatRatingBonus and _G.CR_HIT_MELEE then
		hit = GetCombatRatingBonus(_G.CR_HIT_MELEE)
	end

	if hit == nil then
		return SetSimpleStat(frame, label, NONE)
	end

	return SetSimpleStat(frame, label, format("%.2f%%", hit))
end

local function UpdateMeleeCritStat(frame)
	local value = GetCritChance and GetCritChance() or 0
	return SetSimpleStat(frame, _G.MELEE_CRIT_CHANCE or "Melee Crit", format("%.2f%%", value))
end

local function UpdateMeleeExpertiseStat(frame)
	local label = _G.STAT_EXPERTISE or _G.EXPERTISE or "Expertise"

	if not (GetExpertise and GetExpertisePercent) then
		return SetSimpleStat(frame, label, NONE)
	end

	local main, offhand = GetExpertise()
	main = main or 0
	offhand = offhand or main

	local value
	if offhand and offhand ~= main then
		value = format("%s / %s", FormatStatNumber(main), FormatStatNumber(offhand))
	else
		value = FormatStatNumber(main)
	end

	local mainPercent, offhandPercent = GetExpertisePercent()
	local tooltip

	if mainPercent then
		if offhandPercent and offhandPercent ~= mainPercent then
			tooltip = format("%s: %.2f%% / %.2f%%", _G.MAINHANDSPEED or label, mainPercent, offhandPercent or mainPercent)
		else
			tooltip = format("%s: %.2f%%", label, mainPercent)
		end
	end

	return SetSimpleStat(frame, label, value, tooltip)
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

	return SetSimpleStat(frame, _G.STAT_SPELLPOWER or "Spell Power", FormatStatNumber(bonus))
end

local function UpdateSpellHealingStat(frame)
	local bonus = GetSpellBonusHealing and GetSpellBonusHealing() or 0
	return SetSimpleStat(frame, _G.HEALING_POWER or "Healing Power", FormatStatNumber(bonus))
end

local function UpdateSpellHitStat(frame)
	local label = _G.SPELL_HIT or _G.SPELL_HIT_CHANCE or "Spell Hit"
	local hit

	if GetSpellHitModifier then
		hit = GetSpellHitModifier()
	end

	if hit == nil and GetCombatRatingBonus and _G.CR_HIT_SPELL then
		hit = GetCombatRatingBonus(_G.CR_HIT_SPELL)
	end

	if hit == nil then
		return SetSimpleStat(frame, label, NONE)
	end

	return SetSimpleStat(frame, label, format("%.2f%%", hit))
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

local function UpdateSpellHasteStat(frame)
	local label = _G.SPELL_HASTE or _G.STAT_SPELLHASTE or "Spell Haste"
	local haste

	if UnitSpellHaste then
		haste = UnitSpellHaste("player")
	elseif GetCombatRatingBonus and _G.CR_HASTE_SPELL then
		haste = GetCombatRatingBonus(_G.CR_HASTE_SPELL)
	end

	if haste == nil then
		return SetSimpleStat(frame, label, NONE)
	end

	return SetSimpleStat(frame, label, format("%.2f%%", haste))
end

local function UpdateSpellRegenStat(frame)
	if not GetManaRegen then
		return SetSimpleStat(frame, _G.MANA_REGEN or "Mana Regen", NONE)
	end

	local base, casting = GetManaRegen()
	base = base or 0
	casting = casting or 0

	local value = format("%.1f / %.1f", casting * 5, base * 5)
	return SetSimpleStat(frame, _G.MANA_REGEN or "Mana Regen (per 5s)", value)
end

local function UpdateRangedDamageStat(frame)
	local speed, minDamage, maxDamage, physicalBonusPos, physicalBonusNeg, percent = UnitRangedDamage("player")

	if not speed or speed == 0 then
		return SetSimpleStat(frame, _G.RANGED_DAMAGE or "Ranged Damage", NONE)
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
		return SetSimpleStat(frame, _G.RANGED_ATTACK_SPEED or "Ranged Speed", NONE)
	end

	return SetSimpleStat(frame, _G.RANGED_ATTACK_SPEED or "Ranged Speed", format("%.2f", speed))
end

local function UpdateRangedAttackPowerStat(frame)
	if not UnitRangedAttackPower then
		return SetSimpleStat(frame, _G.RANGED_ATTACK_POWER or "Ranged Attack Power", NONE)
	end

	local base, posBuff, negBuff = UnitRangedAttackPower("player")
	local effective = (base or 0) + (posBuff or 0) + (negBuff or 0)

	return SetSimpleStat(frame, _G.RANGED_ATTACK_POWER or "Ranged Attack Power", FormatStatNumber(effective))
end

local function UpdateRangedHitStat(frame)
	local label = _G.RANGED_HIT_CHANCE or "Ranged Hit"
	local hit

	if GetRangedHitModifier then
		hit = GetRangedHitModifier()
	elseif GetHitModifier then
		hit = GetHitModifier("player")
	end

	if hit == nil and GetCombatRatingBonus and _G.CR_HIT_RANGED then
		hit = GetCombatRatingBonus(_G.CR_HIT_RANGED)
	end

	if hit == nil then
		return SetSimpleStat(frame, label, NONE)
	end

	return SetSimpleStat(frame, label, format("%.2f%%", hit))
end

local function UpdateRangedCritStat(frame)
	if not GetRangedCritChance then
		return SetSimpleStat(frame, _G.RANGED_CRIT_CHANCE or "Ranged Crit", NONE)
	end

	local value = GetRangedCritChance()
	return SetSimpleStat(frame, _G.RANGED_CRIT_CHANCE or "Ranged Crit", format("%.2f%%", value or 0))
end

local function SetCharacterStats(statsTable, category)
	if not statsTable then
		return
	end

	if category == "PLAYERSTAT_BASE_STATS" then
		ApplyStatUpdate(statsTable[1], UpdatePrimaryStat, 1)
		ApplyStatUpdate(statsTable[2], UpdatePrimaryStat, 2)
		ApplyStatUpdate(statsTable[3], UpdatePrimaryStat, 3)
		ApplyStatUpdate(statsTable[4], UpdatePrimaryStat, 4)
		ApplyStatUpdate(statsTable[5], UpdatePrimaryStat, 5)
		ApplyStatUpdate(statsTable[6], UpdateArmorStat)
	elseif category == "PLAYERSTAT_DEFENSES" then
		ApplyStatUpdate(statsTable[1], UpdateArmorStat)
		ApplyStatUpdate(statsTable[2], UpdateDefenseStat)
		ApplyStatUpdate(statsTable[3], UpdateDodgeStat)
		ApplyStatUpdate(statsTable[4], UpdateParryStat)
		ApplyStatUpdate(statsTable[5], UpdateBlockStat)
		ApplyStatUpdate(statsTable[6], UpdateResilienceStat)
	elseif category == "PLAYERSTAT_MELEE_COMBAT" then
		ApplyStatUpdate(statsTable[1], UpdateMeleeDamageStat)
		ApplyStatUpdate(statsTable[2], UpdateMeleeSpeedStat)
		ApplyStatUpdate(statsTable[3], UpdateMeleeAttackPowerStat)
		ApplyStatUpdate(statsTable[4], UpdateMeleeHitStat)
		ApplyStatUpdate(statsTable[5], UpdateMeleeCritStat)
		ApplyStatUpdate(statsTable[6], UpdateMeleeExpertiseStat)
	elseif category == "PLAYERSTAT_SPELL_COMBAT" then
		ApplyStatUpdate(statsTable[1], UpdateSpellPowerStat)
		ApplyStatUpdate(statsTable[2], UpdateSpellHealingStat)
		ApplyStatUpdate(statsTable[3], UpdateSpellHitStat)
		ApplyStatUpdate(statsTable[4], UpdateSpellCritStat)
		ApplyStatUpdate(statsTable[5], UpdateSpellHasteStat)
		ApplyStatUpdate(statsTable[6], UpdateSpellRegenStat)
	elseif category == "PLAYERSTAT_RANGED_COMBAT" then
		ApplyStatUpdate(statsTable[1], UpdateRangedDamageStat)
		ApplyStatUpdate(statsTable[2], UpdateRangedSpeedStat)
		ApplyStatUpdate(statsTable[3], UpdateRangedAttackPowerStat)
		ApplyStatUpdate(statsTable[4], UpdateRangedHitStat)
		ApplyStatUpdate(statsTable[5], UpdateRangedCritStat)
	end
end

local orderList = {}
local function BuildListFromValue()
	wipe(orderList)

	for number in gmatch(E.db.mui.armory.StatOrder, "%d") do
		tinsert(orderList, tonumber(number))
	end
end

local categoryFrames = {}
local framesToSort = {}
local function UpdateCategoriesOrder()
	wipe(framesToSort)

	for _, index in ipairs(orderList) do
		tinsert(framesToSort, categoryFrames[index])
	end
end

local function GetOrderedCategoryFrames()
	if #framesToSort == 0 then
		UpdateCategoriesOrder()
	end

	return framesToSort
end

local function UpdateCategoriesAnchor()
	UpdateCategoriesOrder()

	local prev
	for _, frame in pairs(framesToSort) do
		if not prev then
			frame:SetPoint("TOP", 0, -70)
		else
			frame:SetPoint("TOP", prev, "BOTTOM")
		end
		prev = frame
	end
end

local function BuildValueFromList()
	local str = ""
	for _, index in ipairs(orderList) do
		str = str..tostring(index)
	end
	E.db.mui.armory.StatOrder = str

	UpdateCategoriesAnchor()
end

local function Arrow_GoUp(bu)
	local frameIndex = bu.__owner.index

	BuildListFromValue()

	for order, index in pairs(orderList) do
		if index == frameIndex then
			if order > 1 then
				local oldIndex = orderList[order-1]
				orderList[order-1] = frameIndex
				orderList[order] = oldIndex

				BuildValueFromList()
			end
			break
		end
	end
end

local function Arrow_GoDown(bu)
	local frameIndex = bu.__owner.index

	BuildListFromValue()

	for order, index in pairs(orderList) do
		if index == frameIndex then
			if order < 5 then
				local oldIndex = orderList[order+1]
				orderList[order+1] = frameIndex
				orderList[order] = oldIndex

				BuildValueFromList()
			end
			break
		end
	end
end

local DEFAULT_STAT_PANEL_WIDTH = 200
local MIN_STAT_CONTENT_WIDTH = 160
local STAT_PANEL_PADDING = 20

local function GetStatPanelWidth()
	local panel = M.StatPanel2
	local width = panel and panel:GetWidth()
	if width and width > 0 then
		return width
	end
	return DEFAULT_STAT_PANEL_WIDTH
end

local function GetStatPanelContentWidth()
	local width = GetStatPanelWidth() - STAT_PANEL_PADDING
	if width < MIN_STAT_CONTENT_WIDTH then
		width = MIN_STAT_CONTENT_WIDTH
	end
	return width
end

local function CreateStatRow(parent, index)
	local frame = CreateFrame("Frame", "$parentRow"..index, parent, "StatFrameTemplate")
	frame:SetWidth(GetStatPanelContentWidth())
	frame:SetPoint("TOP", parent.header, "BOTTOM", 0, -2 - (index - 1) * 16)

	local background = frame:CreateTexture(nil, "BACKGROUND")
	background:SetAtlas("UI-Character-Info-Line-Bounce", true)
	background:SetAlpha(.3)
	background:SetPoint("CENTER")
	background:SetShown(index%2 == 0)
	frame.background = background

	return frame
end

local function CreateHeaderArrow(parent, direct, func)
	local onLeft = direct == "LEFT"
	local xOffset = onLeft and 10 or -10
	local arrowDirec = onLeft and "up" or "down"

	local bu = CreateFrame("Button", nil, parent)
	bu:SetPoint(direct, parent.header, xOffset, 0)

	local tex = bu:CreateTexture()
	tex:SetAllPoints()
	S:SetupArrow(tex, arrowDirec)
	bu.__texture = tex
	bu:SetScript("OnEnter", F.Texture_OnEnter)
	bu:SetScript("OnLeave", F.Texture_OnLeave)

	bu:SetSize(18, 18)
	bu.__owner = parent
	bu:SetScript("OnClick", func)
end

local function CreatePlayerILvl(parent, category)
	local frame = CreateFrame("Frame", "MER_StatCategoryIlvl", parent)
	frame:SetWidth(GetStatPanelWidth())
	frame:SetHeight(42 + 16)
	frame:SetPoint("TOP")

	local header = CreateFrame("Frame", "$parentHeader", frame, "CharacterStatFrameCategoryTemplate")
	header:SetPoint("TOP", 0, 10)
	header.Background:Hide()
	header.Title:FontTemplate(nil, 14)
	header.Title:SetText(E:TextGradient(category, F.ClassGradient[E.myclass]["r1"], F.ClassGradient[E.myclass]["g1"], F.ClassGradient[E.myclass]["b1"], F.ClassGradient[E.myclass]["r2"], F.ClassGradient[E.myclass]["g2"], F.ClassGradient[E.myclass]["b2"]))
	frame.header = header

	local line = frame:CreateTexture(nil, "ARTWORK")
	line:SetSize(GetStatPanelContentWidth(), E.mult)
	line:SetPoint("BOTTOM", header, 0, 5)
	line:SetColorTexture(1, 1, 1, .25)

	local iLvlFrame = CreateStatRow(frame, 1)
	iLvlFrame:SetHeight(30)
	iLvlFrame.background:Show()
	iLvlFrame.background:SetAtlas("UI-Character-Info-ItemLevel-Bounce", true)

	M.PlayerILvl = iLvlFrame:CreateFontString(nil, "OVERLAY")
	M.PlayerILvl:FontTemplate(nil, 20)
	M.PlayerILvl:SetAllPoints()
	playerILvlFrame = frame
end

function M:UpdatePlayerILvl()
	IL:UpdateUnitILvl("player", M.PlayerILvl)
end

local function CreateStatHeader(parent, index, category)
	local maxLines = index == 5 and 5 or 6
	local frame = CreateFrame("Frame", "MER_StatCategory"..index, parent)
	frame:SetWidth(GetStatPanelWidth())
	frame:SetHeight(42 + maxLines*16)
	frame.index = index
	tinsert(categoryFrames, frame)

	local header = CreateFrame("Frame", "$parentHeader", frame, "CharacterStatFrameCategoryTemplate")
	header:SetPoint("TOP")
	header.Background:Hide()
	header.Title:FontTemplate(nil, 14)
	header.Title:SetText(E:TextGradient(_G[category], F.ClassGradient[E.myclass]["r1"], F.ClassGradient[E.myclass]["g1"], F.ClassGradient[E.myclass]["b1"], F.ClassGradient[E.myclass]["r2"], F.ClassGradient[E.myclass]["g2"], F.ClassGradient[E.myclass]["b2"]))
	frame.header = header

	CreateHeaderArrow(frame, "LEFT", Arrow_GoUp)
	CreateHeaderArrow(frame, "RIGHT", Arrow_GoDown)

	local line = frame:CreateTexture(nil, "ARTWORK")
	line:SetSize(GetStatPanelContentWidth(), E.mult)
	line:SetPoint("BOTTOM", header, 0, 5)
	line:SetColorTexture(1, 1, 1, .25)

	local statsTable = {}
	for i = 1, maxLines do
		statsTable[i] = CreateStatRow(frame, i)
	end
	SetCharacterStats(statsTable, category)
	frame.category = category
	frame.statsTable = statsTable

	return frame
end

local function GetResistanceHolder()
	if not resistanceHolder then
		resistanceHolder = CreateFrame("Frame", "MER_CharacterResistanceHolder", PaperDollFrame)
		resistanceHolder:SetSize(1, 1)
	end

	return resistanceHolder
end

local function HasResistanceFrames()
	return _G.MagicResFrame1 ~= nil
end

local function AnchorResistanceHolder()
	if not HasResistanceFrames() then
		return
	end

	local holder = GetResistanceHolder()
	local anchor = (M.StatPanel2 and M.StatPanel2:IsShown()) and M.StatPanel2 or (_G.CharacterModelFrame or PaperDollFrame)

	holder:ClearAllPoints()
	holder:SetParent(PaperDollFrame)

	if anchor == M.StatPanel2 then
		holder:SetPoint("TOP", anchor, "TOP", -2, -13)
	else
		holder:SetPoint("BOTTOM", anchor, "TOP", 0, RESISTANCE_BAR_OFFSET_Y)
	end

	holder:SetFrameLevel((PaperDollFrame:GetFrameLevel() or 0) + 2)
	holder:Show()
end

local function LayoutMagicResistance()
	if not HasResistanceFrames() then
		return
	end

	AnchorResistanceHolder()

	local holder = GetResistanceHolder()
	local totalWidth = 0
	local spacing = 4
	local padding = 6
	local holderHeight = 0

	for i = 1, 5 do
		local bu = _G["MagicResFrame"..i]
		if not bu then
			return
		end

		bu:SetParent(holder)
		bu:ClearAllPoints()
		if i == 1 then
			bu:SetPoint("LEFT", holder, "LEFT", padding, 0)
		else
			bu:SetPoint("LEFT", _G["MagicResFrame"..(i-1)], "RIGHT", spacing, 0)
		end

		local width = bu:GetWidth() or 0
		local height = bu:GetHeight() or 0
		holderHeight = max(holderHeight, height)
		totalWidth = totalWidth + width
		if i > 1 then
			totalWidth = totalWidth + spacing
		end
	end

	holder:SetWidth(totalWidth > 0 and (totalWidth + padding * 2) or 1)
	holder:SetHeight(holderHeight > 0 and holderHeight or 1)

	if CharacterResistanceFrame and not CharacterResistanceFrame.MERArmoryHidden then
		HideItemLevelFrame(CharacterResistanceFrame)
	end
end

UpdateResistanceBar = function()
	if not HasResistanceFrames() then
		return
	end

	LayoutMagicResistance()
end

local function AnchorCharacterModelFrame()
	local frame = _G.CharacterModelFrame
	if not frame then
		return
	end

	frame:ClearAllPoints()
	local parentFrame = _G.PaperDollFrame or PaperDollFrame
	frame:SetPoint(CHARACTER_MODEL_POINT, parentFrame, CHARACTER_MODEL_REL_POINT, CHARACTER_MODEL_OFFSET_X, CHARACTER_MODEL_OFFSET_Y)

	if UpdateResistanceBar then
		UpdateResistanceBar()
	end
end

local function HideModelRotators()
	local leftButton = _G.CharacterModelFrameRotateLeftButton
	local rightButton = _G.CharacterModelFrameRotateRightButton

	if leftButton then
		leftButton:Hide()
		leftButton.Show = E.noop
	end

	if rightButton then
		rightButton:Hide()
		rightButton.Show = E.noop
	end
end

local function HookCharacterModelPosition()
	local frame = _G.CharacterModelFrame
	if not frame then
		return
	end

	AnchorCharacterModelFrame()
	HideModelRotators()

	if frame.MERArmoryAnchorHooked then
		return
	end

	hooksecurefunc(frame, "SetPoint", function(_, point, relativeTo, relativePoint, xOffset, yOffset)
		local parentFrame = _G.PaperDollFrame or PaperDollFrame
		if point ~= CHARACTER_MODEL_POINT or relativeTo ~= parentFrame or relativePoint ~= CHARACTER_MODEL_REL_POINT or xOffset ~= CHARACTER_MODEL_OFFSET_X or yOffset ~= CHARACTER_MODEL_OFFSET_Y then
			AnchorCharacterModelFrame()
			HideModelRotators()
		end
	end)
	frame.MERArmoryAnchorHooked = true
end

local function ToggleMagicRes()
	if not M.hasOtherAddon then
		CharacterModelFrame:SetSize(231, 320)
	end
	UpdateResistanceBar()
	AnchorCharacterModelFrame()
end

local function UpdateStats()
	if not (M.StatPanel2 and M.StatPanel2:IsShown()) then return end

	UpdateCategoriesOrder()
	ResetStatsFadeSequence()

	if playerILvlFrame and playerILvlFrame:IsShown() then
		AddCategoryFrameToFade(playerILvlFrame)
	end

	for _, frame in ipairs(GetOrderedCategoryFrames()) do
		if frame then
			SetCharacterStats(frame.statsTable, frame.category)
			AddCategoryFrameToFade(frame)
		end
	end

	if statsFadeArmed then
		statsFadeQueued = true
		PlayStatsFade()
	end
end

local statsUpdateQueued
local function QueueUpdateStats()
	if statsUpdateQueued then
		return
	end

	statsUpdateQueued = true
	if C_Timer and C_Timer.After then
		C_Timer.After(0.1, function()
			statsUpdateQueued = false
			UpdateStats()
		end)
	else
		statsUpdateQueued = false
		UpdateStats()
	end
end

local function OnPaperDollEvent(_, event, unit)
	if event and event:find("^UNIT_") and unit ~= "player" then
		return
	end

	QueueUpdateStats()
end

local function InitializeStatPanel()
	if not M.StatPanel2 then
		return
	end

	HideBlizzardExpandButton()

	CharacterAttributesFrame:Hide()
	if CharacterStatsPane then
		CharacterStatsPane:Hide()
	end

	M.StatPanel2:Show()
	QueueStatsFade()
	UpdateStats()
	ToggleMagicRes()
end

M.OtherPanels = {"DCS_StatScrollFrame", "CSC_SideStatsFrame"}
local found
function M:FindAddOnPanels()
	if not found then
		for _, name in pairs(M.OtherPanels) do
			if _G[name] then
				tinsert(PaperDollFrame.__statPanels, _G[name])
			end
		end
		if PaperDollFrame.inspectFrame then
			tinsert(PaperDollFrame.__statPanels, PaperDollFrame.inspectFrame)
		end
		found = true
	end

	M:SortAddOnPanels()
end

function M:SortAddOnPanels()
	local prev

	for _, frame in pairs(PaperDollFrame.__statPanels) do
		frame:ClearAllPoints()

		if not prev then
			if M.StatPanel2:IsShown() then
				frame:SetPoint("TOPLEFT", M.StatPanel2, "TOPRIGHT", 3, 0)
			else
				frame:SetPoint("TOPLEFT", PaperDollFrame, "TOPRIGHT", -32, -15-C.mult)
			end
		else
			frame:SetPoint("TOPLEFT", prev, "TOPRIGHT", 3, 0)
		end
		prev = frame
	end
end

function M:AddCharacterIcon()
	ClassSymbolFrame = ("|T" .. (MER.ClassIcons[E.myclass] .. ".tga:0:0:0:0|t"))

	E:Delay(0, function() -- otherwise it will just return "name"
		if not (CharacterNameText:GetText():match("|T")) then
			CharacterNameText:SetFont(E.LSM:Fetch('font', E.db.general.font), 16, E.db.general.fontStyle)
			CharacterNameText:SetShadowColor(0, 0, 0, 0.6)
			CharacterNameText:SetShadowOffset(2, -1)

			CharacterNameText:SetText(ClassSymbolFrame .. " " .. F.GradientName(CharacterNameText:GetText(), E.myclass))
		end
	end)
end

function M:SelectEquipSet()
	if InCombatLockdown() then UIErrorsFrame:AddMessage(MER.InfoColor .. ERR_NOT_IN_COMBAT) return end

	local dialog = _G.GearManagerDialog
	if not dialog then
		return
	end

	local selectedSet = dialog.selectedSet
	local name = selectedSet and selectedSet.id
	if name then
		PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
		EquipmentManager_EquipSet(name)
	end
end

function M:ExGearManager()
	local dialog = _G.GearManagerDialog

	if dialog then
		dialog.Title:SetJustifyH("LEFT")
		dialog.Title:SetPoint("TOPLEFT", 12, -12)
		dialog:SetFrameStrata("DIALOG")
		dialog:SetSize(339, 70)
		dialog:ClearAllPoints()
		dialog:SetPoint("BOTTOMLEFT", PaperDollFrame, "TOPLEFT", 10, -18)
	end

	local prevButton
	for i = 1, 10 do
		local button = _G["GearSetButton" .. i]
		if button then
			button:ClearAllPoints()
			button:SetSize(28, 28)
			if not prevButton then
				button:SetPoint("BOTTOMLEFT", 10, 10)
			else
				button:SetPoint("LEFT", prevButton, "RIGHT", 5, 0)
			end
			prevButton = button

			button:SetScript("OnDoubleClick", M.SelectEquipSet)
		end
	end

	local names = { "EquipSet", "DeleteSet", "SaveSet" }
	for i, name in pairs(names) do
		local button = _G["GearManagerDialog" .. name]
		if button then
			button:SetSize(60, 20)
			button:ClearAllPoints()
			button:SetPoint("TOPRIGHT", 35 - 62 * i, -9)
		end
	end
end

function M:Armory()
	if not E.db.mui.armory.character.enable or not (E.private.skins.blizzard.enable or E.private.skins.blizzard.character) then
		return
	end

	M.hasOtherAddon = IsAddOnLoaded("CharacterStatsTBC")

	local insetRight = _G.CharacterFrameInsetRight
	local statParent = insetRight or PaperDollFrame
	local statPanel = CreateFrame("Frame", "MER_StatPanel", statParent)
	if insetRight then
		statPanel:SetAllPoints(insetRight)
	else
		statPanel:SetSize(200, 424)
		statPanel:SetPoint("TOPLEFT", PaperDollFrame, "TOPRIGHT", -30, -12)
	end

	statPanel:SetFrameLevel((statParent:GetFrameLevel() or 0) + 1)
	statPanel:SetTemplate('Transparent')
	statPanel:Styling()
	S:CreateShadow(statPanel)
	M.StatPanel2 = statPanel
	SuppressStatsPanel()
	HookCharacterModelPosition()

	local scrollFrame = CreateFrame("ScrollFrame", nil, statPanel, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", 0, -45)

	scrollFrame:SetPoint("BOTTOMRIGHT", 0, 2)
	scrollFrame.ScrollBar:Hide()
	scrollFrame.ScrollBar.Show = E.noop

	local stat = CreateFrame("Frame", nil, scrollFrame)
	stat:SetSize(GetStatPanelWidth(), 1)
	statPanel.child = stat
	stat:ClearAllPoints()
	stat:SetPoint("TOP", scrollFrame, "TOP", 0, 0)
	scrollFrame:SetScrollChild(stat)
	scrollFrame:SetScript("OnMouseWheel", function(self, delta)
		local scrollBar = self.ScrollBar
		local step = delta*25
		if IsShiftKeyDown() then
			step = step*6
		end
		scrollBar:SetValue(scrollBar:GetValue() - step)
	end)

	-- Player iLvl
	CreatePlayerILvl(stat, _G.STAT_AVERAGE_ITEM_LEVEL)
	hooksecurefunc("PaperDollFrame_UpdateStats", M.UpdatePlayerILvl)
	hooksecurefunc("PaperDollFrame_UpdateStats", UpdateResistanceBar)
	hooksecurefunc("PaperDollFrame_UpdateStats", UpdateStats)

	-- Player stats
	local categories = {
		"PLAYERSTAT_BASE_STATS",
		"PLAYERSTAT_DEFENSES",
		"PLAYERSTAT_MELEE_COMBAT",
		"PLAYERSTAT_SPELL_COMBAT",
		"PLAYERSTAT_RANGED_COMBAT",
	}
	for index, category in pairs(categories) do
		CreateStatHeader(stat, index, category)
	end

	-- Init
	BuildListFromValue()
	BuildValueFromList()
	CharacterNameFrame:ClearAllPoints()
	CharacterNameFrame:SetPoint("TOPLEFT", _G.CharacterFrame, 130, -20)
	PaperDollFrame.__statPanels = {}
	M:ExGearManager()

	-- Update data
	hooksecurefunc("ToggleCharacter", UpdateStats)
	PaperDollFrame:HookScript("OnEvent", OnPaperDollEvent)

	InitializeStatPanel()
	SuppressStatsPanel()
	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			HideBlizzardExpandButton()
			HideExternalStatsToggleButton()
		end)
	end

	local LeatrixWatcher = CreateFrame("Frame")
	LeatrixWatcher:RegisterEvent("ADDON_LOADED")
	LeatrixWatcher:SetScript("OnEvent", function(_, _, addonName)
		if addonName == "Leatrix_Plus" then
			HideExternalStatsToggleButton()
		end
	end)

	PaperDollFrame:HookScript("OnShow", function()
		SuppressStatsPanel()
		InitializeStatPanel()
		HideBlizzardExpandButton()
		HideExternalStatsToggleButton()
		M:FindAddOnPanels()
		UpdateResistanceBar()
		HookCharacterModelPosition()
		UpdateStats()
	end)

	local CharacterFrame = _G.CharacterFrame
	if CharacterFrame then
		CharacterFrame:HookScript("OnShow", function()
			SuppressStatsPanel()
			UpdateResistanceBar()
			HookCharacterModelPosition()
		end)
	end

	UpdateResistanceBar()

	-- Block LeatrixPlus toggle
		if IsAddOnLoaded("Leatrix_Plus") then
			local function resetModelAnchor(_, point, relativeTo, relativePoint, x, y)
				local parentFrame = _G.PaperDollFrame or PaperDollFrame
				if point ~= CHARACTER_MODEL_POINT or relativeTo ~= parentFrame or relativePoint ~= CHARACTER_MODEL_REL_POINT or x ~= CHARACTER_MODEL_OFFSET_X or y ~= CHARACTER_MODEL_OFFSET_Y then
					AnchorCharacterModelFrame()
					HideModelRotators()
				end
			end

			local modelFrame = _G.CharacterModelFrame
			if modelFrame then
				resetModelAnchor(modelFrame)
				hooksecurefunc(modelFrame, "SetPoint", resetModelAnchor)
			end
		end

	hooksecurefunc("PaperDollFrame_SetLevel", M.AddCharacterIcon)

	local EventFrame = CreateFrame("Frame")
	EventFrame:RegisterUnitEvent("UNIT_NAME_UPDATE", "player")
	EventFrame:RegisterUnitEvent("PLAYER_ENTERING_WORLD")
	EventFrame:SetScript("OnEvent", function()
		M:AddCharacterIcon()
	end)
end

M:AddCallback("Armory")
