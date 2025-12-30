local MER, F, E, L, V, P, G = unpack(ElvUI_AzUI)
local module = MER:GetModule('MER_Misc')

local _G = _G
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local GameTooltip_Hide = GameTooltip_Hide
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local UnitGUID = UnitGUID
local UnitName = UnitName
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitDetailedThreatSituation = UnitDetailedThreatSituation
local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local GetNumGroupMembers = GetNumGroupMembers
local GetNumSubgroupMembers = GetNumSubgroupMembers
local GetTime = GetTime
local time = time

local format = format
local wipe = wipe
local pairs = pairs
local ipairs = ipairs
local sort = table.sort
local max = math.max
local floor = math.floor
local abs = math.abs
local bor = bit.bor
local band = bit.band
local tinsert = table.insert

local UNKNOWN_ACTOR = _G.UNKNOWN or _G.UNKNOWNOBJECT or "Unknown"
local LABEL_DAMAGE = _G.DAMAGE or "Damage"
local LABEL_HEALING = _G.HEALING_DONE or "Healing"
local LABEL_THREAT = _G.THREAT or "Threat"
local LABEL_DEATHS = _G.DEATHS or "Deaths"
local LABEL_DISPELS = _G.DISPELS or "Dispels"
local LABEL_CURRENT_FIGHT = L["Current Fight"] or "Current Fight"
local LABEL_SEGMENTS = L["Segments"] or "Segments"
local LABEL_NO_DATA = L["No Data Available"] or "No combat data yet."

local ROW_COUNT = 8
local ROW_HEIGHT = 20
local ROW_SPACING = 2
local SEGMENT_LIMIT = 20
local DETAIL_MAX_LINES = 8
local DETAIL_WIDTH = 360
local DETAIL_HEIGHT = 460
local DETAIL_MIN_WIDTH = 280
local DETAIL_MIN_HEIGHT = 320
local HOVER_LINE_COUNT = 6
local HOVER_FRAME_WIDTH = 240
local HOVER_FRAME_HEIGHT = 160
local GRAPH_BAR_COUNT = 60
local GRAPH_HEIGHT = 90
local LABEL_HIGHLIGHT = L["Highlight"] or "Highlight"
local LABEL_DAMAGE_TIMELINE = L["Damage Timeline"] or "Damage Timeline"
local LABEL_ATTACK_DETAILS = L["Attack Details"] or "Attack Details"
local LABEL_TOP_ABILITIES = L["Top Abilities"] or "Top Abilities"
local LABEL_MISS_PERCENT = L["Miss %"] or "Miss %"

local AFFILIATION_FILTER = bor(
	_G.COMBATLOG_OBJECT_AFFILIATION_MINE or 0,
	_G.COMBATLOG_OBJECT_AFFILIATION_PARTY or 0,
	_G.COMBATLOG_OBJECT_AFFILIATION_RAID or 0
)

local TYPE_FILTER = bor(
	_G.COMBATLOG_OBJECT_TYPE_PLAYER or 0,
	_G.COMBATLOG_OBJECT_TYPE_PET or 0,
	_G.COMBATLOG_OBJECT_TYPE_GUARDIAN or 0
)

local FRIENDLY_FLAG = _G.COMBATLOG_OBJECT_REACTION_FRIENDLY or 0
local HOSTILE_FLAG = _G.COMBATLOG_OBJECT_REACTION_HOSTILE or 0

local damageEvents = {
	SWING_DAMAGE = true,
	SPELL_DAMAGE = true,
	SPELL_PERIODIC_DAMAGE = true,
	RANGE_DAMAGE = true,
	DAMAGE_SPLIT = true,
	DAMAGE_SHIELD = true,
}

local healingEvents = {
	SPELL_HEAL = true,
	SPELL_PERIODIC_HEAL = true,
}

local dispelEvents = {
	SPELL_DISPEL = true,
	SPELL_STOLEN = true,
	SPELL_AURA_BROKEN_SPELL = true,
	SPELL_AURA_BROKEN = true,
}

local deathEvents = {
	UNIT_DIED = true,
	UNIT_DESTROYED = true,
	UNIT_DISSIPATES = true,
}

local missEvents = {
	SWING_MISSED = true,
	SPELL_MISSED = true,
	SPELL_PERIODIC_MISSED = true,
	RANGE_MISSED = true,
}

local viewOrder = { "damage", "healing", "threat", "dispels", "deaths" }
local viewLabels = {
	damage = LABEL_DAMAGE,
	healing = LABEL_HEALING,
	threat = LABEL_THREAT,
	dispels = LABEL_DISPELS,
	deaths = LABEL_DEATHS,
}

local outcomeLabels = {
	normal = L["Normal Hits"] or "Normal Hits",
	crit = L["Critical Hits"] or "Critical Hits",
	glancing = L["Glancing"] or "Glancing",
	crushing = L["Crushing"] or "Crushing",
	block = L["Blocked"] or "Blocked",
	dodge = L["Dodged"] or "Dodged",
	parry = L["Parried"] or "Parried",
	miss = L["Missed"] or "Missed",
	resist = L["Resisted"] or "Resisted",
	absorb = L["Absorbed"] or "Absorbed",
	evade = L["Evaded"] or "Evaded",
	immune = L["Immune"] or "Immune",
	reflect = L["Reflected"] or "Reflected",
}

local missOutcomeKeys = { "miss", "dodge", "parry", "evade", "immune", "block", "resist", "absorb" }

local missTypeMap = {
	MISS = "miss",
	BLOCK = "block",
	DEFLECT = "miss",
	DODGE = "dodge",
	PARRY = "parry",
	RESIST = "resist",
	IMMUNE = "immune",
	EVADE = "evade",
	REFLECT = "reflect",
	ABSORB = "absorb",
}

local viewIcons = {
	damage = "Interface\\Icons\\Ability_MeleeDamage",
	healing = "Interface\\Icons\\Spell_Holy_HolyBolt",
	threat = "Interface\\Icons\\Ability_Racial_Avatar",
	dispels = "Interface\\Icons\\Spell_Arcane_ArcaneTorrent",
	deaths = "Interface\\Icons\\Ability_Rogue_FeignDeath",
}

local segmentIconTexture = "Interface\\Icons\\INV_Misc_PocketWatch_01"

local meterFrame
local detailFrame
local segmentListFrame
local viewFlyoutFrame
local hoverGraphFrame
local UpdateViewButtonState
local rows = {}
local segmentCounter = 0
local sortCache = {}
local spellSortCache = {}

module.segmentHistory = module.segmentHistory or {}
module.currentSegment = module.currentSegment
module.displayedSegment = module.displayedSegment

local function ShortValue(amount, decimals)
	amount = amount or 0
	if amount == 0 then
		return "0"
	end

	if abs(amount) >= 1000 then
		return E:ShortValue(amount, decimals or 1)
	end

	if decimals and decimals > 0 then
		return format("%." .. decimals .. "f", amount)
	end

	return format("%.0f", amount)
end

local function FormatDuration(seconds)
	seconds = max(0, seconds)
	if seconds >= 3600 then
		local h = floor(seconds / 3600)
		local m = floor((seconds % 3600) / 60)
		return format("%dh %dm", h, m)
	elseif seconds >= 120 then
		local m = floor(seconds / 60)
		local s = floor(seconds % 60)
		return format("%dm %ds", m, s)
	elseif seconds >= 60 then
		return format("1m %ds", floor(seconds % 60))
	else
		return format("%ds", floor(seconds))
	end
end

local function CleanName(name)
	if not name or name == "" then
		return UNKNOWN_ACTOR
	end

	local short = name:match("^(.-)%-.+$")
	if short and short ~= "" then
		return short
	end

	return name
end

local function CreateSpellEntry(spellId, spellName)
	return {
		id = spellId,
		name = spellName or (spellId and ("#" .. spellId)) or (_G.MELEE or "Melee"),
		amount = 0,
		hits = 0,
		crits = 0,
		over = 0,
		extra = {},
	}
end

local function CreateSegment(isCurrent)
	segmentCounter = segmentCounter + 1
	return {
		id = segmentCounter,
		isCurrent = isCurrent,
		name = LABEL_CURRENT_FIGHT,
		startTime = GetTime(),
		endTime = nil,
		timestamp = time(),
		lastEnemyName = nil,
		totalDamage = 0,
		totalHealing = 0,
		totalThreat = 0,
		highestThreat = 0,
		totalDispels = 0,
		actors = {},
	}
end

local function EnsureActor(segment, guid, name, class)
	if not guid then
		return
	end

	local actors = segment.actors
	local actor = actors[guid]
	if not actor then
		actor = {
			guid = guid,
			name = CleanName(name),
			class = class,
			damage = 0,
			healing = 0,
			threat = 0,
			deaths = 0,
			dispels = 0,
			damageSpells = {},
			healingSpells = {},
			dispelSpells = {},
			damageTimeline = {},
			outcomeBreakdown = {},
		}
		actors[guid] = actor
	else
		if name and name ~= "" then
			actor.name = CleanName(name)
		end
		if class then
			actor.class = class
		end
	end

	return actor
end

local function AddSpellAmount(tableRef, spellId, spellName, amount, isCrit, extraKey)
	if not tableRef then
		return
	end

	spellId = spellId or 0
	local entry = tableRef[spellId]
	if not entry then
		entry = CreateSpellEntry(spellId, spellName)
		tableRef[spellId] = entry
	end

	if amount and amount > 0 then
		entry.amount = entry.amount + amount
	end

	entry.hits = entry.hits + 1
	if isCrit then
		entry.crits = (entry.crits or 0) + 1
	end

	if extraKey and extraKey ~= "" then
		entry.extra[extraKey] = (entry.extra[extraKey] or 0) + 1
	end
end

local function TrackDamageTimeline(actor, segment, amount)
	if not actor or not segment or not amount or amount <= 0 then
		return
	end

	actor.damageTimeline = actor.damageTimeline or {}
	local now = GetTime()
	local startTime = segment.startTime or now
	local bucket = floor(max(0, now - startTime))
	actor.damageTimeline[bucket] = (actor.damageTimeline[bucket] or 0) + amount
end

local function TrackOutcome(actor, outcomeKey)
	if not actor then
		return
	end

	actor.outcomeBreakdown = actor.outcomeBreakdown or {}
	local key = outcomeKey or "normal"
	actor.outcomeBreakdown[key] = (actor.outcomeBreakdown[key] or 0) + 1
end

local function ResetSegmentData(segment)
	wipe(segment.actors)
	segment.startTime = GetTime()
	segment.endTime = nil
	segment.lastEnemyName = nil
	segment.totalDamage = 0
	segment.totalHealing = 0
	segment.totalThreat = 0
	segment.highestThreat = 0
	segment.totalDispels = 0
	segment.name = LABEL_CURRENT_FIGHT
	segment.timestamp = time()
end

local function CloneSpellTable(source)
	if not source then
		return nil
	end

	local copy = {}
	for spellId, data in pairs(source) do
		local newEntry = {
			id = data.id,
			name = data.name,
			amount = data.amount or 0,
			hits = data.hits or 0,
			crits = data.crits or 0,
			over = data.over or 0,
			extra = {},
		}
		for key, value in pairs(data.extra or {}) do
			newEntry.extra[key] = value
		end
		copy[spellId] = newEntry
	end
	return copy
end

local function CloneSimpleTable(source)
	if not source then
		return nil
	end

	local copy = {}
	for key, value in pairs(source) do
		copy[key] = value
	end

	return copy
end

local function CloneSegment(segment)
	local copy = {
		id = segment.id,
		isCurrent = false,
		name = segment.name,
		startTime = segment.startTime,
		endTime = segment.endTime,
		timestamp = segment.timestamp,
		lastEnemyName = segment.lastEnemyName,
		totalDamage = segment.totalDamage,
		totalHealing = segment.totalHealing,
		totalThreat = segment.totalThreat,
		highestThreat = segment.highestThreat,
		totalDispels = segment.totalDispels,
		actors = {},
	}

	for guid, actor in pairs(segment.actors) do
		local actorCopy = {
			guid = actor.guid,
			name = actor.name,
			class = actor.class,
			damage = actor.damage,
			healing = actor.healing,
			threat = actor.threat,
			deaths = actor.deaths,
			dispels = actor.dispels,
			damageSpells = CloneSpellTable(actor.damageSpells),
			healingSpells = CloneSpellTable(actor.healingSpells),
			dispelSpells = CloneSpellTable(actor.dispelSpells),
			damageTimeline = CloneSimpleTable(actor.damageTimeline),
			outcomeBreakdown = CloneSimpleTable(actor.outcomeBreakdown),
		}
		copy.actors[guid] = actorCopy
	end

	return copy
end

local function IsTracked(flags)
	if not flags then
		return false
	end

	if band(flags, FRIENDLY_FLAG) == 0 then
		return false
	end

	if band(flags, AFFILIATION_FILTER) == 0 then
		return false
	end

	return band(flags, TYPE_FILTER) ~= 0
end

local function SegmentHasActivity(segment)
	return (segment.totalDamage > 0)
		or (segment.totalHealing > 0)
		or (segment.totalDispels > 0)
		or (segment.highestThreat > 0)
		or (segment.endTime and segment.endTime > segment.startTime)
end

local function NormalizeMissType(missType)
	if not missType or missType == "" then
		return "miss"
	end

	return missTypeMap[missType] or "miss"
end

local function ExtractHitFlags(subEvent, info)
	local isCrit = false
	local isGlancing = false
	local isCrushing = false

	if subEvent == "SWING_DAMAGE" then
		isCrit = info[18] or false
		isGlancing = info[19] or false
		isCrushing = info[20] or false
	else
		local critIndex = 21
		if info[critIndex] ~= nil then
			isCrit = info[critIndex] or false
		end
	end

	return isCrit, isGlancing, isCrushing
end

local function GetOutcomeKey(subEvent, isCrit, isGlancing, isCrushing)
	if isCrit then
		return "crit"
	elseif isGlancing then
		return "glancing"
	elseif isCrushing then
		return "crushing"
	end

	return "normal"
end

local function GetSegmentDuration(segment)
	local endTime = segment.endTime or GetTime()
	return max(0, endTime - (segment.startTime or endTime))
end

local function FormatSegmentName(segment)
	local base = segment.name or LABEL_CURRENT_FIGHT
	if segment.lastEnemyName and segment.lastEnemyName ~= "" then
		base = segment.lastEnemyName
	end

	if segment.isCurrent then
		return base
	end

	local duration = FormatDuration(GetSegmentDuration(segment))
	return format("%s • %s", base, duration)
end

local function SortSpells(spellTable)
	wipe(spellSortCache)
	if not spellTable then
		return spellSortCache
	end

	for _, data in pairs(spellTable) do
		spellSortCache[#spellSortCache + 1] = data
	end

	sort(spellSortCache, function(a, b)
		local aAmount = a.amount or a.hits or 0
		local bAmount = b.amount or b.hits or 0
		if aAmount == bAmount then
			return (a.name or "") < (b.name or "")
		end
		return aAmount > bAmount
	end)

	return spellSortCache
end

local function GetDisplayedSegment()
	return module.displayedSegment or module.currentSegment
end

local function ActorColor(actor)
	if not actor or not actor.class then
		return 0.2, 0.6, 1, 0.75
	end

	local color = E:ClassColor(actor.class, true)
	if color then
		return color.r, color.g, color.b, 0.75
	end

	return 0.2, 0.6, 1, 0.75
end

local function BuildSortedList(segment, view)
	wipe(sortCache)
	if not segment then
		return sortCache
	end

	local key = view
	local includeZeroDeaths = (view == "deaths")
	local includeZeroDispels = (view == "dispels")

	for _, actor in pairs(segment.actors) do
		local value = actor[key] or 0
		if value > 0 or (includeZeroDeaths and actor.deaths and actor.deaths > 0) or (includeZeroDispels and actor.dispels and actor.dispels > 0) then
			sortCache[#sortCache + 1] = actor
		end
	end

	sort(sortCache, function(a, b)
		local av = a[key] or 0
		local bv = b[key] or 0
		if av == bv then
			return (a.name or UNKNOWN_ACTOR) < (b.name or UNKNOWN_ACTOR)
		end
		return av > bv
	end)

	return sortCache
end

local function FormatRate(amount)
	if amount <= 0 then
		return "0"
	end

	if amount < 10 then
		return format("%.2f", amount)
	elseif amount < 100 then
		return format("%.1f", amount)
	end

	return E:ShortValue(amount, 1)
end

local function FormatRowValue(segment, view, value, total, duration)
	if view == "damage" then
		local percent = total > 0 and (value / total) * 100 or 0
		local dps = duration > 0 and (value / duration) or 0
		return format("%s | %.1f%% | %s DPS", ShortValue(value, 1), percent, FormatRate(dps))
	elseif view == "healing" then
		local percent = total > 0 and (value / total) * 100 or 0
		local hps = duration > 0 and (value / duration) or 0
		return format("%s | %.1f%% | %s HPS", ShortValue(value, 1), percent, FormatRate(hps))
	elseif view == "threat" then
		local percent = total > 0 and (value / total) * 100 or 0
		return format("%s | %.1f%%", ShortValue(value, 1), percent)
	elseif view == "dispels" then
		local percent = total > 0 and (value / total) * 100 or 0
		return format("%d | %.1f%%", value, percent)
	elseif view == "deaths" then
		return format("%d", value)
	end

	return ShortValue(value, 1)
end

local function PopulateTooltipLines(tooltip, segment, actor, view)
	if not actor then
		return
	end

	if view == "damage" then
		local spells = SortSpells(actor.damageSpells)
		if #spells > 0 then
			tooltip:AddLine(" ")
			for i = 1, math.min(#spells, DETAIL_MAX_LINES) do
				local spell = spells[i]
				tooltip:AddDoubleLine(
					spell.name or ("#" .. (spell.id or 0)),
					format("%s (%d)", ShortValue(spell.amount, 1), spell.hits or 0),
					0.8, 0.8, 0.8,
					0.7, 0.7, 0.7
				)
			end
		end
	elseif view == "healing" then
		local spells = SortSpells(actor.healingSpells)
		if #spells > 0 then
			tooltip:AddLine(" ")
			for i = 1, math.min(#spells, DETAIL_MAX_LINES) do
				local spell = spells[i]
				tooltip:AddDoubleLine(
					spell.name or ("#" .. (spell.id or 0)),
					format("%s (%d)", ShortValue(spell.amount, 1), spell.hits or 0),
					0.8, 0.8, 0.8,
					0.7, 0.7, 0.7
				)
			end
		end
	elseif view == "dispels" then
		local spells = SortSpells(actor.dispelSpells)
		if #spells > 0 then
			tooltip:AddLine(" ")
			for i = 1, math.min(#spells, DETAIL_MAX_LINES) do
				local spell = spells[i]
				local removedCount = 0
				for _, count in pairs(spell.extra or {}) do
					removedCount = removedCount + count
				end
				tooltip:AddDoubleLine(
					spell.name or ("#" .. (spell.id or 0)),
					format("%d (%d)", spell.hits or 0, removedCount),
					0.8, 0.8, 0.8,
					0.7, 0.7, 0.7
				)
			end
		end
	end
end

local function EnsureHoverGraphFrame()
	if hoverGraphFrame then
		return hoverGraphFrame
	end

	if not meterFrame then
		return nil
	end

	hoverGraphFrame = CreateFrame("Frame", "MERCombatMeterHoverGraph", meterFrame, "BackdropTemplate")
	hoverGraphFrame:SetSize(HOVER_FRAME_WIDTH, HOVER_FRAME_HEIGHT)
	hoverGraphFrame:SetFrameStrata(meterFrame:GetFrameStrata())
	hoverGraphFrame:SetFrameLevel(meterFrame:GetFrameLevel() + 8)
	hoverGraphFrame:Hide()

	if hoverGraphFrame.SetTemplate then
		hoverGraphFrame:SetTemplate("Transparent")
	end

	hoverGraphFrame.title = hoverGraphFrame:CreateFontString(nil, "OVERLAY")
	hoverGraphFrame.title:SetFont(E.media.normFont, 12, "OUTLINE")
	hoverGraphFrame.title:SetPoint("TOP", hoverGraphFrame, "TOP", 0, -8)

	hoverGraphFrame.lines = {}
	local anchor
	for index = 1, HOVER_LINE_COUNT do
		local line = CreateFrame("Frame", nil, hoverGraphFrame)
		line:SetHeight(18)
		if not anchor then
			line:SetPoint("TOPLEFT", hoverGraphFrame, "TOPLEFT", 4, -32)
			line:SetPoint("TOPRIGHT", hoverGraphFrame, "TOPRIGHT", -4, -32)
		else
			line:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
			line:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -4)
		end
		anchor = line

		line.bar = CreateFrame("StatusBar", nil, line)
		line.bar:SetAllPoints()
		line.bar:SetStatusBarTexture(E.media.normTex)
		line.bar:SetMinMaxValues(0, 1)
		line.bar:SetValue(0)

		line.bg = line:CreateTexture(nil, "BACKGROUND")
		line.bg:SetAllPoints()
		line.bg:SetColorTexture(0, 0, 0, 0.35)

		line.rank = line:CreateFontString(nil, "OVERLAY")
		line.rank:SetFont(E.media.normFont, 10, "OUTLINE")
		line.rank:SetPoint("LEFT", line, "LEFT", 4, 0)
		line.rank:SetJustifyH("LEFT")

		line.name = line:CreateFontString(nil, "OVERLAY")
		line.name:SetFont(E.media.normFont, 10, "OUTLINE")
		line.name:SetPoint("LEFT", line.rank, "RIGHT", 4, 0)
		line.name:SetPoint("RIGHT", line, "RIGHT", -90, 0)
		line.name:SetJustifyH("LEFT")
		line.name:SetWordWrap(false)

		line.value = line:CreateFontString(nil, "OVERLAY")
		line.value:SetFont(E.media.normFont, 10, "OUTLINE")
		line.value:SetPoint("RIGHT", line, "RIGHT", -4, 0)
		line.value:SetJustifyH("RIGHT")

		hoverGraphFrame.lines[index] = line
	end

	return hoverGraphFrame
end

local function HideHoverGraph()
	if hoverGraphFrame then
		hoverGraphFrame:Hide()
	end
end

local function ShowHoverGraph(row, actor, view)
	if not row or not actor then
		HideHoverGraph()
		return
	end

	if view ~= "damage" and view ~= "healing" and view ~= "dispels" then
		HideHoverGraph()
		return
	end

	local frame = EnsureHoverGraphFrame()
	if not frame then
		return
	end

	frame:SetParent(meterFrame)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", row, "TOPRIGHT", 6, 0)
	frame:SetFrameStrata(row:GetFrameStrata())
	frame:SetFrameLevel(row:GetFrameLevel() + 5)
	frame.title:SetText(format("%s • %s", actor.name or UNKNOWN_ACTOR, viewLabels[view] or view))

	local spells
	if view == "damage" then
		spells = SortSpells(actor.damageSpells)
	elseif view == "healing" then
		spells = SortSpells(actor.healingSpells)
	elseif view == "dispels" then
		spells = SortSpells(actor.dispelSpells)
	else
		spells = wipe(spellSortCache)
	end

	if #spells == 0 then
		HideHoverGraph()
		return
	end

	local maxSpellValue = 0
	local valueKey = (view == "dispels") and "hits" or "amount"
	for index = 1, math.min(#spells, HOVER_LINE_COUNT) do
		local data = spells[index]
		if data and data[valueKey] and data[valueKey] > maxSpellValue then
			maxSpellValue = data[valueKey]
		end
	end
	if maxSpellValue <= 0 then
		maxSpellValue = 1
	end

	local r, g, b = ActorColor(actor)
	local totalValue = actor[view] or 0
	for index = 1, HOVER_LINE_COUNT do
		local line = frame.lines[index]
		local spell = spells[index]
		if line and spell then
			local statValue = spell[valueKey] or 0
			local percentOfTotal = (totalValue > 0) and ((statValue / totalValue) * 100) or 0
			local valueText = (valueKey == "amount") and ShortValue(statValue, 1) or tostring(statValue)
			line.rank:SetText(format("%d.", index))
			line.name:SetText(spell.name or ("#" .. (spell.id or 0)))
			line.value:SetText(format("%s (%.1f%%)", valueText, percentOfTotal))
			line.bar:SetMinMaxValues(0, maxSpellValue)
			line.bar:SetValue(statValue)
			line.bar:SetStatusBarColor(r, g, b, 0.8)
			line:Show()
		elseif line then
			line.rank:SetText("")
			line.name:SetText("")
			line.value:SetText("")
			line.bar:SetValue(0)
			line:Hide()
		end
	end

	frame:Show()
end

local function BuildTimelineBuckets(actor, segment)
	local buckets = {}
	local timeline = actor and actor.damageTimeline
	local duration = max(1, floor(GetSegmentDuration(segment)))
	local bucketSize = max(1, floor(duration / GRAPH_BAR_COUNT))
	if duration < GRAPH_BAR_COUNT then
		bucketSize = 1
	end

	local accum = 0
	local secondsInBucket = 0
	for second = 0, duration do
		local value = timeline and timeline[second] or 0
		accum = accum + (value or 0)
		secondsInBucket = secondsInBucket + 1
		if secondsInBucket >= bucketSize or second == duration then
			buckets[#buckets + 1] = { value = accum, seconds = secondsInBucket }
			accum = 0
			secondsInBucket = 0
		end
	end

	if #buckets == 0 then
		buckets[1] = { value = 0, seconds = bucketSize }
	end

	local maxValue = 0
	for _, bucket in ipairs(buckets) do
		if bucket.value > maxValue then
			maxValue = bucket.value
		end
	end

	return buckets, maxValue
end

local function BuildOutcomeList(actor)
	local breakdown = (actor and actor.outcomeBreakdown) or {}
	local ordered = {}
	for key, count in pairs(breakdown) do
		if count and count > 0 then
			ordered[#ordered + 1] = {
				key = key,
				label = outcomeLabels[key] or key,
				count = count,
			}
		end
	end

	sort(ordered, function(a, b)
		if a.count == b.count then
			return a.label < b.label
		end
		return a.count > b.count
	end)

	return ordered
end

local function ComputeMissPercent(breakdown)
	local total = 0
	local missed = 0
	if breakdown then
		for _, count in pairs(breakdown) do
			total = total + count
		end
		for _, key in ipairs(missOutcomeKeys) do
			missed = missed + (breakdown[key] or 0)
		end
	end

	local percent = (total > 0) and ((missed / total) * 100) or 0
	return percent, total, missed
end

local function SaveDetailFramePosition()
	if not detailFrame then
		return
	end

	local parent = E.UIParent or UIParent
	local centerX, centerY = detailFrame:GetCenter()
	local parentCenterX, parentCenterY = parent and parent:GetCenter()
	if not centerX or not centerY or not parentCenterX or not parentCenterY then
		return
	end

	detailFrame.savedPosition = {
		x = centerX - parentCenterX,
		y = centerY - parentCenterY,
	}
end

local function SaveDetailFrameSize()
	if not detailFrame then
		return
	end

	detailFrame.savedSize = {
		width = max(DETAIL_MIN_WIDTH, detailFrame:GetWidth() or DETAIL_WIDTH),
		height = max(DETAIL_MIN_HEIGHT, detailFrame:GetHeight() or DETAIL_HEIGHT),
	}
end

local function ApplyDetailFramePosition()
	if not detailFrame then
		return
	end

	local parent = E.UIParent or UIParent
	detailFrame:ClearAllPoints()
	local pos = detailFrame.savedPosition
	if pos then
		detailFrame:SetPoint("CENTER", parent, "CENTER", pos.x or 0, pos.y or 0)
	else
		detailFrame:SetPoint("CENTER", parent, "CENTER", 0, 0)
		SaveDetailFramePosition()
	end
end

local function ApplyDetailFrameSize()
	if not detailFrame then
		return
	end

	local savedSize = detailFrame.savedSize
	local width = max(DETAIL_MIN_WIDTH, savedSize and savedSize.width or DETAIL_WIDTH)
	local height = max(DETAIL_MIN_HEIGHT, savedSize and savedSize.height or DETAIL_HEIGHT)
	detailFrame:SetSize(width, height)
end

local function PositionDetailFrame()
	if not detailFrame then
		return
	end

	detailFrame:SetParent(E.UIParent or UIParent)
	detailFrame:SetFrameStrata("DIALOG")
	detailFrame:SetFrameLevel((meterFrame and meterFrame:GetFrameLevel() or ((E.UIParent or UIParent):GetFrameLevel()) or 5) + 10)
	ApplyDetailFramePosition()
	ApplyDetailFrameSize()
end

local function ClearGraphHighlight()
	if detailFrame then
		if detailFrame.graphHighlightLabel then
			detailFrame.graphHighlightLabel:SetText("")
			detailFrame.graphHighlightLabel:Hide()
		end
		if detailFrame.graph and detailFrame.graph.highlight then
			detailFrame.graph.highlight:Hide()
		end
	end
end

local function HighlightGraphForSpell(spellName, r, g, b)
	if not detailFrame or not detailFrame.graph or not detailFrame.graph:IsShown() then
		return
	end

	local highlight = detailFrame.graph.highlight
	if highlight then
		highlight:SetColorTexture(r or 0.9, g or 0.8, b or 0.2, 0.2)
		highlight:Show()
	end

	if detailFrame.graphHighlightLabel then
		detailFrame.graphHighlightLabel:SetText(format("%s: %s", LABEL_HIGHLIGHT, spellName or UNKNOWN_ACTOR))
		detailFrame.graphHighlightLabel:Show()
	end
end

local function DetailLine_OnEnter(line)
	if not line or not line.spell or not detailFrame or detailFrame.view ~= "damage" then
		return
	end

	if not detailFrame:IsShown() then
		return
	end

	HighlightGraphForSpell(line.spell.name or UNKNOWN_ACTOR, line.actorColorR or 1, line.actorColorG or 0.9, line.actorColorB or 0.2)
end

local function DetailLine_OnLeave()
	ClearGraphHighlight()
end

local function LayoutGraphBars(frame)
	if not frame or not frame.bars then
		return
	end

	local width = frame:GetWidth() or 0
	if width <= 0 then
		return
	end

	local spacing = 1
	local barWidth = (width - ((GRAPH_BAR_COUNT - 1) * spacing)) / GRAPH_BAR_COUNT
	barWidth = max(1, barWidth)

	for index = 1, GRAPH_BAR_COUNT do
		local bar = frame.bars[index]
		if not bar then
			bar = frame:CreateTexture(nil, "ARTWORK")
			frame.bars[index] = bar
		end
		bar:ClearAllPoints()
		bar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", (index - 1) * (barWidth + spacing), 1)
		bar:SetWidth(barWidth)
		bar:SetHeight(2)
		bar:SetColorTexture(0.2, 0.6, 1, 0.85)
	end
end

local function LayoutDetailColumns()
	if not detailFrame then
		return
	end

	local container = detailFrame.container
	local availableWidth = (container and container:GetWidth()) or (detailFrame:GetWidth() - 24) or DETAIL_WIDTH
	availableWidth = max(120, availableWidth)

	local leftVisible = detailFrame.leftColumn and detailFrame.leftColumn:IsShown()
	local rightVisible = detailFrame.rightColumn and detailFrame.rightColumn:IsShown()
	local leftWidth = leftVisible and max(120, detailFrame.leftColumn:GetWidth()) or availableWidth
	local rightWidth = rightVisible and max(120, detailFrame.rightColumn:GetWidth()) or max(120, availableWidth * 0.5)

	local rankWidth = 34
	local valueWidth = max(110, leftWidth * 0.35)
	local nameWidth = max(60, leftWidth - rankWidth - valueWidth - 16)

	if leftVisible and detailFrame.lines then
		for _, line in ipairs(detailFrame.lines) do
			line.rank:SetWidth(rankWidth)
			line.value:SetWidth(valueWidth)
			if line.name then
				line.name:SetWidth(nameWidth)
			end
		end
	end

	local columnWidth = max(80, (rightWidth - 16) * 0.5)
	local labelWidth = max(50, columnWidth * 0.45)
	local valueColumnWidth = max(50, columnWidth - labelWidth)
	if rightVisible and detailFrame.breakdownLines then
		for _, row in ipairs(detailFrame.breakdownLines) do
			row.leftLabel:SetWidth(labelWidth)
			row.leftValue:SetWidth(valueColumnWidth)
			row.rightLabel:SetWidth(labelWidth)
			row.rightValue:SetWidth(valueColumnWidth)
		end
	end
end

local function UpdateDetailFrame()
	if not detailFrame or not detailFrame:IsShown() then
		return
	end

	local segment = GetDisplayedSegment()
	if not segment then
		detailFrame:Hide()
		return
	end

	local actor = detailFrame.actor
	local view = detailFrame.view
	if not actor or not view then
		detailFrame:Hide()
		return
	end

	local configView = view
	local total = 0
	if view == "damage" then
		total = segment.totalDamage
	elseif view == "healing" then
		total = segment.totalHealing
	elseif view == "threat" then
		total = segment.totalThreat
	elseif view == "dispels" then
		total = segment.totalDispels
	elseif view == "deaths" then
		for _, data in pairs(segment.actors) do
			total = total + (data.deaths or 0)
		end
	end

	local value = actor[view] or 0
	local percent = total > 0 and (value / total) * 100 or 0
	local duration = max(1, GetSegmentDuration(segment))
	local rateText = ""
	if view == "damage" then
		rateText = format("%s DPS", FormatRate(value / duration))
	elseif view == "healing" then
		rateText = format("%s HPS", FormatRate(value / duration))
	end

	detailFrame.title:SetText(format("%s • %s", actor.name or UNKNOWN_ACTOR, viewLabels[configView] or view))
	detailFrame.summaryLeft:SetText(format("%s: %s", viewLabels[configView] or view, ShortValue(value, 1)))
	detailFrame.summaryRight:SetText(format("%.1f%%", percent))
	detailFrame.rate:SetText(rateText)

	local others = max(0, total - value)
	detailFrame.others:SetText(format(L["Others"] or "Others: %s", ShortValue(others, 1)))

	local showDamageExtras = (view == "damage")
	local showSpellList = (view == "damage" or view == "healing" or view == "dispels")
	if detailFrame.graphTitle then
		detailFrame.graphTitle:SetShown(showDamageExtras)
	end
	if detailFrame.graph then
		detailFrame.graph:SetShown(showDamageExtras)
	end
	if detailFrame.graphAverage then
		detailFrame.graphAverage:SetShown(showDamageExtras)
	end
	if detailFrame.graphPeak then
		detailFrame.graphPeak:SetShown(showDamageExtras)
	end
	if detailFrame.graphHighlightLabel then
		if showDamageExtras then
			detailFrame.graphHighlightLabel:SetShown(detailFrame.graphHighlightLabel:GetText() ~= "")
		else
			detailFrame.graphHighlightLabel:Hide()
		end
	end
	if detailFrame.spellTitle then
		detailFrame.spellTitle:SetShown(showSpellList)
		if showSpellList then
			detailFrame.spellTitle:SetText(format("%s • %s", viewLabels[view] or view, LABEL_TOP_ABILITIES))
		end
	end
	if detailFrame.leftColumn then
		detailFrame.leftColumn:ClearAllPoints()
		if showSpellList then
			detailFrame.leftColumn:SetPoint("TOPLEFT", detailFrame.graphHighlightLabel, "BOTTOMLEFT", 0, -12)
			detailFrame.leftColumn:SetPoint("BOTTOMLEFT", detailFrame.container, "BOTTOMLEFT", 0, 12)
			if showDamageExtras and detailFrame.rightColumn then
				detailFrame.leftColumn:SetPoint("RIGHT", detailFrame.container, "CENTER", -8, 0)
			else
				detailFrame.leftColumn:SetPoint("RIGHT", detailFrame.container, "RIGHT", 0, 0)
			end
		end
		detailFrame.leftColumn:SetShown(showSpellList)
	end
	if detailFrame.lines then
		for _, line in ipairs(detailFrame.lines) do
			line:SetShown(showSpellList)
			if not showSpellList then
				line.rank:SetText("")
				line.name:SetText("")
				line.value:SetText("")
				line.bar:SetValue(0)
				line.spell = nil
			end
		end
	end
	if detailFrame.breakdownTitle then
		detailFrame.breakdownTitle:SetShown(showDamageExtras)
	end
	if detailFrame.rightColumn then
		detailFrame.rightColumn:ClearAllPoints()
		if showDamageExtras then
			if showSpellList and detailFrame.leftColumn and detailFrame.leftColumn:IsShown() then
				detailFrame.rightColumn:SetPoint("TOPLEFT", detailFrame.leftColumn, "TOPRIGHT", 12, 0)
				detailFrame.rightColumn:SetPoint("BOTTOMLEFT", detailFrame.leftColumn, "BOTTOMRIGHT", 12, 0)
			else
				detailFrame.rightColumn:SetPoint("TOPLEFT", detailFrame.graphHighlightLabel, "BOTTOMLEFT", 0, -12)
				detailFrame.rightColumn:SetPoint("BOTTOMLEFT", detailFrame.container, "BOTTOMLEFT", 0, 12)
			end
			detailFrame.rightColumn:SetPoint("RIGHT", detailFrame.container, "RIGHT", 0, 0)
			detailFrame.rightColumn:SetShown(true)
		else
			detailFrame.rightColumn:SetShown(false)
		end
	end
	if detailFrame.breakdownLines then
		for _, row in ipairs(detailFrame.breakdownLines) do
			row:SetShown(showDamageExtras)
			if not showDamageExtras then
				row.leftLabel:SetText("")
				row.leftValue:SetText("")
				row.rightLabel:SetText("")
				row.rightValue:SetText("")
			end
		end
	end
	if detailFrame.missSummary then
		detailFrame.missSummary:SetShown(showDamageExtras)
	end

	if showDamageExtras and detailFrame.graph then
		LayoutGraphBars(detailFrame.graph)
		local buckets, maxValue = BuildTimelineBuckets(actor, segment)
		local hasData = false
		local r, g, b = ActorColor(actor)
		local graphHeight = max(1, detailFrame.graph:GetHeight() - 4)
		for index = 1, GRAPH_BAR_COUNT do
			local bar = detailFrame.graph.bars and detailFrame.graph.bars[index]
			if bar then
				local data = buckets[index]
				local currentValue = data and data.value or 0
				local heightRatio = (maxValue > 0) and (currentValue / maxValue) or 0
				bar:SetHeight(max(2, graphHeight * heightRatio))
				bar:SetColorTexture(r, g, b, 0.85)
				bar:SetAlpha(data and 0.9 or 0.2)
				if currentValue > 0 then
					hasData = true
				end
			end
		end
		if detailFrame.graph.placeholder then
			detailFrame.graph.placeholder:SetShown(not hasData)
		end

		local peakRate = 0
		for _, data in ipairs(buckets) do
			local secondsInBucket = max(1, data.seconds or 1)
			peakRate = max(peakRate, data.value / secondsInBucket)
		end

		local averageRate = duration > 0 and (value / duration) or 0
		if detailFrame.graphAverage then
			detailFrame.graphAverage:SetText(format("Avg: %s DPS", FormatRate(averageRate)))
		end
		if detailFrame.graphPeak then
			detailFrame.graphPeak:SetText(format("Peak: %s DPS", FormatRate(peakRate)))
		end

		local breakdownList = BuildOutcomeList(actor)
		local missPercent, totalAttempts = ComputeMissPercent(actor.outcomeBreakdown)
		local entriesPerRow = 2
		for rowIndex, row in ipairs(detailFrame.breakdownLines or {}) do
			local leftEntry = breakdownList[(rowIndex - 1) * entriesPerRow + 1]
			local rightEntry = breakdownList[(rowIndex - 1) * entriesPerRow + 2]
			if leftEntry and totalAttempts > 0 then
				local entryPercent = (leftEntry.count / totalAttempts) * 100
				row.leftLabel:SetText(leftEntry.label)
				row.leftValue:SetText(format("%d (%.1f%%)", leftEntry.count, entryPercent))
			else
				row.leftLabel:SetText("")
				row.leftValue:SetText("")
			end

			if rightEntry and totalAttempts > 0 then
				local entryPercent = (rightEntry.count / totalAttempts) * 100
				row.rightLabel:SetText(rightEntry.label)
				row.rightValue:SetText(format("%d (%.1f%%)", rightEntry.count, entryPercent))
			else
				row.rightLabel:SetText("")
				row.rightValue:SetText("")
			end
		end
		if detailFrame.missSummary then
			detailFrame.missSummary:SetText(format("%s: %.1f%%", LABEL_MISS_PERCENT, missPercent))
		end
	elseif detailFrame.breakdownLines then
		for _, row in ipairs(detailFrame.breakdownLines) do
			row.leftLabel:SetText("")
			row.leftValue:SetText("")
			row.rightLabel:SetText("")
			row.rightValue:SetText("")
		end
		if detailFrame.graph and detailFrame.graph.placeholder then
			detailFrame.graph.placeholder:SetShown(false)
		end
		if detailFrame.graphAverage then
			detailFrame.graphAverage:SetText("")
		end
		if detailFrame.graphPeak then
			detailFrame.graphPeak:SetText("")
		end
		if detailFrame.missSummary then
			detailFrame.missSummary:SetText("")
		end
		ClearGraphHighlight()
	end

	if showSpellList then
		local spells
		if view == "damage" then
			spells = SortSpells(actor.damageSpells)
		elseif view == "healing" then
			spells = SortSpells(actor.healingSpells)
		elseif view == "dispels" then
			spells = SortSpells(actor.dispelSpells)
		else
			spells = wipe(spellSortCache)
		end

		local maxSpellValue = 0
		if view == "dispels" then
			for _, spell in ipairs(spells) do
				if (spell.hits or 0) > maxSpellValue then
					maxSpellValue = spell.hits or 0
				end
			end
		else
			for _, spell in ipairs(spells) do
				if (spell.amount or 0) > maxSpellValue then
					maxSpellValue = spell.amount or 0
				end
			end
		end
		if maxSpellValue <= 0 then
			maxSpellValue = 1
		end

		for index = 1, DETAIL_MAX_LINES do
			local line = detailFrame.lines[index]
			local spell = spells[index]
			if spell then
				local spellValue
				local amountText
				local extraText = ""
				if view == "dispels" then
					spellValue = spell.hits or 0
					amountText = format("%d", spell.hits or 0)
					local removed = 0
					for _, count in pairs(spell.extra or {}) do
						removed = removed + count
					end
					if removed > 0 then
						extraText = format("%d", removed)
					end
				else
					spellValue = spell.amount or 0
					amountText = ShortValue(spell.amount or 0, 1)
					extraText = format("%d / %d", spell.hits or 0, spell.crits or 0)
				end

				local spellPercent = value > 0 and (spellValue / value) * 100 or 0
				line.rank:SetText(format("%d.", index))
				line.name:SetText(spell.name or ("#" .. (spell.id or 0)))
				if extraText ~= "" then
					line.value:SetText(format("%s | %.1f%% | %s", amountText, spellPercent, extraText))
				else
					line.value:SetText(format("%s | %.1f%%", amountText, spellPercent))
				end

				local r, g, b = ActorColor(actor)
				line.bar:SetMinMaxValues(0, maxSpellValue)
				line.bar:SetValue(spellValue)
				line.bar:SetStatusBarColor(r, g, b, 0.8)
				line.spell = spell
				line.actorColorR = r
				line.actorColorG = g
				line.actorColorB = b
			else
				line.rank:SetText("")
				line.name:SetText("")
				line.value:SetText("")
				line.bar:SetValue(0)
				line.spell = nil
				line.actorColorR = nil
				line.actorColorG = nil
				line.actorColorB = nil
			end
		end
	end

	LayoutDetailColumns()
end

local function HideDetailFrame(force)
	if detailFrame then
		detailFrame.actor = nil
		detailFrame.view = nil
		ClearGraphHighlight()
		if force then
			detailFrame:Hide()
		end
	end
end

local function ShowDetailFrame(actor, view)
	if not meterFrame then
		return
	end

	if not detailFrame then
		detailFrame = CreateFrame("Frame", "MERCombatMeterDetailFrame", E.UIParent or UIParent, "BackdropTemplate")
		detailFrame:SetSize(DETAIL_WIDTH, DETAIL_HEIGHT)
		detailFrame:SetFrameStrata("DIALOG")
		detailFrame:SetFrameLevel(meterFrame:GetFrameLevel() + 10)
		detailFrame:Hide()
		detailFrame.savedSize = { width = DETAIL_WIDTH, height = DETAIL_HEIGHT }
		detailFrame:SetMovable(true)
		detailFrame:SetResizable(true)
		detailFrame:SetClampedToScreen(true)
		detailFrame:SetToplevel(true)
		if detailFrame.SetResizeBounds then
			detailFrame:SetResizeBounds(DETAIL_MIN_WIDTH, DETAIL_MIN_HEIGHT)
		elseif detailFrame.SetMinResize then
			detailFrame:SetMinResize(DETAIL_MIN_WIDTH, DETAIL_MIN_HEIGHT)
		end

		detailFrame:SetScript("OnSizeChanged", function(self)
			SaveDetailFrameSize()
			SaveDetailFramePosition()
			if self.graph then
				LayoutGraphBars(self.graph)
			end
			LayoutDetailColumns()
		end)

		detailFrame:SetScript("OnHide", function()
			detailFrame.actor = nil
			detailFrame.view = nil
			ClearGraphHighlight()
		end)

		if detailFrame.SetTemplate then
			detailFrame:SetTemplate("Transparent")
		end

		detailFrame.dragHandle = CreateFrame("Frame", nil, detailFrame)
		detailFrame.dragHandle:SetPoint("TOPLEFT", detailFrame, "TOPLEFT", 0, 0)
		detailFrame.dragHandle:SetPoint("TOPRIGHT", detailFrame, "TOPRIGHT", 0, 0)
		detailFrame.dragHandle:SetHeight(28)
		detailFrame.dragHandle:SetFrameLevel(detailFrame:GetFrameLevel() + 1)
		detailFrame.dragHandle:SetAlpha(0)
		detailFrame.dragHandle:EnableMouse(true)
		detailFrame.dragHandle:SetScript("OnMouseDown", function(_, button)
			if button == "LeftButton" then
				detailFrame:StartMoving()
			end
		end)
		detailFrame.dragHandle:SetScript("OnMouseUp", function(_, button)
			if button == "LeftButton" then
				detailFrame:StopMovingOrSizing()
				SaveDetailFramePosition()
			end
		end)

		detailFrame.resizeButton = CreateFrame("Button", nil, detailFrame)
		detailFrame.resizeButton:SetPoint("BOTTOMRIGHT", detailFrame, "BOTTOMRIGHT", -2, 2)
		detailFrame.resizeButton:SetSize(16, 16)
		detailFrame.resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
		detailFrame.resizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
		detailFrame.resizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
		detailFrame.resizeButton:SetScript("OnMouseDown", function(_, button)
			if button == "LeftButton" then
				detailFrame:StartSizing("BOTTOMRIGHT")
			end
		end)
		detailFrame.resizeButton:SetScript("OnMouseUp", function()
			detailFrame:StopMovingOrSizing()
			SaveDetailFrameSize()
			SaveDetailFramePosition()
		end)

		local container = CreateFrame("Frame", nil, detailFrame)
		container:SetPoint("TOPLEFT", detailFrame, "TOPLEFT", 12, -12)
		container:SetPoint("BOTTOMRIGHT", detailFrame, "BOTTOMRIGHT", -12, 12)
		detailFrame.container = container

		detailFrame.title = container:CreateFontString(nil, "OVERLAY")
		detailFrame.title:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
		detailFrame.title:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
		detailFrame.title:SetFont(E.media.normFont, 14, "OUTLINE")
		detailFrame.title:SetJustifyH("CENTER")

		detailFrame.summaryLeft = container:CreateFontString(nil, "OVERLAY")
		detailFrame.summaryLeft:SetFont(E.media.normFont, 12, "OUTLINE")
		detailFrame.summaryLeft:SetPoint("TOPLEFT", detailFrame.title, "BOTTOMLEFT", 0, -12)
		detailFrame.summaryLeft:SetPoint("RIGHT", container, "CENTER", -8, 0)
		detailFrame.summaryLeft:SetJustifyH("LEFT")

		detailFrame.summaryRight = container:CreateFontString(nil, "OVERLAY")
		detailFrame.summaryRight:SetFont(E.media.normFont, 12, "OUTLINE")
		detailFrame.summaryRight:SetPoint("TOPRIGHT", detailFrame.title, "BOTTOMRIGHT", 0, -12)
		detailFrame.summaryRight:SetPoint("LEFT", container, "CENTER", 8, 0)
		detailFrame.summaryRight:SetJustifyH("RIGHT")

		detailFrame.rate = container:CreateFontString(nil, "OVERLAY")
		detailFrame.rate:SetFont(E.media.normFont, 11, "OUTLINE")
		detailFrame.rate:SetPoint("TOPLEFT", detailFrame.summaryLeft, "BOTTOMLEFT", 0, -6)
		detailFrame.rate:SetPoint("RIGHT", container, "CENTER", -8, 0)
		detailFrame.rate:SetJustifyH("LEFT")

		detailFrame.others = container:CreateFontString(nil, "OVERLAY")
		detailFrame.others:SetFont(E.media.normFont, 11, "OUTLINE")
		detailFrame.others:SetPoint("TOPRIGHT", detailFrame.summaryRight, "BOTTOMRIGHT", 0, -6)
		detailFrame.others:SetPoint("LEFT", container, "CENTER", 8, 0)
		detailFrame.others:SetJustifyH("RIGHT")

		detailFrame.graphTitle = container:CreateFontString(nil, "OVERLAY")
		detailFrame.graphTitle:SetFont(E.media.normFont, 11, "OUTLINE")
		detailFrame.graphTitle:SetPoint("TOPLEFT", detailFrame.rate, "BOTTOMLEFT", 0, -10)
		detailFrame.graphTitle:SetText(LABEL_DAMAGE_TIMELINE)

		detailFrame.graph = CreateFrame("Frame", nil, container)
		detailFrame.graph:SetPoint("TOPLEFT", detailFrame.graphTitle, "BOTTOMLEFT", 0, -6)
		detailFrame.graph:SetPoint("TOPRIGHT", detailFrame.others, "BOTTOMRIGHT", 0, -6)
		detailFrame.graph:SetHeight(GRAPH_HEIGHT)
		detailFrame.graph.bg = detailFrame.graph:CreateTexture(nil, "BACKGROUND")
		detailFrame.graph.bg:SetAllPoints()
		detailFrame.graph.bg:SetColorTexture(0, 0, 0, 0.35)
		detailFrame.graph.bars = {}
		detailFrame.graph.highlight = detailFrame.graph:CreateTexture(nil, "ARTWORK")
		detailFrame.graph.highlight:SetAllPoints()
		detailFrame.graph.highlight:SetColorTexture(1, 1, 1, 0.08)
		detailFrame.graph.highlight:Hide()
		detailFrame.graph.placeholder = detailFrame.graph:CreateFontString(nil, "OVERLAY")
		detailFrame.graph.placeholder:SetFont(E.media.normFont, 10, "OUTLINE")
		detailFrame.graph.placeholder:SetPoint("CENTER", detailFrame.graph, "CENTER", 0, 0)
		detailFrame.graph.placeholder:SetText(L["No Timeline Data"] or "No Timeline Data")
		detailFrame.graph:SetScript("OnSizeChanged", LayoutGraphBars)
		LayoutGraphBars(detailFrame.graph)

		detailFrame.graphAverage = container:CreateFontString(nil, "OVERLAY")
		detailFrame.graphAverage:SetFont(E.media.normFont, 10, "OUTLINE")
		detailFrame.graphAverage:SetPoint("TOPLEFT", detailFrame.graph, "BOTTOMLEFT", 0, -4)
		detailFrame.graphAverage:SetJustifyH("LEFT")

		detailFrame.graphPeak = container:CreateFontString(nil, "OVERLAY")
		detailFrame.graphPeak:SetFont(E.media.normFont, 10, "OUTLINE")
		detailFrame.graphPeak:SetPoint("TOPRIGHT", detailFrame.graph, "BOTTOMRIGHT", 0, -4)
		detailFrame.graphPeak:SetJustifyH("RIGHT")

		detailFrame.graphHighlightLabel = container:CreateFontString(nil, "OVERLAY")
		detailFrame.graphHighlightLabel:SetFont(E.media.normFont, 10, "OUTLINE")
		detailFrame.graphHighlightLabel:SetPoint("TOP", detailFrame.graphAverage, "BOTTOM", 0, -4)
		detailFrame.graphHighlightLabel:SetText("")
		detailFrame.graphHighlightLabel:Hide()

		detailFrame.leftColumn = CreateFrame("Frame", nil, container)
		detailFrame.leftColumn:SetPoint("TOPLEFT", detailFrame.graphHighlightLabel, "BOTTOMLEFT", 0, -12)
		detailFrame.leftColumn:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, 12)
		detailFrame.leftColumn:SetPoint("RIGHT", container, "CENTER", -6, 0)

		detailFrame.rightColumn = CreateFrame("Frame", nil, container)
		detailFrame.rightColumn:SetPoint("TOPLEFT", detailFrame.leftColumn, "TOPRIGHT", 12, 0)
		detailFrame.rightColumn:SetPoint("BOTTOMLEFT", detailFrame.leftColumn, "BOTTOMRIGHT", 12, 0)
		detailFrame.rightColumn:SetPoint("RIGHT", container, "RIGHT", 0, 0)

		detailFrame.spellTitle = detailFrame.leftColumn:CreateFontString(nil, "OVERLAY")
		detailFrame.spellTitle:SetFont(E.media.normFont, 11, "OUTLINE")
		detailFrame.spellTitle:SetPoint("TOPLEFT", detailFrame.leftColumn, "TOPLEFT", 0, 0)
		detailFrame.spellTitle:SetPoint("TOPRIGHT", detailFrame.leftColumn, "TOPRIGHT", 0, 0)
		detailFrame.spellTitle:SetJustifyH("CENTER")
		detailFrame.spellTitle:SetText(LABEL_TOP_ABILITIES)

		detailFrame.lines = {}
		local previousLine = detailFrame.spellTitle
		for index = 1, DETAIL_MAX_LINES do
			local line = CreateFrame("Frame", nil, detailFrame.leftColumn)
			line:SetHeight(22)
			line:SetPoint("LEFT", detailFrame.leftColumn, "LEFT", 0, 0)
			line:SetPoint("RIGHT", detailFrame.leftColumn, "RIGHT", 0, 0)
			if index == 1 then
				line:SetPoint("TOP", previousLine, "BOTTOM", 0, -6)
			else
				line:SetPoint("TOP", previousLine, "BOTTOM", 0, -4)
			end
			previousLine = line

			line.bar = CreateFrame("StatusBar", nil, line)
			line.bar:SetAllPoints()
			line.bar:SetStatusBarTexture(E.media.normTex)
			line.bar:SetMinMaxValues(0, 1)
			line.bar:SetValue(0)
			line.bar:SetFrameLevel(line:GetFrameLevel() - 1)

			line.bg = line:CreateTexture(nil, "BACKGROUND")
			line.bg:SetAllPoints()
			line.bg:SetColorTexture(0, 0, 0, 0.35)

			line.rank = line:CreateFontString(nil, "OVERLAY")
			line.rank:SetFont(E.media.normFont, 11, "OUTLINE")
			line.rank:SetPoint("LEFT", line, "LEFT", 6, 0)
			line.rank:SetWidth(34)
			line.rank:SetJustifyH("LEFT")
			line.rank:SetWordWrap(false)
			line.rank:SetMaxLines(1)

			line.value = line:CreateFontString(nil, "OVERLAY")
			line.value:SetFont(E.media.normFont, 11, "OUTLINE")
			line.value:SetPoint("RIGHT", line, "RIGHT", -6, 0)
			line.value:SetWidth(140)
			line.value:SetJustifyH("RIGHT")
			line.value:SetWordWrap(false)
			line.value:SetMaxLines(1)

			line.name = line:CreateFontString(nil, "OVERLAY")
			line.name:SetFont(E.media.normFont, 11, "OUTLINE")
			line.name:SetPoint("LEFT", line.rank, "RIGHT", 4, 0)
			line.name:SetPoint("RIGHT", line.value, "LEFT", -6, 0)
			line.name:SetJustifyH("LEFT")
			line.name:SetWordWrap(false)
			line.name:SetMaxLines(1)

			line:EnableMouse(true)
			line:SetScript("OnEnter", DetailLine_OnEnter)
			line:SetScript("OnLeave", DetailLine_OnLeave)

			detailFrame.lines[index] = line
		end

		detailFrame.breakdownTitle = detailFrame.rightColumn:CreateFontString(nil, "OVERLAY")
		detailFrame.breakdownTitle:SetFont(E.media.normFont, 11, "OUTLINE")
		detailFrame.breakdownTitle:SetPoint("TOPLEFT", detailFrame.rightColumn, "TOPLEFT", 0, 0)
		detailFrame.breakdownTitle:SetPoint("TOPRIGHT", detailFrame.rightColumn, "TOPRIGHT", 0, 0)
		detailFrame.breakdownTitle:SetJustifyH("CENTER")
		detailFrame.breakdownTitle:SetText(LABEL_ATTACK_DETAILS)

		detailFrame.breakdownLines = {}
		local previousRow = detailFrame.breakdownTitle
		for index = 1, 4 do
			local row = CreateFrame("Frame", nil, detailFrame.rightColumn)
			row:SetHeight(20)
			row:SetPoint("LEFT", detailFrame.rightColumn, "LEFT", 0, 0)
			row:SetPoint("RIGHT", detailFrame.rightColumn, "RIGHT", 0, 0)
			if index == 1 then
				row:SetPoint("TOP", previousRow, "BOTTOM", 0, -6)
			else
				row:SetPoint("TOP", previousRow, "BOTTOM", 0, -4)
			end
			previousRow = row

			row.leftLabel = row:CreateFontString(nil, "OVERLAY")
			row.leftLabel:SetFont(E.media.normFont, 10, "OUTLINE")
			row.leftLabel:SetPoint("LEFT", row, "LEFT", 0, 0)
			row.leftLabel:SetJustifyH("LEFT")
			row.leftLabel:SetWordWrap(false)
			row.leftLabel:SetMaxLines(1)
			row.leftValue = row:CreateFontString(nil, "OVERLAY")
			row.leftValue:SetFont(E.media.normFont, 10, "OUTLINE")
			row.leftValue:SetPoint("LEFT", row.leftLabel, "RIGHT", 4, 0)
			row.leftValue:SetPoint("RIGHT", row, "CENTER", -8, 0)
			row.leftValue:SetJustifyH("RIGHT")
			row.leftValue:SetWordWrap(false)
			row.leftValue:SetMaxLines(1)

			row.rightLabel = row:CreateFontString(nil, "OVERLAY")
			row.rightLabel:SetFont(E.media.normFont, 10, "OUTLINE")
			row.rightLabel:SetPoint("LEFT", row, "CENTER", 8, 0)
			row.rightLabel:SetJustifyH("LEFT")
			row.rightLabel:SetWordWrap(false)
			row.rightLabel:SetMaxLines(1)
			row.rightValue = row:CreateFontString(nil, "OVERLAY")
			row.rightValue:SetFont(E.media.normFont, 10, "OUTLINE")
			row.rightValue:SetPoint("LEFT", row.rightLabel, "RIGHT", 4, 0)
			row.rightValue:SetPoint("RIGHT", row, "RIGHT", 0, 0)
			row.rightValue:SetJustifyH("RIGHT")
			row.rightValue:SetWordWrap(false)
			row.rightValue:SetMaxLines(1)

			detailFrame.breakdownLines[index] = row
		end

		detailFrame.missSummary = detailFrame.rightColumn:CreateFontString(nil, "OVERLAY")
		detailFrame.missSummary:SetFont(E.media.normFont, 10, "OUTLINE")
		detailFrame.missSummary:SetPoint("TOPLEFT", detailFrame.breakdownLines[#detailFrame.breakdownLines], "BOTTOMLEFT", 0, -8)
		detailFrame.missSummary:SetPoint("TOPRIGHT", detailFrame.breakdownLines[#detailFrame.breakdownLines], "BOTTOMRIGHT", 0, -8)
		detailFrame.missSummary:SetJustifyH("CENTER")

		if UISpecialFrames then
			tinsert(UISpecialFrames, detailFrame:GetName())
		end

		LayoutDetailColumns()
	end

	if detailFrame:IsShown() and detailFrame.actor == actor and detailFrame.view == view then
		HideDetailFrame(true)
		return
	end

	PositionDetailFrame()
	LayoutDetailColumns()

	detailFrame.actor = actor
	detailFrame.view = view
	detailFrame:Show()
	UpdateDetailFrame()
	LayoutDetailColumns()
end

local function CreateSegmentListFrame(parent)
	if segmentListFrame then
		return segmentListFrame
	end

	segmentListFrame = CreateFrame("Frame", "MERCombatMeterSegmentList", parent, "BackdropTemplate")
	segmentListFrame:SetHeight((ROW_HEIGHT + 2) * (ROW_COUNT / 2))
	segmentListFrame:SetFrameStrata(parent:GetFrameStrata())
	segmentListFrame:SetFrameLevel(parent:GetFrameLevel() + 5)
	segmentListFrame:Hide()

	if segmentListFrame.SetTemplate then
		segmentListFrame:SetTemplate("Transparent")
	end

	segmentListFrame.buttons = {}
	return segmentListFrame
end

local function CreateViewFlyout(parent)
	if viewFlyoutFrame then
		return viewFlyoutFrame
	end

	viewFlyoutFrame = CreateFrame("Frame", "MERCombatMeterViewFlyout", parent, "BackdropTemplate")
	viewFlyoutFrame:SetHeight((ROW_HEIGHT + 2) * (#viewOrder))
	viewFlyoutFrame:SetWidth(160)
	viewFlyoutFrame:SetFrameStrata(parent:GetFrameStrata())
	viewFlyoutFrame:SetFrameLevel(parent:GetFrameLevel() + 6)
	viewFlyoutFrame:Hide()

	if viewFlyoutFrame.SetTemplate then
		viewFlyoutFrame:SetTemplate("Transparent")
	end

	viewFlyoutFrame.buttons = {}
	return viewFlyoutFrame
end

local function SetDisplayedSegment(segment)
	if not segment then
		return
	end

	module.displayedSegment = segment
	if meterFrame then
		meterFrame.segment = segment
		if meterFrame.segmentLabel then
			meterFrame.segmentLabel:SetText(FormatSegmentName(segment))
		end
	end

	if segmentListFrame and segmentListFrame:IsShown() then
		UpdateSegmentList()
	end

	HideDetailFrame(true)
	module:RefreshCombatMeterDisplay(true)
end

local function UpdateSegmentList()
	if not meterFrame then
		return
	end

	local listFrame = CreateSegmentListFrame(meterFrame)
	if not listFrame then
		return
	end

	listFrame:ClearAllPoints()
	if meterFrame.segmentButton then
		listFrame:SetPoint("TOPLEFT", meterFrame.segmentButton, "BOTTOMLEFT", -4, -4)
		listFrame:SetWidth(240)
	else
		listFrame:SetPoint("TOPLEFT", meterFrame, "TOPLEFT", 0, -30)
		listFrame:SetWidth(240)
	end

	local segments = {}
	segments[#segments + 1] = module.currentSegment
	for _, segment in ipairs(module.segmentHistory) do
		segments[#segments + 1] = segment
	end

	local availableButtons = #listFrame.buttons
	local requiredButtons = #segments
	for index = availableButtons + 1, requiredButtons do
		local button = CreateFrame("Button", nil, listFrame, "BackdropTemplate")
		button:SetHeight(20)
		button:SetPoint("LEFT", listFrame, "LEFT", 4, 0)
		button:SetPoint("RIGHT", listFrame, "RIGHT", -4, 0)
		if index == 1 then
			button:SetPoint("TOP", listFrame, "TOP", 0, -4)
		else
			button:SetPoint("TOP", listFrame.buttons[index - 1], "BOTTOM", 0, -2)
		end
		if button.SetTemplate then
			button:SetTemplate("Transparent")
		end

		button:SetScript("OnClick", function(self)
			SetDisplayedSegment(self.segment)
			listFrame:Hide()
		end)

		button.label = button:CreateFontString(nil, "OVERLAY")
		button.label:SetFont(E.media.normFont, 11, "OUTLINE")
		button.label:SetPoint("LEFT", button, "LEFT", 6, 0)
		button.label:SetJustifyH("LEFT")

		button.value = button:CreateFontString(nil, "OVERLAY")
		button.value:SetFont(E.media.normFont, 11, "OUTLINE")
		button.value:SetPoint("RIGHT", button, "RIGHT", -6, 0)
		button.value:SetJustifyH("RIGHT")

		listFrame.buttons[index] = button
	end

	for index, button in ipairs(listFrame.buttons) do
		local segment = segments[index]
		if segment then
			button.segment = segment
			local duration = GetSegmentDuration(segment)
			local label = FormatSegmentName(segment)
			button.label:SetText(label)

			local mainValue = segment.totalDamage > 0 and ShortValue(segment.totalDamage, 1)
				or (segment.totalHealing > 0 and ShortValue(segment.totalHealing, 1))
				or FormatDuration(duration)

			button.value:SetText(mainValue)
			button:Show()

			if segment == module.displayedSegment then
				button.label:SetTextColor(1, 0.82, 0.2)
				button.value:SetTextColor(1, 0.82, 0.2)
			else
				button.label:SetTextColor(0.85, 0.85, 0.85)
				button.value:SetTextColor(0.75, 0.75, 0.75)
			end
		else
			button.segment = nil
			button:Hide()
		end
	end
end

local function ToggleSegmentList()
	if not meterFrame then
		return
	end

	if viewFlyoutFrame then
		viewFlyoutFrame:Hide()
	end

	if GameTooltip and meterFrame.segmentButton and GameTooltip:IsOwned(meterFrame.segmentButton) then
		GameTooltip:Hide()
	end

	local listFrame = CreateSegmentListFrame(meterFrame)
	if not listFrame then
		return
	end

	if listFrame:IsShown() then
		listFrame:Hide()
	else
		UpdateSegmentList()
		listFrame:Show()
	end
end

local function UpdateViewFlyout()
	if not meterFrame then
		return
	end

	local flyout = CreateViewFlyout(meterFrame)
	if not flyout then
		return
	end

	flyout:ClearAllPoints()
	if meterFrame.viewButton then
		flyout:SetPoint("TOPLEFT", meterFrame.viewButton, "BOTTOMLEFT", -2, -4)
	else
		flyout:SetPoint("TOPLEFT", meterFrame, "TOPLEFT", 4, -30)
	end

	local availableButtons = #flyout.buttons
	local requiredButtons = #viewOrder
	for index = availableButtons + 1, requiredButtons do
		local button = CreateFrame("Button", nil, flyout, "BackdropTemplate")
		button:SetHeight(20)
		button:SetPoint("LEFT", flyout, "LEFT", 4, 0)
		button:SetPoint("RIGHT", flyout, "RIGHT", -4, 0)
		if index == 1 then
			button:SetPoint("TOP", flyout, "TOP", 0, -4)
		else
			button:SetPoint("TOP", flyout.buttons[index - 1], "BOTTOM", 0, -2)
		end

		if button.SetTemplate then
			button:SetTemplate("Transparent")
		end

		button.icon = button:CreateTexture(nil, "ARTWORK")
		button.icon:SetSize(16, 16)
		button.icon:SetPoint("LEFT", button, "LEFT", 6, 0)

		button.label = button:CreateFontString(nil, "OVERLAY")
		button.label:SetFont(E.media.normFont, 11, "OUTLINE")
		button.label:SetPoint("LEFT", button.icon, "RIGHT", 6, 0)
		button.label:SetJustifyH("LEFT")

		button:SetScript("OnClick", function(self)
			if meterFrame then
				meterFrame.activeView = self.viewKey
				UpdateViewButtonState()
			end
			HideDetailFrame(true)
			module:RefreshCombatMeterDisplay(true)
			flyout:Hide()
		end)

		flyout.buttons[index] = button
	end

	for index, button in ipairs(flyout.buttons) do
		local viewKey = viewOrder[index]
		if viewKey then
			button.viewKey = viewKey
			button.icon:SetTexture(viewIcons[viewKey] or viewIcons.damage)
			button.label:SetText(viewLabels[viewKey] or viewKey)

			if meterFrame and meterFrame.activeView == viewKey then
				button.label:SetTextColor(1, 0.82, 0.2)
				button.icon:SetVertexColor(1, 1, 1)
			else
				button.label:SetTextColor(0.85, 0.85, 0.85)
				button.icon:SetVertexColor(0.9, 0.9, 0.9)
			end

			button:Show()
		else
			button:Hide()
		end
	end
end

local function ToggleViewFlyout()
	if not meterFrame then
		return
	end

	if segmentListFrame then
		segmentListFrame:Hide()
	end

	if GameTooltip and meterFrame.viewButton and GameTooltip:IsOwned(meterFrame.viewButton) then
		GameTooltip:Hide()
	end

	local flyout = CreateViewFlyout(meterFrame)
	if not flyout then
		return
	end

	if flyout:IsShown() then
		flyout:Hide()
	else
		UpdateViewFlyout()
		flyout:Show()
	end
end

function module:RefreshCombatMeterDisplay(force)
	local displayedSegment = GetDisplayedSegment()
	if not displayedSegment or not meterFrame or not meterFrame:IsShown() then
		return
	end

	if not force and displayedSegment ~= module.currentSegment then
		-- If viewing history, we only update when forced
		return
	end

	local view = meterFrame.activeView or "damage"
	local actors = BuildSortedList(displayedSegment, view)
	local duration = max(1, GetSegmentDuration(displayedSegment))
	local total = 0

	if view == "damage" then
		total = displayedSegment.totalDamage
	elseif view == "healing" then
		total = displayedSegment.totalHealing
	elseif view == "threat" then
		total = displayedSegment.totalThreat
	elseif view == "dispels" then
		total = displayedSegment.totalDispels
	elseif view == "deaths" then
		for _, actor in pairs(displayedSegment.actors) do
			total = total + (actor.deaths or 0)
		end
	end

	local maxValue = 0
	for _, actor in ipairs(actors) do
		maxValue = max(maxValue, actor[view] or 0)
	end
	if maxValue <= 0 then
		maxValue = 1
	end

	for index = 1, ROW_COUNT do
		local row = rows[index]
		local actor = actors[index]
		if actor then
			local value = actor[view] or 0
			row.data = actor
			row.segment = displayedSegment
			row.viewKey = view
			row:Show()
			row.left:SetText(format("%d. %s", index, actor.name or UNKNOWN_ACTOR))
			row.right:SetText(FormatRowValue(displayedSegment, view, value, total, duration))
			row.bar:SetMinMaxValues(0, 1)
			row.bar:SetValue(maxValue > 0 and (value / maxValue) or 0)
			row.bar:SetStatusBarColor(ActorColor(actor))
		else
			row.data = nil
			row.segment = nil
			row:Hide()
		end
	end

	if meterFrame.emptyLabel then
		meterFrame.emptyLabel:SetShown(#actors == 0)
	end

	UpdateDetailFrame()
end

local function Row_OnEnter(frame)
	if not frame.data then
		HideHoverGraph()
		return
	end

	local actor = frame.data
	local view = frame.viewKey or "damage"
	local segment = frame.segment or GetDisplayedSegment()

	GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
	GameTooltip:SetText(actor.name or UNKNOWN_ACTOR)

	local displayedSegment = segment or module.currentSegment
	local duration = max(1, GetSegmentDuration(displayedSegment))
	local total = 0

	if view == "damage" then
		total = displayedSegment.totalDamage
	elseif view == "healing" then
		total = displayedSegment.totalHealing
	elseif view == "threat" then
		total = displayedSegment.totalThreat
	elseif view == "dispels" then
		total = displayedSegment.totalDispels
	elseif view == "deaths" then
		for _, data in pairs(displayedSegment.actors) do
			total = total + (data.deaths or 0)
		end
	end

	local value = actor[view] or 0
	local percent = total > 0 and (value / total) * 100 or 0
	local rate = ""

	if view == "damage" then
		rate = format("%s DPS", FormatRate(value / duration))
	elseif view == "healing" then
		rate = format("%s HPS", FormatRate(value / duration))
	end

	GameTooltip:AddLine(format("%s: %s", viewLabels[view] or view, ShortValue(value, 1)), 0.9, 0.9, 0.9)
	GameTooltip:AddLine(format("Share: %.1f%%", percent), 0.7, 0.7, 0.7)
	if rate ~= "" then
		GameTooltip:AddLine(rate, 0.7, 0.7, 0.7)
	end

	PopulateTooltipLines(GameTooltip, displayedSegment, actor, view)
	GameTooltip:Show()

	ShowHoverGraph(frame, actor, view)
end

local function Row_OnLeave()
	GameTooltip_Hide()
	HideHoverGraph()
end

local function Row_OnClick(frame)
	if not frame.data or not frame.viewKey then
		return
	end
	ShowDetailFrame(frame.data, frame.viewKey)
end

local function CreateRow(parent, index)
	local row = CreateFrame("Button", nil, parent)
	row:SetHeight(ROW_HEIGHT)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((index - 1) * (ROW_HEIGHT + ROW_SPACING)))
	row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -((index - 1) * (ROW_HEIGHT + ROW_SPACING)))
	row:EnableMouse(true)
	row:RegisterForClicks("LeftButtonUp")

	local statusBar = CreateFrame("StatusBar", nil, row)
	statusBar:SetAllPoints()
	statusBar:SetStatusBarTexture(E.media.normTex)
	statusBar:SetMinMaxValues(0, 1)
	statusBar:SetValue(0)
	statusBar:SetStatusBarColor(0.2, 0.6, 1, 0.75)
	row.bar = statusBar

	local background = row:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(0, 0, 0, 0.35)
	row.bg = background

	local left = row:CreateFontString(nil, "OVERLAY")
	left:SetPoint("LEFT", row, "LEFT", 6, 0)
	left:SetFont(E.media.normFont, 12, "OUTLINE")
	left:SetJustifyH("LEFT")
	row.left = left

	local right = row:CreateFontString(nil, "OVERLAY")
	right:SetPoint("RIGHT", row, "RIGHT", -6, 0)
	right:SetFont(E.media.normFont, 11, "OUTLINE")
	right:SetJustifyH("RIGHT")
	row.right = right

	row:SetScript("OnEnter", Row_OnEnter)
	row:SetScript("OnLeave", Row_OnLeave)
	row:SetScript("OnClick", Row_OnClick)
	row:Hide()

	return row
end

local function Meter_OnUpdate(self, elapsed)
	self.elapsed = (self.elapsed or 0) + elapsed
	if self.elapsed < 0.5 then
		return
	end
	self.elapsed = 0

	if module.displayedSegment ~= module.currentSegment then
		return
	end

	module:RefreshCombatMeterDisplay(true)
end

local function GetMeterParent()
	return _G.RightChatPanel or E.UIParent
end

local function PositionMeter()
	if not meterFrame then
		return
	end

	local parent = GetMeterParent()
	meterFrame:SetParent(parent)
	meterFrame:ClearAllPoints()

	if parent == E.UIParent then
		meterFrame:SetPoint("BOTTOMRIGHT", E.UIParent, "BOTTOMRIGHT", -8, 46)
		meterFrame:SetSize(350, 220)
	else
	local leftInset, rightInset, topInset, bottomInset = 2, 2, 2, 2
	if parent.backdrop and parent.backdrop.insets then
		leftInset = parent.backdrop.insets.left or leftInset
		rightInset = parent.backdrop.insets.right or rightInset
		topInset = parent.backdrop.insets.top or topInset
		bottomInset = parent.backdrop.insets.bottom or bottomInset
	end

	meterFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", leftInset, -topInset)
	meterFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -rightInset, bottomInset)
	end
	if detailFrame and not detailFrame.savedPosition then
		PositionDetailFrame()
	end
end

UpdateViewButtonState = function()
	if not meterFrame or not meterFrame.viewButton then
		return
	end

	local view = meterFrame.activeView or "damage"
	local icon = viewIcons[view] or viewIcons.damage
	local label = viewLabels[view] or view

	if meterFrame.viewButton.icon then
		meterFrame.viewButton.icon:SetTexture(icon)
	end

	if meterFrame.viewText then
		meterFrame.viewText:SetText(label)
	end

	if viewFlyoutFrame and viewFlyoutFrame:IsShown() then
		UpdateViewFlyout()
	end
end

function module:CreateCombatMeterFrame()
	if meterFrame then
		PositionMeter()
		return
	end

	if not module.currentSegment then
		module.currentSegment = CreateSegment(true)
	else
		module.currentSegment.actors = module.currentSegment.actors or {}
	end
	ResetSegmentData(module.currentSegment)
	if not module.displayedSegment then
		module.displayedSegment = module.currentSegment
	end

	local parent = GetMeterParent()
	meterFrame = CreateFrame("Frame", "MERCombatMeter", parent, "BackdropTemplate")
	meterFrame:SetFrameStrata(parent:GetFrameStrata())
	meterFrame:SetFrameLevel(parent:GetFrameLevel() + 5)
	meterFrame:EnableMouse(true)

	if meterFrame.SetTemplate then
		meterFrame:SetTemplate("Transparent")
	end

	meterFrame.activeView = "damage"
	meterFrame.segment = module.displayedSegment

	PositionMeter()

	local header = CreateFrame("Frame", nil, meterFrame)
	header:SetPoint("TOPLEFT", meterFrame, "TOPLEFT", 4, -4)
	header:SetPoint("TOPRIGHT", meterFrame, "TOPRIGHT", -4, -4)
	header:SetHeight(26)
	meterFrame.header = header

	local viewButton = CreateFrame("Button", nil, header, "BackdropTemplate")
	viewButton:SetSize(24, 24)
	viewButton:SetPoint("LEFT", header, "LEFT", 0, 0)
	if viewButton.SetTemplate then
		viewButton:SetTemplate("Transparent")
	end
	viewButton:SetScript("OnClick", ToggleViewFlyout)
	viewButton:SetScript("OnEnter", function()
		GameTooltip:SetOwner(viewButton, "ANCHOR_TOPLEFT")
		GameTooltip:SetText(L["View"] or "View")
		GameTooltip:AddLine(L["Select which metric to display."] or "Select which metric to display.", 0.8, 0.8, 0.8, true)
		GameTooltip:Show()
	end)
	viewButton:SetScript("OnLeave", GameTooltip_Hide)

	local viewIcon = viewButton:CreateTexture(nil, "ARTWORK")
	viewIcon:SetAllPoints()
	viewIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	viewButton.icon = viewIcon
	meterFrame.viewButton = viewButton

	local viewText = header:CreateFontString(nil, "OVERLAY")
	viewText:SetFont(E.media.normFont, 12, "OUTLINE")
	viewText:SetPoint("LEFT", viewButton, "RIGHT", 6, 0)
	viewText:SetJustifyH("LEFT")
	viewText:SetTextColor(1, 0.96, 0.41)
	meterFrame.viewText = viewText

	local segmentButton = CreateFrame("Button", nil, header, "BackdropTemplate")
	segmentButton:SetSize(24, 24)
	segmentButton:SetPoint("LEFT", viewText, "RIGHT", 12, 0)
	if segmentButton.SetTemplate then
		segmentButton:SetTemplate("Transparent")
	end
	segmentButton:SetScript("OnClick", ToggleSegmentList)
	segmentButton:SetScript("OnEnter", function()
		GameTooltip:SetOwner(segmentButton, "ANCHOR_TOPLEFT")
		GameTooltip:SetText(LABEL_SEGMENTS)
		GameTooltip:AddLine(L["Switch between recent fights."] or "Switch between recent fights.", 0.8, 0.8, 0.8, true)
		GameTooltip:Show()
	end)
	segmentButton:SetScript("OnLeave", GameTooltip_Hide)

	local segmentIcon = segmentButton:CreateTexture(nil, "ARTWORK")
	segmentIcon:SetAllPoints()
	segmentIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	segmentIcon:SetTexture(segmentIconTexture)
	segmentButton.icon = segmentIcon
	meterFrame.segmentButton = segmentButton

	local segmentLabel = header:CreateFontString(nil, "OVERLAY")
	segmentLabel:SetFont(E.media.normFont, 11, "OUTLINE")
	segmentLabel:SetPoint("LEFT", segmentButton, "RIGHT", 6, 0)
	segmentLabel:SetPoint("RIGHT", header, "RIGHT", -4, 0)
	segmentLabel:SetJustifyH("LEFT")
	segmentLabel:SetText(FormatSegmentName(module.displayedSegment))
	meterFrame.segmentLabel = segmentLabel

	local content = CreateFrame("Frame", nil, meterFrame)
	content:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)
	content:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -6)
	content:SetPoint("BOTTOMLEFT", meterFrame, "BOTTOMLEFT", 4, 4)
	content:SetPoint("BOTTOMRIGHT", meterFrame, "BOTTOMRIGHT", -4, 4)
	meterFrame.content = content

	for index = 1, ROW_COUNT do
		rows[index] = CreateRow(content, index)
	end

	local emptyLabel = content:CreateFontString(nil, "OVERLAY")
	emptyLabel:SetPoint("CENTER", content, "CENTER", 0, 0)
	emptyLabel:SetFont(E.media.normFont, 12, "OUTLINE")
	emptyLabel:SetText(LABEL_NO_DATA)
	emptyLabel:Hide()
	meterFrame.emptyLabel = emptyLabel

	UpdateViewButtonState()
	meterFrame:SetScript("OnUpdate", Meter_OnUpdate)
	meterFrame:SetScript("OnHide", function()
		if segmentListFrame then
			segmentListFrame:Hide()
		end
		if viewFlyoutFrame then
			viewFlyoutFrame:Hide()
		end
		HideDetailFrame(true)
		GameTooltip_Hide()
		HideHoverGraph()
	end)
	meterFrame:Hide()
end

local function IterateGroupUnits(callback)
	callback("player")
	callback("pet")

	if IsInRaid() then
		for index = 1, GetNumGroupMembers() do
			callback("raid" .. index)
			callback("raid" .. index .. "pet")
		end
	elseif IsInGroup() then
		for index = 1, GetNumSubgroupMembers() do
			callback("party" .. index)
			callback("party" .. index .. "pet")
		end
	end
end

function module:CombatMeterUpdateRoster()
	if not self.meterEnabled then
		return
	end

	local segment = self.currentSegment
	if not segment then
		return
	end

	IterateGroupUnits(function(unit)
		if UnitExists(unit) then
			local guid = UnitGUID(unit)
			if guid then
				local name = UnitName(unit)
				local _, class = UnitClass(unit)
				local actor = EnsureActor(segment, guid, name, class)
				if actor then
					actor.unit = unit
				end
			end
		end
	end)

	self:RefreshCombatMeterDisplay(true)
end

local function UpdateThreatData()
	if not module.meterEnabled then
		return
	end

	local segment = module.currentSegment
	if not segment then
		return
	end

	local highest = 0
	local totalThreat = 0

	if not UnitExists("target") then
		segment.highestThreat = 0
		segment.totalThreat = 0
		for _, actor in pairs(segment.actors) do
			actor.threat = 0
		end
		return
	end

	IterateGroupUnits(function(unit)
		if UnitExists(unit) then
			local guid = UnitGUID(unit)
			if guid then
				local name = UnitName(unit)
				local _, class = UnitClass(unit)
				local actor = EnsureActor(segment, guid, name, class)
				if actor then
					local _, _, threatPct, _, threatValue = UnitDetailedThreatSituation(unit, "target")
					actor.threat = threatValue or 0
					if actor.threat > highest then
						highest = actor.threat
					end
					totalThreat = totalThreat + actor.threat
				end
			end
		end
	end)

	segment.highestThreat = highest
	segment.totalThreat = totalThreat
end

function module:CombatMeterThreatUpdate()
	if not self.meterEnabled then
		return
	end

	UpdateThreatData()
	self:RefreshCombatMeterDisplay(true)
end

local function StoreCurrentSegment()
	local segment = module.currentSegment
	if not segment or not SegmentHasActivity(segment) then
		return
	end

	local snapshot = CloneSegment(segment)
	snapshot.name = segment.lastEnemyName or segment.name or LABEL_CURRENT_FIGHT
	snapshot.endTime = snapshot.endTime or (segment.endTime or GetTime())
	snapshot.duration = GetSegmentDuration(snapshot)

	table.insert(module.segmentHistory, 1, snapshot)
	while #module.segmentHistory > SEGMENT_LIMIT do
		table.remove(module.segmentHistory)
	end

	UpdateSegmentList()
end

local function BeginNewSegment()
	if not module.currentSegment then
		module.currentSegment = CreateSegment(true)
	else
		module.currentSegment = CreateSegment(true)
	end

	if not module.displayedSegment or module.displayedSegment.isCurrent then
		SetDisplayedSegment(module.currentSegment)
	else
		-- Keep displaying history; ensure buttons update
		if meterFrame and meterFrame.segmentLabel then
			meterFrame.segmentLabel:SetText(FormatSegmentName(module.displayedSegment))
		end
	end

	UpdateSegmentList()
end

function module:CombatMeterStart()
	if not self.meterEnabled then
		return
	end

	BeginNewSegment()
	self:CombatMeterUpdateRoster()
	UpdateThreatData()
	self:RefreshCombatMeterDisplay(true)
end

function module:CombatMeterStop()
	if not self.meterEnabled then
		return
	end

	local segment = self.currentSegment
	if segment then
		segment.endTime = GetTime()
		if segment.lastEnemyName and segment.lastEnemyName ~= "" then
			segment.name = segment.lastEnemyName
		else
			segment.name = LABEL_CURRENT_FIGHT
		end
	end

	if meterFrame then
		meterFrame.elapsed = 0
	end

	StoreCurrentSegment()
	self:RefreshCombatMeterDisplay(true)
end

local function TrackEnemyName(segment, destName, destFlags)
	if not destName or destName == "" or not destFlags then
		return
	end

	if band(destFlags, FRIENDLY_FLAG) ~= 0 then
		return
	end

	if band(destFlags, HOSTILE_FLAG) == 0 then
		return
	end

	segment.lastEnemyName = CleanName(destName)
end

local function HandleDamageEvent(segment, subEvent, info, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags)
	if not IsTracked(sourceFlags) then
		return
	end

	local amount, spellId, spellName
	if subEvent == "SWING_DAMAGE" then
		amount = info[12]
		spellId = 6603
		spellName = _G.MELEE or "Melee"
	else
		spellId = info[12]
		spellName = info[13]
		amount = info[15]
	end

	if not amount or amount <= 0 then
		return
	end

	local actor = EnsureActor(segment, sourceGUID, sourceName)
	if not actor then
		return
	end

	local isCrit, isGlancing, isCrushing = ExtractHitFlags(subEvent, info)
	actor.damage = (actor.damage or 0) + amount
	segment.totalDamage = segment.totalDamage + amount

	AddSpellAmount(actor.damageSpells, spellId, spellName, amount, isCrit)
	TrackDamageTimeline(actor, segment, amount)
	TrackOutcome(actor, GetOutcomeKey(subEvent, isCrit, isGlancing, isCrushing))
	TrackEnemyName(segment, destName, destFlags)
end

local function HandleHealingEvent(segment, subEvent, info, sourceGUID, sourceName, sourceFlags)
	if not IsTracked(sourceFlags) then
		return
	end

	local amount = info[15]
	if not amount or amount <= 0 then
		return
	end

	local spellId = info[12]
	local spellName = info[13]
	local isCrit = info[21] or false

	local actor = EnsureActor(segment, sourceGUID, sourceName)
	if not actor then
		return
	end

	actor.healing = (actor.healing or 0) + amount
	segment.totalHealing = segment.totalHealing + amount
	AddSpellAmount(actor.healingSpells, spellId, spellName, amount, isCrit)
end

local function HandleDispelEvent(segment, info, sourceGUID, sourceName, sourceFlags)
	if not IsTracked(sourceFlags) then
		return
	end

	local spellId = info[12]
	local spellName = info[13]
	local extraSpellName = info[15]

	local actor = EnsureActor(segment, sourceGUID, sourceName)
	if not actor then
		return
	end

	actor.dispels = (actor.dispels or 0) + 1
	segment.totalDispels = segment.totalDispels + 1
	AddSpellAmount(actor.dispelSpells, spellId, spellName, 0, false, extraSpellName or "_")
end

local function HandleDeathEvent(segment, destGUID, destName, destFlags)
	if not IsTracked(destFlags) then
		return
	end

	local actor = EnsureActor(segment, destGUID, destName)
	if actor then
		actor.deaths = (actor.deaths or 0) + 1
	end
end

local function HandleMissEvent(segment, subEvent, info, sourceGUID, sourceName, sourceFlags)
	if not IsTracked(sourceFlags) then
		return
	end

	local missType
	if subEvent == "SWING_MISSED" then
		missType = info[12]
	else
		missType = info[15]
	end

	local actor = EnsureActor(segment, sourceGUID, sourceName)
	if not actor then
		return
	end

	TrackOutcome(actor, NormalizeMissType(missType))
end

function module:CombatMeterLogEvent()
	if not self.meterEnabled then
		return
	end

	local info = { CombatLogGetCurrentEventInfo() }
	local subEvent = info[2]
	local sourceGUID = info[4]
	local sourceName = info[5]
	local sourceFlags = info[6]
	local destGUID = info[8]
	local destName = info[9]
	local destFlags = info[10]

	local segment = self.currentSegment
	if not segment then
		return
	end

	if damageEvents[subEvent] then
		HandleDamageEvent(segment, subEvent, info, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags)
	elseif healingEvents[subEvent] then
		HandleHealingEvent(segment, subEvent, info, sourceGUID, sourceName, sourceFlags)
	elseif dispelEvents[subEvent] then
		HandleDispelEvent(segment, info, sourceGUID, sourceName, sourceFlags)
	elseif deathEvents[subEvent] then
		HandleDeathEvent(segment, destGUID, destName, destFlags)
	elseif missEvents[subEvent] then
		HandleMissEvent(segment, subEvent, info, sourceGUID, sourceName, sourceFlags)
	end
end

function module:EnableCombatMeter()
	if self.meterEnabled then
		return
	end

	self:CreateCombatMeterFrame()
	if meterFrame then
		UpdateViewButtonState()
		if meterFrame.segmentLabel then
			local segment = module.displayedSegment or module.currentSegment
			if segment then
				meterFrame.segmentLabel:SetText(FormatSegmentName(segment))
			end
		end
	end

	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", "CombatMeterLogEvent")
	self:RegisterEvent("PLAYER_REGEN_DISABLED", "CombatMeterStart")
	self:RegisterEvent("PLAYER_REGEN_ENABLED", "CombatMeterStop")
	self:RegisterEvent("GROUP_ROSTER_UPDATE", "CombatMeterUpdateRoster")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "CombatMeterUpdateRoster")
	self:RegisterEvent("PLAYER_TARGET_CHANGED", "CombatMeterThreatUpdate")
	self:RegisterEvent("UNIT_THREAT_LIST_UPDATE", "CombatMeterThreatUpdate")
	self:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE", "CombatMeterThreatUpdate")

	if meterFrame then
		meterFrame:Show()
		meterFrame.elapsed = 0
		meterFrame:SetScript("OnUpdate", Meter_OnUpdate)
	end

	if not self.currentSegment then
		self.currentSegment = CreateSegment(true)
	end

	self.meterEnabled = true
	self:CombatMeterUpdateRoster()
	self:CombatMeterThreatUpdate()
	self:RefreshCombatMeterDisplay(true)
end

function module:DisableCombatMeter()
	if not self.meterEnabled then
		return
	end

	self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	self:UnregisterEvent("PLAYER_REGEN_DISABLED")
	self:UnregisterEvent("PLAYER_REGEN_ENABLED")
	self:UnregisterEvent("GROUP_ROSTER_UPDATE")
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	self:UnregisterEvent("PLAYER_TARGET_CHANGED")
	self:UnregisterEvent("UNIT_THREAT_LIST_UPDATE")
	self:UnregisterEvent("UNIT_THREAT_SITUATION_UPDATE")

	if meterFrame then
		meterFrame:SetScript("OnUpdate", nil)
		meterFrame:Hide()
	end

	if segmentListFrame then
		segmentListFrame:Hide()
	end

	if viewFlyoutFrame then
		viewFlyoutFrame:Hide()
	end

	HideDetailFrame(true)
	self.meterEnabled = false
end

function module:CombatMeter()
	if not E.db.mui.misc.combatMeter then
		self:DisableCombatMeter()
		return
	end

	self:EnableCombatMeter()
end

module:AddCallback("CombatMeter")
module:AddCallbackForUpdate("CombatMeter")
