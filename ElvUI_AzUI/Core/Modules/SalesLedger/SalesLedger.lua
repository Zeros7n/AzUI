local MER, F, E, L, V, P, G = unpack(ElvUI_AzUI)
local module = MER:GetModule('MER_SalesLedger')

local _G = _G
local abs = math.abs
local floor = math.floor
local max = math.max
local min = math.min
local tinsert = table.insert
local tremove = table.remove

local date = date
local time = time

local GetMoney = GetMoney
local GetItemInfo = GetItemInfo
local GetItemInfoInstant = GetItemInfoInstant
local GetAuctionDeposit = GetAuctionDeposit
local GetAuctionSellItemInfo = GetAuctionSellItemInfo
local GetAuctionItemInfo = GetAuctionItemInfo
local GetAuctionItemLink = GetAuctionItemLink
local GetInboxHeaderInfo = GetInboxHeaderInfo
local GetInboxInvoiceInfo = GetInboxInvoiceInfo
local GetInboxItem = GetInboxItem
local GetInboxItemLink = GetInboxItemLink
local GetSendMailPrice = GetSendMailPrice
local GetMerchantItemInfo = GetMerchantItemInfo
local GetMerchantItemLink = GetMerchantItemLink
local GetBuybackItemInfo = GetBuybackItemInfo
local GetBuybackItemLink = GetBuybackItemLink
local GetTrainerServiceCost = GetTrainerServiceCost
local GetRepairAllCost = GetRepairAllCost
local GetPlayerTradeMoney = GetPlayerTradeMoney
local GetTargetTradeMoney = GetTargetTradeMoney
local TaxiNodeCost = TaxiNodeCost

local GetContainerItemInfo = C_Container and C_Container.GetContainerItemInfo or GetContainerItemInfo
local GetContainerItemLink = C_Container and C_Container.GetContainerItemLink or GetContainerItemLink

local AUCTION_CUT_RATE = 0.05

local CATEGORIES = {
	QUEST = "quest",
	LOOT = "loot",
	VENDOR_SALE = "vendorSale",
	VENDOR_PURCHASE = "vendorPurchase",
	AUCTION_SALE = "auctionSale",
	AUCTION_PURCHASE = "auctionPurchase",
	AUCTION_EXPIRED = "auctionExpired",
	AUCTION_CANCELED = "auctionCanceled",
	MAIL = "mail",
	TRADE = "trade",
	COD = "cod",
	REPAIR = "repair",
	TAXI = "taxi",
	TRAINING = "training",
	RESPEC = "respec",
	GUILD_REPAIR = "guildRepair",
	GUILD_BANK = "guildBank",
	OTHER = "other",
}

local CATEGORY_LABELS = {
	[CATEGORIES.QUEST] = L["Quest"],
	[CATEGORIES.LOOT] = L["Loot"],
	[CATEGORIES.VENDOR_SALE] = L["Vendor Sale"],
	[CATEGORIES.VENDOR_PURCHASE] = L["Vendor Purchase"],
	[CATEGORIES.AUCTION_SALE] = L["Auction Sale"],
	[CATEGORIES.AUCTION_PURCHASE] = L["Auction Purchase"],
	[CATEGORIES.AUCTION_EXPIRED] = L["Auction Expired"],
	[CATEGORIES.AUCTION_CANCELED] = L["Auction Canceled"],
	[CATEGORIES.MAIL] = L["Mail"],
	[CATEGORIES.TRADE] = L["Trade"],
	[CATEGORIES.COD] = L["COD"],
	[CATEGORIES.REPAIR] = L["Repair"],
	[CATEGORIES.TAXI] = L["Taxi"],
	[CATEGORIES.TRAINING] = L["Training"],
	[CATEGORIES.RESPEC] = L["Respec"],
	[CATEGORIES.GUILD_REPAIR] = L["Guild Repair"],
	[CATEGORIES.GUILD_BANK] = L["Guild Bank"],
	[CATEGORIES.OTHER] = L["Other"],
}

local TIMEFRAME_LABELS = {
	SESSION = L["Session"],
	TODAY = L["Today"],
	WEEK = L["This Week"],
	ROLLING = L["Rolling"],
	LIFETIME = L["Lifetime"],
}

local SCOPE_LABELS = {
	CHAR = L["Character"],
	REALM = L["Realm"],
	ACCOUNT = L["Account"],
}

local function EnsureTable(parent, key)
	local value = parent[key]
	if not value then
		value = {}
		parent[key] = value
	end
	return value
end

local function GetDateKey(ts)
	local t = date("*t", ts)
	return (t.year * 10000) + (t.month * 100) + t.day
end

local function GetWeekKey(ts)
	local t = date("*t", ts)
	local dayStart = time({year = t.year, month = t.month, day = t.day, hour = 0})
	local offset = (t.wday - 1) * 86400
	local sunday = dayStart - offset
	local st = date("*t", sunday)
	return (st.year * 10000) + (st.month * 100) + st.day
end

local function BuildSystemPattern(text)
	if not text then
		return nil
	end
	local placeholder = "%%AZUI_PLACEHOLDER%%"
	text = text:gsub("%%(%d+%$)?[%a]", placeholder)
	text = E:EscapeString(text)
	text = text:gsub(placeholder, "(.+)")
	return text
end

local function ExtractItemLinkFromMessage(msg)
	if not msg then
		return nil
	end
	return msg:match("|Hitem:.-|h%[.-%]|h") or msg:match("|Hitem:.-|h.-|h")
end

local function ExtractItemFromAuctionSoldMessage(msg)
	if not msg then
		return nil
	end
	local link = ExtractItemLinkFromMessage(msg)
	if link then
		return link
	end
	return msg:match("auction of (.+) has sold") or msg:match("auction of (.+) sold")
end

local function ParseMoneyFromMessage(msg)
	if not msg then
		return nil
	end
	if GetMoneyFromString then
		local amount = GetMoneyFromString(msg)
		if amount and amount > 0 then
			return amount
		end
	end
	local stripped = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub(",", "")
	local gold = tonumber(stripped:match("(%d+)%s*[gG]")) or tonumber(stripped:match("(%d+)%s*[Gg]old"))
	local silver = tonumber(stripped:match("(%d+)%s*[sS]")) or tonumber(stripped:match("(%d+)%s*[Ss]ilver"))
	local copper = tonumber(stripped:match("(%d+)%s*[cC]")) or tonumber(stripped:match("(%d+)%s*[Cc]opper"))
	if not gold then
		gold = tonumber(stripped:match("(%d+)%s*|TInterface\\MoneyFrame\\UI%-GoldIcon"))
	end
	if not silver then
		silver = tonumber(stripped:match("(%d+)%s*|TInterface\\MoneyFrame\\UI%-SilverIcon"))
	end
	if not copper then
		copper = tonumber(stripped:match("(%d+)%s*|TInterface\\MoneyFrame\\UI%-CopperIcon"))
	end
	if gold or silver or copper then
		return (gold or 0) * 10000 + (silver or 0) * 100 + (copper or 0)
	end
	return nil
end

local function GetRecordIcon(record)
	if not record then
		return nil
	end
	local link = record.itemLink
	local itemId = record.itemId
	if GetItemInfoInstant then
		local _, _, _, _, icon = GetItemInfoInstant(link or itemId or 0)
		if icon and icon > 0 then
			return icon
		end
	end
	if link then
		return select(10, GetItemInfo(link))
	end
	if itemId then
		return select(10, GetItemInfo(itemId))
	end
	return nil
end

local function GetItemIdFromLink(link)
	if not link then
		return nil
	end
	local itemId = GetItemInfoInstant(link)
	if itemId and type(itemId) == "number" then
		return itemId
	end
	return nil
end

local function GetItemNameFromLink(link)
	if not link then
		return nil
	end
	return link:match("%[(.+)%]")
end

local sellTooltip
local function GetSellItemLink()
	if _G.GetAuctionSellItemLink then
		return _G.GetAuctionSellItemLink()
	end
	if C_AuctionHouse and C_AuctionHouse.GetSellItemInfo then
		local info = C_AuctionHouse.GetSellItemInfo()
		if type(info) == "table" then
			if info.itemLink then
				return info.itemLink
			end
			local itemId = (info.itemKey and info.itemKey.itemID) or info.itemID
			if itemId then
				return select(2, GetItemInfo(itemId))
			end
		elseif type(info) == "string" then
			if info:find("item:") or info:find("|c") then
				return info
			end
		end
	end
	if _G.GameTooltip and _G.GameTooltip.SetAuctionSellItem then
		if not sellTooltip then
			sellTooltip = CreateFrame("GameTooltip", "AzUI_SalesLedgerSellTooltip", UIParent, "GameTooltipTemplate")
		end
		sellTooltip:SetOwner(UIParent, "ANCHOR_NONE")
		local ok = pcall(sellTooltip.SetAuctionSellItem, sellTooltip)
		if ok then
			local _, link = sellTooltip:GetItem()
			sellTooltip:Hide()
			return link
		end
		sellTooltip:Hide()
	end
	return nil
end

function module:FormatMoney(amount)
	local sign = amount < 0 and "-" or ""
	return sign .. E:FormatMoney(abs(amount))
end

function module:GetCategoryLabel(category, sub)
	if sub == "deposit" then
		return L["Auction Deposit"]
	end
	return CATEGORY_LABELS[category] or L["Other"]
end

function module:GetScopeLabel(scope)
	return SCOPE_LABELS[scope] or SCOPE_LABELS.CHAR
end

function module:GetTimeframeLabel(timeframe)
	return TIMEFRAME_LABELS[timeframe] or TIMEFRAME_LABELS.SESSION
end

function module:GetScopeAggregate(scope)
	if scope == "ACCOUNT" then
		return self.global.aggregates.account
	elseif scope == "REALM" then
		return self.global.aggregates.realm and self.global.aggregates.realm[E.myrealm]
	end
	return self.global.aggregates.char and self.global.aggregates.char[E.myrealm] and self.global.aggregates.char[E.myrealm][E.myname]
end

function module:GetCharacterStore()
	self.global.characters = self.global.characters or {}
	return self.global.characters
end

function module:IsMailIndexProcessed(index)
	if not index or not self.mailProcessed then
		return false
	end
	local ts = self.mailProcessed[index]
	if ts and (time() - ts) < 2 then
		return true
	end
	return false
end

function module:MarkMailIndexProcessed(index)
	if not index then
		return
	end
	self.mailProcessed = self.mailProcessed or {}
	self.mailProcessed[index] = time()
end

function module:IsAuctionHouseMail(sender, subject)
	local auctionSender = _G.AUCTION_HOUSE_MAILBOX or _G.AUCTION_HOUSE
	if sender and auctionSender and sender == auctionSender then
		return true
	end
	if subject and self.auctionMailPatterns then
		for _, pattern in pairs(self.auctionMailPatterns) do
			if pattern and subject:match(pattern) then
				return true
			end
		end
	end
	return false
end

function module:UpdateCharacterSnapshot(isLogout)
	if not self.global then
		return
	end
	local store = self:GetCharacterStore()
	local realmStore = EnsureTable(store, E.myrealm)
	local info = EnsureTable(realmStore, E.myname)
	local current = GetMoney()
	if not info.lastLogoutGold then
		info.lastLogoutGold = current
	end
	if isLogout then
		local previous = info.lastLogoutGold or current
		info.lastDelta = current - previous
		info.lastLogoutGold = current
		info.gold = current
		info.lastSeen = time()
	else
		info.gold = current
		info.lastSeen = time()
	end
end

function module:GetTimeframeStart(timeframe)
	local now = time()
	if timeframe == "SESSION" and self.session and self.session.started then
		return self.session.started
	elseif timeframe == "TODAY" then
		local t = date("*t", now)
		return time({year = t.year, month = t.month, day = t.day, hour = 0})
	elseif timeframe == "WEEK" then
		local t = date("*t", now)
		local dayStart = time({year = t.year, month = t.month, day = t.day, hour = 0})
		local offset = (t.wday - 1) * 86400
		return dayStart - offset
	elseif timeframe == "ROLLING" then
		local days = self.db.rollingDays or 7
		return now - (days * 86400)
	end
	return 0
end

local function FloorToDay(ts)
	if not ts or ts <= 0 then
		ts = time()
	end
	local t = date("*t", ts)
	if not t then
		return nil
	end
	return time({year = t.year, month = t.month, day = t.day, hour = 0})
end

local function FormatBucketLabel(ts, bucketSeconds)
	if not ts or not bucketSeconds then
		return ""
	end
	local endTs = ts + bucketSeconds
	if bucketSeconds < 86400 then
		return format("%s - %s", date("%H:%M", ts), date("%H:%M", endTs))
	elseif bucketSeconds == 86400 then
		return date("%B %d, %Y", ts)
	else
		return format("%s - %s", date("%B %d, %Y", ts), date("%B %d, %Y", endTs - 1))
	end
end

local function ChooseLifetimeBucketSeconds(spanSeconds)
	local candidates = { 900, 3600, 21600, 86400, 604800, 2592000, 7776000, 31536000 }
	local maxPoints = 120
	for i = 1, #candidates do
		local seconds = candidates[i]
		if (spanSeconds / seconds) <= maxPoints then
			return seconds
		end
	end
	return candidates[#candidates]
end

local function GetBucketCount(startTs, endTs, bucketSeconds)
	if not startTs or not endTs or not bucketSeconds or bucketSeconds <= 0 then
		return 0
	end
	local span = max(0, endTs - startTs)
	return floor(span / bucketSeconds) + 1
end

function module:GetFirstDailyTimestamp(scope)
	local agg = self:GetScopeAggregate(scope)
	if not agg or not agg.daily then
		return nil
	end
	local firstKey
	for key in pairs(agg.daily) do
		if not firstKey or key < firstKey then
			firstKey = key
		end
	end
	if not firstKey then
		return nil
	end
	local year = floor(firstKey / 10000)
	local month = floor((firstKey % 10000) / 100)
	local day = firstKey % 100
	return time({year = year, month = month, day = day, hour = 0})
end

function module:BuildSeriesFromRecords(scope, startTs, bucketSeconds, count)
	local series = {}
	if not startTs or not bucketSeconds or bucketSeconds <= 0 or not count or count <= 0 then
		return series
	end
	for i = 1, count do
		series[i] = { ts = startTs + ((i - 1) * bucketSeconds), delta = 0 }
	end

	local endTs = startTs + (count * bucketSeconds)
	local records = self:GetRecordsForScope(scope)
	for i = 1, #records do
		local record = records[i]
		local ts = record and record.ts or 0
		if ts >= startTs and ts < endTs then
			local idx = floor((ts - startTs) / bucketSeconds) + 1
			local delta = record.delta or 0
			local bucket = series[idx]
			if bucket then
				bucket.delta = bucket.delta + delta
			end
		end
	end

	return series
end

function module:BuildSeriesFromDailyAgg(agg, startTs, bucketSeconds, count)
	local series = {}
	if not agg or not agg.daily or not startTs or not bucketSeconds or bucketSeconds <= 0 or not count or count <= 0 then
		return series
	end
	local daysPerBucket = max(1, floor(bucketSeconds / 86400))
	for i = 1, count do
		local bucketStart = startTs + ((i - 1) * bucketSeconds)
		local delta = 0
		for d = 0, daysPerBucket - 1 do
			local ts = bucketStart + (d * 86400)
			local key = GetDateKey(ts)
			local bucket = agg.daily[key]
			delta = delta + (bucket and bucket.net or 0)
		end
		series[i] = { ts = bucketStart, delta = delta }
	end
	return series
end

local function ApplyCumulativeNet(series)
	local total = 0
	for i = 1, #series do
		total = total + (series[i].delta or 0)
		series[i].total = total
	end
end

function module:GetGraphSeries(scope, timeframe)
	local agg = self:GetScopeAggregate(scope)
	local series = {}
	local now = time()
	local todayStart = FloorToDay(now)

	if not agg or not agg.daily then
		return series
	end

	if timeframe == "TODAY" then
		local bucketSeconds = 900
		local endTs = now
		local count = GetBucketCount(todayStart, endTs, bucketSeconds)
		series = self:BuildSeriesFromRecords(scope, todayStart, bucketSeconds, count)
		ApplyCumulativeNet(series)
		return series, todayStart, endTs, bucketSeconds
	elseif timeframe == "WEEK" then
		local startTs = FloorToDay(self:GetTimeframeStart("WEEK"))
		local bucketSeconds = 86400
		local endTs = now
		local count = GetBucketCount(startTs, endTs, bucketSeconds)
		series = self:BuildSeriesFromDailyAgg(agg, startTs, bucketSeconds, count)
		ApplyCumulativeNet(series)
		return series, startTs, endTs, bucketSeconds
	elseif timeframe == "LIFETIME" then
		local startTs = self:GetFirstDailyTimestamp(scope)
		if not startTs then
			return series
		end
		local endTs = now
		local spanSeconds = max(0, endTs - startTs)
		local bucketSeconds = ChooseLifetimeBucketSeconds(spanSeconds)
		local count = GetBucketCount(startTs, endTs, bucketSeconds)
		if bucketSeconds >= 86400 and (bucketSeconds % 86400 == 0) then
			series = self:BuildSeriesFromDailyAgg(agg, startTs, bucketSeconds, count)
		else
			series = self:BuildSeriesFromRecords(scope, startTs, bucketSeconds, count)
		end
		ApplyCumulativeNet(series)
		return series, startTs, endTs, bucketSeconds
	end

	local rawStart = self:GetTimeframeStart(timeframe)
	if not rawStart or rawStart <= 0 then
		rawStart = todayStart
	end
	local startTs = FloorToDay(rawStart) or todayStart
	local bucketSeconds = 86400
	local endTs = now
	local count = GetBucketCount(startTs, endTs, bucketSeconds)
	series = self:BuildSeriesFromDailyAgg(agg, startTs, bucketSeconds, count)
	ApplyCumulativeNet(series)
	return series, startTs, endTs, bucketSeconds
end

function module:UpdateSummaryGraph()
	if not self.frame or not self.frame.summary or not self.frame.summary.graph then
		return
	end
	local summary = self.frame.summary
	local graph = summary.graph
	local scope = self.view.scope or "CHAR"
	local timeframe = self.view.timeframe or "SESSION"
	local series, startTs, endTs, bucketSeconds = self:GetGraphSeries(scope, timeframe)
	local count = #series

	if summary.graphHeader then
		if startTs and endTs then
			local rangeLabel
			if bucketSeconds and bucketSeconds < 86400 then
				rangeLabel = date("%m/%d", startTs)
			else
				rangeLabel = format("%s - %s", date("%m/%d", startTs), date("%m/%d", endTs))
			end
			summary.graphHeader:SetText(format("%s (%s)", L["Net"], rangeLabel))
		else
			summary.graphHeader:SetText(L["Net"])
		end
	end

	local width = graph:GetWidth()
	local height = graph:GetHeight()
	if not width or width <= 0 or not height or height <= 0 then
		return
	end

	graph.lines = graph.lines or {}
	graph.points = graph.points or {}
	graph.bars = graph.bars or {}
	graph.grid = graph.grid or { h = {}, v = {} }
	for i = 1, #graph.bars do
		graph.bars[i]:Hide()
	end

	local gridAlpha = 0.08
	local gridHeight = height - 2
	local hLines = 3
	for i = 1, hLines do
		local line = graph.grid.h[i]
		if not line then
			line = graph:CreateTexture(nil, "BORDER")
			line:SetTexture(E.media.blankTex)
			graph.grid.h[i] = line
		end
		line:SetVertexColor(1, 1, 1, gridAlpha)
		local y = gridHeight * (i / (hLines + 1))
		line:ClearAllPoints()
		line:SetPoint("BOTTOMLEFT", graph, "BOTTOMLEFT", 0, y)
		line:SetPoint("BOTTOMRIGHT", graph, "BOTTOMRIGHT", 0, y)
		line:SetHeight(1)
		line:Show()
	end
	for i = hLines + 1, #graph.grid.h do
		graph.grid.h[i]:Hide()
	end

	local vLines = 4
	local vStep = width / (vLines + 1)
	for i = 1, vLines do
		local line = graph.grid.v[i]
		if not line then
			line = graph:CreateTexture(nil, "BORDER")
			line:SetTexture(E.media.blankTex)
			graph.grid.v[i] = line
		end
		line:SetVertexColor(1, 1, 1, gridAlpha)
		local x = vStep * i
		line:ClearAllPoints()
		line:SetPoint("BOTTOMLEFT", graph, "BOTTOMLEFT", x, 0)
		line:SetPoint("TOPLEFT", graph, "TOPLEFT", x, 0)
		line:SetWidth(1)
		line:Show()
	end
	for i = vLines + 1, #graph.grid.v do
		graph.grid.v[i]:Hide()
	end

	if count == 0 then
		for i = 1, #graph.lines do
			graph.lines[i]:Hide()
		end
		for i = 1, #graph.points do
			graph.points[i]:Hide()
		end
		return
	end

	local minValue = 0
	local maxValue = 0
	for i = 1, count do
		local value = series[i].total or 0
		if i == 1 or value < minValue then
			minValue = value
		end
		if i == 1 or value > maxValue then
			maxValue = value
		end
	end
	local range = maxValue - minValue
	if range == 0 then
		range = 1
	end

	local step = (count > 1) and (width / (count - 1)) or 0
	local lineThickness = 2
	local pointSize = 6
	local usableHeight = height - 2
	local r, g, b = E.media.rgbvaluecolor.r, E.media.rgbvaluecolor.g, E.media.rgbvaluecolor.b

	local prevX, prevY
	for i = 1, count do
		local data = series[i]
		local value = data.total or 0
		local x = (count > 1) and ((i - 1) * step) or (width / 2)
		local y = ((value - minValue) / range) * usableHeight

		local point = graph.points[i]
		if not point then
			point = CreateFrame("Button", nil, graph)
			point.tex = point:CreateTexture(nil, "ARTWORK")
			point.tex:SetAllPoints()
			point.tex:SetTexture(MER.Media.Textures.Pushed or E.media.blankTex)
			point:SetSize(pointSize, pointSize)
			point:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_TOP")
				GameTooltip:ClearLines()
				if self.ts and self.bucketSeconds then
					GameTooltip:AddLine(FormatBucketLabel(self.ts, self.bucketSeconds))
				end
				GameTooltip:AddDoubleLine(L["Net"], module:FormatMoney(self.value or 0), 1, 1, 1, 1, 1, 1)
				GameTooltip:Show()
			end)
			point:SetScript("OnLeave", function()
				GameTooltip:Hide()
			end)
			graph.points[i] = point
		end
		point.tex:SetVertexColor(r, g, b, 1)
		point:ClearAllPoints()
		point:SetPoint("CENTER", graph, "BOTTOMLEFT", x, y)
		point.ts = data.ts
		point.value = value
		point.bucketSeconds = bucketSeconds or 86400
		point:Show()

		if prevX and prevY then
			local line = graph.lines[i - 1]
			if not line then
				line = graph:CreateTexture(nil, "ARTWORK")
				line:SetTexture(E.media.blankTex)
				graph.lines[i - 1] = line
			end
			local dx = x - prevX
			local dy = y - prevY
			local length = math.sqrt((dx * dx) + (dy * dy))
			local angle = math.atan2(dy, dx)
			line:SetSize(length, lineThickness)
			line:SetVertexColor(r, g, b, 0.9)
			line:ClearAllPoints()
			line:SetPoint("CENTER", graph, "BOTTOMLEFT", (prevX + x) / 2, (prevY + y) / 2)
			line:SetRotation(angle)
			line:Show()
		end

		prevX, prevY = x, y
	end

	for i = count, #graph.lines do
		graph.lines[i]:Hide()
	end
	for i = count + 1, #graph.points do
		graph.points[i]:Hide()
	end
end

function module:GetBucketForTimeframe(scope, timeframe)
	local agg = self:GetScopeAggregate(scope)
	if not agg then
		return nil
	end
	if timeframe == "SESSION" then
		return self.session
	elseif timeframe == "TODAY" then
		local key = GetDateKey(time())
		return agg.daily and agg.daily[key]
	elseif timeframe == "WEEK" then
		local key = GetWeekKey(time())
		return agg.weekly and agg.weekly[key]
	elseif timeframe == "ROLLING" then
		local days = self.db.rollingDays or 7
		local cutoff = time() - (days * 86400)
		local total = { earned = 0, spent = 0, net = 0, profit = 0, byCategory = {} }
		if agg.daily then
			for key, bucket in pairs(agg.daily) do
				local year = floor(key / 10000)
				local month = floor((key % 10000) / 100)
				local day = key % 100
				local ts = time({year = year, month = month, day = day, hour = 0})
				if ts >= cutoff then
					total.earned = total.earned + (bucket.earned or 0)
					total.spent = total.spent + (bucket.spent or 0)
					total.net = total.net + (bucket.net or 0)
					total.profit = total.profit + (bucket.profit or 0)
					if bucket.byCategory then
						for cat, value in pairs(bucket.byCategory) do
							total.byCategory[cat] = (total.byCategory[cat] or 0) + value
						end
					end
				end
			end
		end
		return total
	elseif timeframe == "LIFETIME" then
		return agg.lifetime
	end
	return nil
end

function module:GetRecordsForScope(scope)
	local records = {}
	if not self.global or not self.global.records then
		return records
	end
	if scope == "ACCOUNT" then
		for realm, chars in pairs(self.global.records) do
			for character, store in pairs(chars) do
				local entries = store.entries
				if entries then
					for i = 1, #entries do
						tinsert(records, entries[i])
					end
				end
			end
		end
	elseif scope == "REALM" then
		local realmStore = self.global.records[E.myrealm]
		if realmStore then
			for character, store in pairs(realmStore) do
				local entries = store.entries
				if entries then
					for i = 1, #entries do
						tinsert(records, entries[i])
					end
				end
			end
		end
	else
		local entries = self:GetRecordStore(E.myrealm, E.myname)
		for i = 1, #entries do
			tinsert(records, entries[i])
		end
	end
	return records
end

function module:RecordMatchesFilters(record, startTime, searchText)
	if startTime and record.ts and record.ts < startTime then
		return false
	end
	if self.db.filters and self.db.filters.categories then
		if self.db.filters.categories[record.cat] == false then
			return false
		end
	end
	if searchText and searchText ~= "" then
		local needle = searchText:lower()
		local hay = record.itemLink or record.note or ""
		if hay:lower():find(needle, 1, true) == nil then
			return false
		end
	end
	return true
end

function module:GetFilteredRecords(scope, timeframe, searchText)
	local startTime = self:GetTimeframeStart(timeframe)
	local records = self:GetRecordsForScope(scope)
	local filtered = {}
	for i = 1, #records do
		local record = records[i]
		if record and self:RecordMatchesFilters(record, startTime, searchText) then
			tinsert(filtered, record)
		end
	end
	return filtered
end

function module:GetSortValue(record, key)
	if key == "time" then
		return record.ts or 0
	elseif key == "category" then
		return self:GetCategoryLabel(record.cat, record.sub)
	elseif key == "item" then
		return record.itemLink or record.note or ""
	elseif key == "qty" then
		return record.qty or 1
	elseif key == "delta" then
		if record.cat == CATEGORIES.AUCTION_SALE and record.gross then
			return record.gross
		end
		return record.delta or 0
	elseif key == "net" then
		return record.net or record.delta or 0
	end
	return record.ts or 0
end

function module:SortRecords(records)
	local key = (self.sort and self.sort.key) or "time"
	local asc = self.sort and self.sort.asc
	table.sort(records, function(a, b)
		local va = self:GetSortValue(a, key)
		local vb = self:GetSortValue(b, key)
		if va == vb then
			return (a.ts or 0) > (b.ts or 0)
		end
		if asc then
			return va < vb
		end
		return va > vb
	end)
end

function module:NotifyUpdate()
	if self.frame and self.frame:IsShown() then
		self:UpdateSummary()
		self:UpdateLedger()
	end
	if self.dtUpdate then
		self.dtUpdate()
	end
end

function module:IsCategoryEnabled(category)
	if not self.db or not self.db.filters or not self.db.filters.categories then
		return true
	end
	local enabled = self.db.filters.categories[category]
	if enabled == nil then
		return true
	end
	return enabled
end

function module:QueuePending(amount, category, data)
	if category and not self:IsCategoryEnabled(category) then
		return
	end
	tinsert(self.pendingQueue, {
		amount = amount,
		category = category,
		data = data,
		added = time(),
	})
end

function module:QueueIgnore(amount)
	if not amount or amount == 0 then
		return
	end
	tinsert(self.pendingQueue, 1, {
		amount = amount,
		ignore = true,
		added = time(),
	})
end

function module:ConsumePending(delta)
	local now = time()
	for i = #self.pendingQueue, 1, -1 do
		if now - (self.pendingQueue[i].added or now) > 10 then
			tremove(self.pendingQueue, i)
		end
	end

	local pendingIndex
	local pendingEntry

	for i = 1, #self.pendingQueue do
		local entry = self.pendingQueue[i]
		if entry.amount and entry.amount == delta then
			pendingIndex = i
			pendingEntry = entry
			break
		end
	end

	if not pendingEntry then
		for i = 1, #self.pendingQueue do
			local entry = self.pendingQueue[i]
			if entry.amount == nil then
				pendingIndex = i
				pendingEntry = entry
				break
			end
		end
	end

	if pendingIndex then
		tremove(self.pendingQueue, pendingIndex)
		if pendingEntry.ignore then
			return
		end
		self:CreateRecordFromPending(delta, pendingEntry)
		return
	end

	if self.db.trackUnclassified then
		self:AddRecord({
			cat = CATEGORIES.OTHER,
			delta = delta,
			net = delta,
			gross = delta,
			force = true,
			note = L["Unclassified"],
		})
	end
end

function module:CreateRecordFromPending(delta, pending)
	local data = pending.data or {}
	local record = {
		cat = pending.category or CATEGORIES.OTHER,
		delta = delta,
		net = data.net or delta,
		gross = data.gross or delta,
		profit = data.profit,
		qty = data.qty or 1,
		itemLink = data.itemLink,
		itemId = data.itemId,
		sub = data.sub,
		note = data.note,
		mail = data.mail,
	}
	self:AddRecord(record)
end

function module:GetRecordStore(realm, character)
	local records = EnsureTable(self.global.records, realm)
	local charStore = EnsureTable(records, character)
	if not charStore.entries then
		charStore.entries = {}
	end
	return charStore.entries
end

function module:EnsureAggregate(agg)
	if not agg.lifetime then
		agg.lifetime = {}
	end
	if not agg.daily then
		agg.daily = {}
	end
	if not agg.weekly then
		agg.weekly = {}
	end
	if not agg.byItem then
		agg.byItem = {}
	end
end

function module:UpdateTotals(bucket, record)
	bucket.earned = (bucket.earned or 0) + max(record.delta, 0)
	bucket.spent = (bucket.spent or 0) + max(-record.delta, 0)
	bucket.net = (bucket.net or 0) + record.delta
	bucket.profit = (bucket.profit or 0) + (record.profit or record.net or record.delta)
	bucket.byCategory = bucket.byCategory or {}
	bucket.byCategory[record.cat] = (bucket.byCategory[record.cat] or 0) + record.delta
end

function module:UpdateItemAggregate(agg, record)
	if not record.itemLink then
		return
	end
	local key = record.itemId or record.itemLink
	if not key then
		return
	end
	local item = agg.byItem[key]
	if not item then
		item = {
			link = record.itemLink,
			qty = 0,
			net = 0,
			gross = 0,
			profit = 0,
		}
		agg.byItem[key] = item
	end
	item.qty = item.qty + (record.qty or 1)
	item.net = item.net + (record.delta or 0)
	item.gross = item.gross + (record.gross or 0)
	item.profit = item.profit + (record.profit or record.net or record.delta or 0)
end

function module:UpdateAggregates(record)
	local realm = record.realm
	local character = record.char
	local dateKey = GetDateKey(record.ts)
	local weekKey = GetWeekKey(record.ts)

	self.global.aggregates.account = self.global.aggregates.account or {}
	self.global.aggregates.realm = self.global.aggregates.realm or {}
	self.global.aggregates.char = self.global.aggregates.char or {}

	local accountAgg = self.global.aggregates.account
	self:EnsureAggregate(accountAgg)
	local realmAgg = EnsureTable(self.global.aggregates.realm, realm)
	self:EnsureAggregate(realmAgg)
	local charAgg = EnsureTable(EnsureTable(self.global.aggregates.char, realm), character)
	self:EnsureAggregate(charAgg)

	local function UpdateAll(agg)
		self:UpdateTotals(agg.lifetime, record)
		local daily = EnsureTable(agg.daily, dateKey)
		self:UpdateTotals(daily, record)
		local weekly = EnsureTable(agg.weekly, weekKey)
		self:UpdateTotals(weekly, record)
		self:UpdateItemAggregate(agg, record)
	end

	UpdateAll(accountAgg)
	UpdateAll(realmAgg)
	UpdateAll(charAgg)
end

function module:UpdateSession(record)
	self.session = self.session or {
		started = time(),
		earned = 0,
		spent = 0,
		net = 0,
		profit = 0,
		byCategory = {},
	}
	self.session.earned = self.session.earned + max(record.delta, 0)
	self.session.spent = self.session.spent + max(-record.delta, 0)
	self.session.net = self.session.net + record.delta
	self.session.profit = self.session.profit + (record.profit or record.net or record.delta)
	self.session.byCategory[record.cat] = (self.session.byCategory[record.cat] or 0) + record.delta
end

function module:RebuildAggregates()
	self.global.aggregates = { account = {}, realm = {}, char = {} }
	for realm, chars in pairs(self.global.records) do
		for character, store in pairs(chars) do
			local entries = store.entries
			if entries then
				for i = 1, #entries do
					local record = entries[i]
					if record then
						self:UpdateAggregates(record)
					end
				end
			end
		end
	end
end

function module:RebuildSession()
	if not self.session or not self.session.started then
		return
	end
	local entries = self:GetRecordStore(E.myrealm, E.myname)
	local started = self.session.started
	self.session = {
		started = started,
		earned = 0,
		spent = 0,
		net = 0,
		profit = 0,
		byCategory = {},
	}
	for i = 1, #entries do
		local record = entries[i]
		if record and record.ts and record.ts >= started then
			self:UpdateSession(record)
		end
	end
end

function module:RunPurge()
	if not self.db or not self.db.purge or not self.db.purge.enabled then
		return
	end
	local days = self.db.purge.days or 0
	if days <= 0 then
		return
	end
	local cutoff = time() - (days * 86400)
	local changed = false
	for realm, chars in pairs(self.global.records) do
		for character, store in pairs(chars) do
			local entries = store.entries
			if entries then
				local kept = {}
				for i = 1, #entries do
					local record = entries[i]
					if record and record.ts and record.ts >= cutoff then
						tinsert(kept, record)
					else
						changed = true
					end
				end
				store.entries = kept
			end
		end
	end
	if changed and self.db.purge.mode == "RAW_AND_SUMMARY" then
		self:RebuildAggregates()
	end
	if changed then
		self:NotifyUpdate()
	end
end

function module:AddRecord(record)
	if not record or not record.cat then
		return nil
	end

	if not self:IsCategoryEnabled(record.cat) then
		return nil
	end

	if record.delta == 0 and not record.force then
		return nil
	end

	local realm = E.myrealm
	local character = E.myname
	local entries = self:GetRecordStore(realm, character)

	record.ts = record.ts or time()
	record.realm = realm
	record.char = character
	record.delta = record.delta or 0
	record.net = record.net or record.delta
	record.gross = record.gross or record.delta
	record.profit = record.profit or record.net or record.delta
	record.qty = record.qty or 1

	tinsert(entries, record)
	self:UpdateAggregates(record)
	self:UpdateSession(record)
	self:NotifyUpdate()

	return #entries
end

function module:GetAuctionStore()
	self.global.auctions.pending = self.global.auctions.pending or {}
	local realmStore = EnsureTable(self.global.auctions.pending, E.myrealm)
	local charStore = EnsureTable(realmStore, E.myname)
	if not charStore.nextId then
		charStore.nextId = 1
	end
	if not charStore.entries then
		charStore.entries = {}
	end
	return charStore
end

function module:AddPendingAuction(entry)
	local store = self:GetAuctionStore()
	local id = store.nextId
	store.nextId = store.nextId + 1
	entry.id = id
	entry.added = time()
	if not entry.itemName and entry.itemLink then
		entry.itemName = GetItemNameFromLink(entry.itemLink)
	end
	store.entries[id] = entry
	return entry
end

function module:BuildAuctionKey(itemId, qty, minBid, buyout)
	return format("%s:%d:%d:%d", itemId or "0", qty or 1, minBid or 0, buyout or 0)
end

function module:ScanOwnedAuctions()
	if C_AuctionHouse and C_AuctionHouse.GetOwnedAuctions then
		local owned = C_AuctionHouse.GetOwnedAuctions()
		if not owned or #owned == 0 then
			return
		end
		local now = time()
		if self.lastAuctionScan and (now - self.lastAuctionScan) < 2 then
			return
		end
		self.lastAuctionScan = now

		local needed = {}
		local infoMap = {}
		for i = 1, #owned do
			local info = owned[i]
			if info then
				local itemKey = info.itemKey
				local itemId = (itemKey and itemKey.itemID) or info.itemID
				local qty = info.quantity or info.stackSize or 1
				local minBid = info.bidAmount or info.minBid or 0
				local buyout = info.buyoutAmount or info.buyout or 0
				local keyItem = itemId or info.itemName or i
				if itemKey and type(itemKey) == "table" then
					keyItem = format("%s:%d:%d:%d:%d", itemId or 0, itemKey.itemSuffix or 0, itemKey.itemLevel or 0, itemKey.itemContext or 0, itemKey.battlePetSpeciesID or 0)
				end
				local key = self:BuildAuctionKey(keyItem, qty, minBid, buyout)
				needed[key] = (needed[key] or 0) + 1
				if not infoMap[key] then
					local itemName = info.itemName
					if not itemName and itemKey and C_AuctionHouse.GetItemKeyInfo then
						local keyInfo = C_AuctionHouse.GetItemKeyInfo(itemKey)
						itemName = keyInfo and keyInfo.itemName
					end
					local link = info.itemLink
					if not link and itemId then
						link = select(2, GetItemInfo(itemId))
					end
					infoMap[key] = {
						itemLink = link or itemName,
						itemId = itemId,
						itemName = itemName,
						qty = qty,
						minBid = minBid,
						buyout = buyout,
						deposit = info.depositAmount or info.deposit or 0,
						source = "scan",
						keyItem = keyItem,
					}
				end
			end
		end

		local store = self:GetAuctionStore()
		local existing = {}
		for _, entry in pairs(store.entries) do
			local key = self:BuildAuctionKey(entry.keyItem or entry.itemId or entry.itemName or entry.itemLink, entry.qty, entry.minBid or 0, entry.buyout or 0)
			existing[key] = (existing[key] or 0) + 1
		end

		for key, countNeeded in pairs(needed) do
			local countExisting = existing[key] or 0
			local toAdd = countNeeded - countExisting
			if toAdd > 0 then
				local info = infoMap[key]
				for _ = 1, toAdd do
					if info then
						local entry = {}
						for k, v in pairs(info) do
							entry[k] = v
						end
						self:AddPendingAuction(entry)
					end
				end
			end
		end
		return
	end
	if not GetNumAuctionItems or not GetAuctionItemInfo then
		return
	end
	local total = GetNumAuctionItems("owner")
	if not total or total <= 0 then
		return
	end
	local now = time()
	if self.lastAuctionScan and (now - self.lastAuctionScan) < 2 then
		return
	end
	self.lastAuctionScan = now

	local needed = {}
	local infoMap = {}
	for i = 1, total do
		local name, _, count, _, _, _, _, minBid, _, buyout = GetAuctionItemInfo("owner", i)
		local link = GetAuctionItemLink and GetAuctionItemLink("owner", i)
		local itemId = GetItemIdFromLink(link)
		local qty = count or 1
		local key = self:BuildAuctionKey(itemId or name or link or i, qty, minBid or 0, buyout or 0)
		needed[key] = (needed[key] or 0) + 1
		if not infoMap[key] then
			infoMap[key] = {
				itemLink = link or name,
				itemId = itemId,
				itemName = name,
				qty = qty,
				minBid = minBid or 0,
				buyout = buyout or 0,
				deposit = 0,
				source = "scan",
			}
		end
	end

	local store = self:GetAuctionStore()
	local existing = {}
	for _, entry in pairs(store.entries) do
		local key = self:BuildAuctionKey(entry.keyItem or entry.itemId or entry.itemName or entry.itemLink, entry.qty, entry.minBid or 0, entry.buyout or 0)
		existing[key] = (existing[key] or 0) + 1
	end

	for key, countNeeded in pairs(needed) do
		local countExisting = existing[key] or 0
		local toAdd = countNeeded - countExisting
		if toAdd > 0 then
			local info = infoMap[key]
			for _ = 1, toAdd do
				if info then
					local entry = {}
					for k, v in pairs(info) do
						entry[k] = v
					end
					self:AddPendingAuction(entry)
				end
			end
		end
	end
end

function module:FindPendingAuction(itemLink, qty)
	local store = self:GetAuctionStore()
	local itemId = GetItemIdFromLink(itemLink)
	local itemName = itemLink
	if itemLink and itemLink:find("|H") then
		itemName = GetItemNameFromLink(itemLink)
	end
	local foundId
	local found
	for id, entry in pairs(store.entries) do
		local entryName = entry.itemName or (entry.itemLink and GetItemNameFromLink(entry.itemLink))
		if entry.itemLink == itemLink or (itemId and entry.itemId == itemId) or (itemName and entryName and entryName == itemName) then
			if not qty or entry.qty == qty then
				if not found or entry.added < found.added then
					foundId = id
					found = entry
				end
			end
		end
	end
	return foundId, found
end

function module:RemovePendingAuction(id)
	local store = self:GetAuctionStore()
	if id and store.entries[id] then
		store.entries[id] = nil
	end
end

function module:RecordAuctionDepositLoss(category, itemLink, qty, deposit)
	if not deposit or deposit <= 0 then
		return
	end
	self:AddRecord({
		cat = category,
		sub = "deposit",
		itemLink = itemLink,
		itemId = GetItemIdFromLink(itemLink),
		qty = qty or 1,
		delta = -deposit,
		net = -deposit,
		gross = -deposit,
		force = true,
	})
end

function module:RecordAuctionExpired(itemLink, qty, deposit)
	local record = {
		cat = CATEGORIES.AUCTION_EXPIRED,
		sub = "expired",
		itemLink = itemLink,
		itemId = GetItemIdFromLink(itemLink),
		qty = qty or 1,
		delta = 0,
		net = 0,
		gross = 0,
		force = true,
	}
	self:AddRecord(record)
	self:RecordAuctionDepositLoss(CATEGORIES.AUCTION_EXPIRED, itemLink, qty, deposit)
end

function module:RecordAuctionCanceled(itemLink, qty, deposit)
	local record = {
		cat = CATEGORIES.AUCTION_CANCELED,
		sub = "canceled",
		itemLink = itemLink,
		itemId = GetItemIdFromLink(itemLink),
		qty = qty or 1,
		delta = 0,
		net = 0,
		gross = 0,
		force = true,
	}
	self:AddRecord(record)
	self:RecordAuctionDepositLoss(CATEGORIES.AUCTION_CANCELED, itemLink, qty, deposit)
end

function module:RecordAuctionSale(itemLink, qty, salePrice, deposit)
	local gross = salePrice or 0
	local cut = floor(gross * AUCTION_CUT_RATE)
	local depositValue = deposit or 0
	local profit = gross - cut - depositValue
	local net = profit
	local record = {
		cat = CATEGORIES.AUCTION_SALE,
		sub = "sold",
		itemLink = itemLink,
		itemId = GetItemIdFromLink(itemLink),
		qty = qty or 1,
		gross = gross,
		cut = cut,
		deposit = depositValue,
		delta = net,
		net = net,
		profit = profit,
		mail = net,
		pendingMail = true,
	}
	local recordId = self:AddRecord(record)
	if recordId then
		self.pendingSales = self.pendingSales or {}
		self.pendingSales[recordId] = record
	end
	return record
end

function module:FindPendingSaleRecord(itemName, salePrice)
	if not self.pendingSales then
		return nil
	end
	local foundId
	local found
	for id, record in pairs(self.pendingSales) do
		if record and record.pendingMail then
			if salePrice and record.gross == salePrice then
				foundId = id
				found = record
				break
			end
			if itemName and record.itemLink and record.itemLink:find(itemName, 1, true) then
				foundId = id
				found = record
				break
			end
		end
	end
	return foundId, found
end

function module:HandleAuctionSold(itemLink, salePriceOverride)
	local id, pending = self:FindPendingAuction(itemLink)
	local qty = pending and pending.qty or 1
	local salePrice = (salePriceOverride and salePriceOverride > 0) and salePriceOverride or (pending and pending.buyout) or 0
	if salePrice == 0 and pending and pending.minBid then
		salePrice = pending.minBid
	end
	local deposit = pending and pending.deposit or 0
	if pending and pending.itemLink then
		itemLink = pending.itemLink
	end
	if pending and id then
		self:RemovePendingAuction(id)
	end
	if salePrice == 0 then
		salePrice = 0
	end
	local record = self:RecordAuctionSale(itemLink, qty, salePrice, deposit)
	self:SendSaleChat(record)
	self:QueueAuctionNotification(record)
end

function module:HandleAuctionExpired(itemLink)
	local id, pending = self:FindPendingAuction(itemLink)
	local qty = pending and pending.qty or 1
	local deposit = pending and pending.deposit or 0
	if pending and id then
		self:RemovePendingAuction(id)
	end
	self:RecordAuctionExpired(itemLink, qty, deposit)
end

function module:HandleAuctionCanceled(itemLink)
	local id, pending = self:FindPendingAuction(itemLink)
	local qty = pending and pending.qty or 1
	local deposit = pending and pending.deposit or 0
	if pending and id then
		self:RemovePendingAuction(id)
	end
	self:RecordAuctionCanceled(itemLink, qty, deposit)
end

function module:HandleAuctionOutbid(itemLink)
	if not self.pendingBids then
		return
	end
	local index
	local bid
	for i = 1, #self.pendingBids do
		local entry = self.pendingBids[i]
		if entry.itemLink == itemLink then
			index = i
			bid = entry
			break
		end
	end
	if not index or not bid then
		return
	end
	tremove(self.pendingBids, index)
	self:QueuePending(bid.amount, CATEGORIES.AUCTION_PURCHASE, {
		itemLink = bid.itemLink,
		itemId = bid.itemId,
		qty = bid.qty,
		sub = "refund",
		gross = bid.amount,
	})
end

function module:TrackAuctionBid(listType, index, bidAmount)
	if not self:IsCategoryEnabled(CATEGORIES.AUCTION_PURCHASE) then
		return
	end
	if not bidAmount or bidAmount <= 0 then
		return
	end
	local name, _, count, _, _, _, _, _, buyout = GetAuctionItemInfo(listType, index)
	local link = GetAuctionItemLink(listType, index)
	local itemId = GetItemIdFromLink(link)
	local qty = count or 1
	self.pendingBids = self.pendingBids or {}
	tinsert(self.pendingBids, {
		itemLink = link,
		itemId = itemId,
		qty = qty,
		amount = bidAmount,
	})
	self:QueuePending(-bidAmount, CATEGORIES.AUCTION_PURCHASE, {
		itemLink = link,
		itemId = itemId,
		qty = qty,
		gross = -bidAmount,
		sub = (buyout and buyout > 0 and bidAmount == buyout) and "buyout" or "bid",
	})
end

function module:PLAYER_MONEY()
	local current = GetMoney()
	if not self.lastMoney then
		self.lastMoney = current
		return
	end
	local delta = current - self.lastMoney
	self.lastMoney = current
	if delta == 0 then
		return
	end
	self:ConsumePending(delta)
end

function module:PLAYER_LOGOUT()
	self:UpdateCharacterSnapshot(true)
end

function module:AUCTION_HOUSE_SHOW()
	if C_AuctionHouse and C_AuctionHouse.RequestOwnedAuctions then
		C_AuctionHouse.RequestOwnedAuctions()
	end
	self:ScanOwnedAuctions()
end

function module:AUCTION_OWNED_LIST_UPDATE()
	self:ScanOwnedAuctions()
end

function module:OWNED_AUCTIONS_UPDATED()
	self:ScanOwnedAuctions()
end

function module:QUEST_TURNED_IN(_, _, money)
	if money and money > 0 then
		self:QueuePending(money, CATEGORIES.QUEST)
	end
end

function module:CHAT_MSG_MONEY()
	self:QueuePending(nil, CATEGORIES.LOOT)
end

function module:CHAT_MSG_SYSTEM(_, msg)
	if not msg then
		return
	end
	if self.auctionPatterns and self.auctionPatterns.sold then
		local itemLink, moneyText = msg:match(self.auctionPatterns.sold)
		if not itemLink then
			local lower = msg:lower()
			if lower:find("auction", 1, true) and lower:find("sold", 1, true) then
				itemLink = ExtractItemFromAuctionSoldMessage(msg)
			end
		end
		if itemLink then
			local salePrice = ParseMoneyFromMessage(moneyText or msg)
			self:HandleAuctionSold(itemLink, salePrice)
			return
		end
	end
	if self.auctionPatterns and self.auctionPatterns.expired then
		local itemLink = msg:match(self.auctionPatterns.expired)
		if itemLink then
			self:HandleAuctionExpired(itemLink)
			return
		end
	end
	if self.auctionPatterns and self.auctionPatterns.canceled then
		local itemLink = msg:match(self.auctionPatterns.canceled)
		if itemLink then
			self:HandleAuctionCanceled(itemLink)
			return
		end
	end
	if self.auctionPatterns and self.auctionPatterns.outbid then
		local itemLink = msg:match(self.auctionPatterns.outbid)
		if itemLink then
			self:HandleAuctionOutbid(itemLink)
			return
		end
	end
end

function module:OnStartAuction(minBid, buyoutPrice, runTime, stackSize, numStacks)
	if not self:IsCategoryEnabled(CATEGORIES.AUCTION_SALE) then
		return
	end
	local name, _, count = GetAuctionSellItemInfo and GetAuctionSellItemInfo()
	local link = GetSellItemLink()
	if not link then
		return
	end
	name = name or GetItemNameFromLink(link)
	local qty = stackSize or count or 1
	local stacks = numStacks or 1
	local deposit = GetAuctionDeposit and GetAuctionDeposit() or 0
	local depositPerAuction = 0
	if deposit and deposit > 0 and stacks > 0 then
		depositPerAuction = floor(deposit / stacks)
	end

	for _ = 1, stacks do
		self:AddPendingAuction({
			itemLink = link,
			itemId = GetItemIdFromLink(link),
			itemName = name,
			qty = qty,
			minBid = minBid or 0,
			buyout = buyoutPrice or 0,
			deposit = depositPerAuction,
			duration = runTime,
		})
	end
end

function module:OnPostAuction(...)
	self:OnStartAuction(...)
end

function module:OnCancelAuction(index)
	if not self:IsCategoryEnabled(CATEGORIES.AUCTION_CANCELED) then
		return
	end
	local name, _, count = GetAuctionItemInfo("owner", index)
	local link = GetAuctionItemLink("owner", index)
	if not link then
		return
	end
	local _, pending = self:FindPendingAuction(link, count or 1)
	local deposit = pending and pending.deposit or 0
	self:RecordAuctionCanceled(link, count or 1, deposit)
end

function module:OnPlaceAuctionBid(listType, index, bidAmount)
	self:TrackAuctionBid(listType, index, bidAmount)
end

function module:OnBuyMerchantItem(index, quantity)
	if not self:IsCategoryEnabled(CATEGORIES.VENDOR_PURCHASE) then
		return
	end
	local name, _, price, stackSize, _, _, extendedCost = GetMerchantItemInfo(index)
	if extendedCost then
		return
	end
	local link = GetMerchantItemLink(index)
	local qty = quantity or stackSize or 1
	local total = price and price > 0 and (price * qty) or nil
	self:QueuePending(total and -total or nil, CATEGORIES.VENDOR_PURCHASE, {
		itemLink = link,
		itemId = GetItemIdFromLink(link),
		qty = qty,
		gross = total and -total or nil,
	})
end

function module:OnBuybackItem(index)
	if not self:IsCategoryEnabled(CATEGORIES.VENDOR_PURCHASE) then
		return
	end
	local name, _, price, quantity = GetBuybackItemInfo(index)
	local link = GetBuybackItemLink(index)
	local qty = quantity or 1
	local total = price and price > 0 and (price * qty) or nil
	self:QueuePending(total and -total or nil, CATEGORIES.VENDOR_PURCHASE, {
		itemLink = link,
		itemId = GetItemIdFromLink(link),
		qty = qty,
		gross = total and -total or nil,
		sub = "buyback",
	})
end

function module:OnSellMerchantItem(bag, slot, quantity)
	if not self:IsCategoryEnabled(CATEGORIES.VENDOR_SALE) then
		return
	end
	local link = GetContainerItemLink(bag, slot)
	local itemId = GetItemIdFromLink(link)
	local itemInfo = GetContainerItemInfo and GetContainerItemInfo(bag, slot)
	local stackCount
	if type(itemInfo) == "table" then
		stackCount = itemInfo.stackCount
	else
		stackCount = itemInfo
	end
	local qty = quantity or stackCount or 1
	local sellPrice = link and select(11, GetItemInfo(link)) or nil
	local total = sellPrice and sellPrice > 0 and (sellPrice * qty) or nil
	self:QueuePending(total, CATEGORIES.VENDOR_SALE, {
		itemLink = link,
		itemId = itemId,
		qty = qty,
		gross = total,
	})
end

function module:OnRepairAllItems(useGuild)
	local repairEnabled = self:IsCategoryEnabled(CATEGORIES.REPAIR)
	local guildRepairEnabled = self:IsCategoryEnabled(CATEGORIES.GUILD_REPAIR)
	if not repairEnabled and not guildRepairEnabled then
		return
	end
	local cost, canRepair, guildRepair = GetRepairAllCost()
	if not cost or cost <= 0 then
		return
	end
	if guildRepair then
		if guildRepairEnabled then
			self:AddRecord({
				cat = CATEGORIES.GUILD_REPAIR,
				delta = -cost,
				net = -cost,
				gross = -cost,
				sub = "guild",
			})
		end
		return
	end
	if not repairEnabled then
		return
	end
	self:QueuePending(-cost, CATEGORIES.REPAIR, { gross = -cost })
end

function module:OnTakeTaxiNode(node)
	if not self:IsCategoryEnabled(CATEGORIES.TAXI) then
		return
	end
	if not node or not TaxiNodeCost then
		return
	end
	local cost = TaxiNodeCost(node)
	if cost and cost > 0 then
		self:QueuePending(-cost, CATEGORIES.TAXI, { gross = -cost })
	end
end

function module:OnBuyTrainerService(index)
	if not self:IsCategoryEnabled(CATEGORIES.TRAINING) then
		return
	end
	if not index then
		return
	end
	local cost = GetTrainerServiceCost(index)
	if cost and cost > 0 then
		self:QueuePending(-cost, CATEGORIES.TRAINING, { gross = -cost })
	end
end

function module:OnResetTalents()
	if not self:IsCategoryEnabled(CATEGORIES.RESPEC) then
		return
	end
	local cost = GetTalentResetCost and GetTalentResetCost() or 0
	if cost and cost > 0 then
		self:QueuePending(-cost, CATEGORIES.RESPEC, { gross = -cost })
	end
end

function module:OnDepositGuildBankMoney(amount)
	if not self:IsCategoryEnabled(CATEGORIES.GUILD_BANK) then
		return
	end
	if amount and amount > 0 then
		self:QueuePending(-amount, CATEGORIES.GUILD_BANK, { gross = -amount, sub = "deposit" })
	end
end

function module:OnWithdrawGuildBankMoney(amount)
	if not self:IsCategoryEnabled(CATEGORIES.GUILD_BANK) then
		return
	end
	if amount and amount > 0 then
		self:QueuePending(amount, CATEGORIES.GUILD_BANK, { gross = amount, sub = "withdraw" })
	end
end

function module:OnSendMail()
	if not self:IsCategoryEnabled(CATEGORIES.MAIL) then
		return
	end
	local cost = GetSendMailPrice and GetSendMailPrice() or 0
	if cost and cost > 0 then
		self:QueuePending(-cost, CATEGORIES.MAIL, { gross = -cost, sub = "postage" })
	end
end

function module:OnTakeInboxMoney(index)
	if not index then
		return
	end
	if self:IsMailIndexProcessed(index) then
		return
	end
	local sender, subject, money = GetInboxHeaderInfo(index)
	money = tonumber(money) or 0
	if money <= 0 then
		return
	end

	local invoiceType, itemName, playerName, bid, buyout, deposit, consignment, invoiceMoney = GetInboxInvoiceInfo(index)
	if invoiceType == "seller" or invoiceType == "seller_temp_invoice" then
		local mailMoney = invoiceMoney or money or 0
		local cut = consignment or 0
		local depositValue = deposit or 0
		local gross = 0
		if bid and bid > 0 then
			gross = bid
		elseif buyout and buyout > 0 then
			gross = buyout
		end
		local recordId, record = self:FindPendingSaleRecord(itemName, gross > 0 and gross or nil)
		if record and gross == 0 then
			gross = record.gross or 0
		end
		if gross == 0 then
			gross = mailMoney + cut + depositValue
		end
		local profit = gross - cut - depositValue
		if record then
			record.gross = gross
			record.cut = cut
			record.deposit = depositValue
			record.delta = mailMoney
			record.net = mailMoney
			record.profit = profit
			record.mail = mailMoney
			record.pendingMail = false
			if not record.itemLink and itemName then
				local link = select(2, GetItemInfo(itemName))
				record.itemLink = link or itemName
				record.itemId = record.itemId or GetItemIdFromLink(record.itemLink)
			end
			if playerName and playerName ~= "" then
				record.buyer = playerName
			end
			if recordId then
				self.pendingSales[recordId] = nil
			end
			self:RebuildAggregates()
			self:RebuildSession()
			self:NotifyUpdate()
		else
			local itemLink = itemName
			if itemName then
				local link = select(2, GetItemInfo(itemName))
				if link then
					itemLink = link
				end
			end
			self:AddRecord({
				cat = CATEGORIES.AUCTION_SALE,
				sub = "sold",
				itemLink = itemLink,
				itemId = GetItemIdFromLink(itemLink),
				qty = 1,
				gross = gross,
				cut = cut,
				deposit = depositValue,
				delta = mailMoney,
				net = mailMoney,
				profit = profit,
				mail = mailMoney,
				buyer = playerName,
				force = true,
			})
		end
		self:QueueIgnore(money)
		self:MarkMailIndexProcessed(index)
		return
	end

	if self:IsAuctionHouseMail(sender, subject) then
		self:QueuePending(money, CATEGORIES.AUCTION_SALE, {
			note = subject,
			gross = money,
			net = money,
			profit = money,
			sub = "mail",
		})
	else
		self:QueuePending(money, CATEGORIES.MAIL, {
			note = subject,
			gross = money,
		})
	end
	self:MarkMailIndexProcessed(index)
end

function module:OnTakeInboxItem(index)
	if not index then
		return
	end
	if self:IsMailIndexProcessed(index) then
		return
	end
	local _, _, _, cod = GetInboxHeaderInfo(index)
	cod = tonumber(cod) or 0
	if cod <= 0 then
		return
	end
	if not self:IsCategoryEnabled(CATEGORIES.COD) then
		return
	end
	local link = GetInboxItemLink and GetInboxItemLink(index)
	local _, itemId, count = GetInboxItem(index)
	self:QueuePending(-cod, CATEGORIES.COD, {
		itemLink = link,
		itemId = itemId,
		qty = count or 1,
		gross = -cod,
	})
	self:MarkMailIndexProcessed(index)
end

function module:OnAutoLootMailItem(index)
	if not index or self:IsMailIndexProcessed(index) then
		return
	end
	local _, _, money, cod = GetInboxHeaderInfo(index)
	money = tonumber(money) or 0
	cod = tonumber(cod) or 0
	if money > 0 then
		self:OnTakeInboxMoney(index)
	end
	if cod > 0 then
		self:OnTakeInboxItem(index)
	end
end

function module:OnTradeClosed()
	if not self.tradeAccepted then
		return
	end
	self.tradeAccepted = false
	if not self:IsCategoryEnabled(CATEGORIES.TRADE) then
		return
	end
	local given = GetPlayerTradeMoney and GetPlayerTradeMoney() or 0
	local received = GetTargetTradeMoney and GetTargetTradeMoney() or 0
	local delta = (received or 0) - (given or 0)
	if delta ~= 0 then
		self:QueuePending(delta, CATEGORIES.TRADE, { gross = delta })
	end
end

function module:TRADE_ACCEPT_UPDATE(_, playerAccepted, targetAccepted)
	if playerAccepted == 1 and targetAccepted == 1 then
		self.tradeAccepted = true
	end
end

function module:TRADE_CLOSED()
	self:OnTradeClosed()
end

function module:ToggleFrame()
	if not self.frame then
		return
	end
	if self.frame:IsShown() then
		self.frame:Hide()
	else
		self.frame:Show()
		self:UpdateSummary()
		self:UpdateLedger()
	end
end

function module:SavePosition()
	if not self.frame or not self.db.position then
		return
	end
	local point, _, _, x, y = self.frame:GetPoint()
	self.db.position.point = point
	self.db.position.x = x
	self.db.position.y = y
end

function module:SaveSize(width, height)
	if not self.db.size then
		self.db.size = {}
	end
	self.db.size.width = width
	self.db.size.height = height
end

local function SetTabBackdrop(tab, selected)
	if not tab then
		return
	end
	local target = tab.backdrop or tab
	if not target.SetBackdropBorderColor then
		return
	end
	local color = selected and E.media.rgbvaluecolor or E.media.bordercolor
	local r, g, b = color.r or color[1], color.g or color[2], color.b or color[3]
	target:SetBackdropBorderColor(r, g, b)
end

function module:SelectTab(index)
	if not self.frame or not self.frame.pages then
		return
	end
	local ES = E:GetModule("Skins")
	local useSkins = ES and ES.HandleButton
	for i, page in ipairs(self.frame.pages) do
		page:SetShown(i == index)
		local tab = self.frame.tabs and self.frame.tabs[i]
		if tab then
			if useSkins and tab.backdrop then
				tab.__selected = (i == index)
				SetTabBackdrop(tab, tab.__selected)
			else
				if i == index then
					tab:LockHighlight()
				else
					tab:UnlockHighlight()
				end
			end
		end
	end
end

function module:CycleScope()
	local options = { "CHAR", "REALM", "ACCOUNT" }
	local current = self.view.scope or "CHAR"
	local nextIndex = 1
	for i = 1, #options do
		if options[i] == current then
			nextIndex = i + 1
			break
		end
	end
	if nextIndex > #options then
		nextIndex = 1
	end
	self.view.scope = options[nextIndex]
	self:UpdateSummary()
	self:UpdateLedger()
end

function module:CycleTimeframe()
	local options = { "SESSION", "TODAY", "WEEK", "ROLLING", "LIFETIME" }
	local current = self.view.timeframe or "SESSION"
	local nextIndex = 1
	for i = 1, #options do
		if options[i] == current then
			nextIndex = i + 1
			break
		end
	end
	if nextIndex > #options then
		nextIndex = 1
	end
	self.view.timeframe = options[nextIndex]
	self:UpdateSummary()
	self:UpdateLedger()
end

function module:UpdateSummary()
	if not self.frame or not self.frame.summary then
		return
	end
	local summary = self.frame.summary
	local scope = self.view.scope or "CHAR"
	local timeframe = self.view.timeframe or "SESSION"
	local bucket = self:GetBucketForTimeframe(scope, timeframe) or {}

	if summary.scopeDropDown and UIDropDownMenu_SetText then
		UIDropDownMenu_SetText(summary.scopeDropDown, self:GetScopeLabel(scope))
	end
	if summary.timeDropDown and UIDropDownMenu_SetText then
		UIDropDownMenu_SetText(summary.timeDropDown, self:GetTimeframeLabel(timeframe))
	end

	if summary.metricTexts then
		summary.metricTexts.earned:SetText(format("%s: %s", L["Earned"], self:FormatMoney(bucket.earned or 0)))
		summary.metricTexts.spent:SetText(format("%s: %s", L["Spent"], self:FormatMoney(-(bucket.spent or 0))))
		summary.metricTexts.net:SetText(format("%s: %s", L["Net"], self:FormatMoney(bucket.net or 0)))
		summary.metricTexts.profit:SetText(format("%s: %s", L["Profit"], self:FormatMoney(bucket.profit or 0)))
	elseif summary.earnedValue then
		summary.earnedValue:SetText(self:FormatMoney(bucket.earned or 0))
		summary.spentValue:SetText(self:FormatMoney(-(bucket.spent or 0)))
		summary.netValue:SetText(self:FormatMoney(bucket.net or 0))
		summary.profitValue:SetText(self:FormatMoney(bucket.profit or 0))
	end

	self:UpdateSummaryLayout()
	self:UpdateCharacterSummary()
	self:UpdateSummaryGraph()
end

function module:UpdateSummaryLayout()
	if not self.frame or not self.frame.summary then
		return
	end
	local summary = self.frame.summary

	if summary.headerRow and summary.scopeGroup and summary.timeGroup then
		local width = summary.headerRow:GetWidth()
		if width and width > 0 then
			local half = floor(width / 2)
			summary.scopeGroup:ClearAllPoints()
			summary.scopeGroup:SetPoint("LEFT", summary.headerRow, "LEFT", 0, 0)
			summary.scopeGroup:SetWidth(half)
			summary.timeGroup:ClearAllPoints()
			summary.timeGroup:SetPoint("LEFT", summary.headerRow, "LEFT", half, 0)
			summary.timeGroup:SetWidth(half)
		end
	end

	if summary.metricRow and summary.metricTexts then
		local width = summary.metricRow:GetWidth()
		if width and width > 0 then
			local segment = floor(width / 4)
			local keys = { "earned", "spent", "net", "profit" }
			for i = 1, #keys do
				local text = summary.metricTexts[keys[i]]
				if text then
					text:SetWidth(segment)
					text:ClearAllPoints()
					text:SetPoint("LEFT", summary.metricRow, "LEFT", (i - 1) * segment, 0)
				end
			end
		end
	end
end

function module:GetCharacterSummaryList(scope)
	local list = {}
	local seen = {}
	local scopeMode = scope or (self.view and self.view.scope) or "CHAR"
	local function AddEntry(name, realm, gold, source)
		if not name or name == "" or not realm or realm == "" then
			return
		end
		if scopeMode == "CHAR" then
			if realm ~= E.myrealm or name ~= E.myname then
				return
			end
		elseif scopeMode == "REALM" then
			if realm ~= E.myrealm then
				return
			end
		end
		local key = realm .. ":" .. name
		local existing = seen[key]
		if not existing or source > existing.source then
			seen[key] = {
				source = source,
				entry = {
					name = name,
					realm = realm,
					gold = gold or 0,
				},
			}
		end
	end

	if self.global and self.global.characters then
		for realm, chars in pairs(self.global.characters) do
			for name, info in pairs(chars) do
				local gold = info.gold or info.lastLogoutGold or 0
				AddEntry(name, realm, gold, 2)
			end
		end
	end

	if _G.ElvDB and _G.ElvDB.gold then
		for realm, chars in pairs(_G.ElvDB.gold) do
			if type(chars) == "table" then
				for name, gold in pairs(chars) do
					AddEntry(name, realm, gold, 1)
				end
			end
		end
	end

	AddEntry(E.myname, E.myrealm, GetMoney(), 3)

	for _, data in pairs(seen) do
		tinsert(list, data.entry)
	end
	table.sort(list, function(a, b)
		if a.gold == b.gold then
			if a.realm == b.realm then
				return a.name < b.name
			end
			return a.realm < b.realm
		end
		return a.gold > b.gold
	end)
	return list
end

function module:UpdateCharacterSummary()
	if not self.frame or not self.frame.summary or not self.frame.summary.charSummary then
		return
	end
	local summary = self.frame.summary
	local charSummary = summary.charSummary
	local scrollFrame = charSummary.scrollFrame
	local list = self:GetCharacterSummaryList(self.view and self.view.scope or "CHAR")
	charSummary.records = list

	local rowHeight = charSummary.rowHeight
	local offset = FauxScrollFrame_GetOffset(scrollFrame)
	local total = #list
	FauxScrollFrame_Update(scrollFrame, total, #charSummary.rows, rowHeight)

	for i = 1, #charSummary.rows do
		local row = charSummary.rows[i]
		local index = i + offset
		local data = list[index]
		if data then
			local nameText = data.name or ""
			if data.realm and data.realm ~= "" then
				nameText = nameText .. " - " .. data.realm
			end
			row.name:SetText(nameText)
			row.gold:SetText(self:FormatMoney(data.gold or 0))
			row:Show()
		else
			row:Hide()
		end
	end
end

function module:UpdateCharacterLayout()
	if not self.frame or not self.frame.summary or not self.frame.summary.charSummary then
		return
	end
	local charSummary = self.frame.summary.charSummary
	local scroll = charSummary.scrollFrame
	if not scroll then
		return
	end
	local width = scroll:GetWidth()
	if not width or width <= 0 then
		return
	end
	width = width - 6

	local padding = 8
	local goldW = 110
	local nameW = width - (goldW + padding)
	if nameW < 120 then
		nameW = 120
	end

	local columns = {
		{ key = "name", width = nameW, justify = "LEFT" },
		{ key = "gold", width = goldW, justify = "RIGHT" },
	}

	local x = 0
	for i = 1, #columns do
		local col = columns[i]
		local header = charSummary.headers[col.key]
		if header then
			header:SetWidth(col.width)
			header:ClearAllPoints()
			header:SetPoint("BOTTOMLEFT", scroll, "TOPLEFT", x, 4)
			header:SetJustifyH(col.justify)
		end
		for _, row in ipairs(charSummary.rows) do
			local cell = row[col.key]
			if cell then
				cell:SetWidth(col.width)
				cell:SetJustifyH(col.justify)
				cell:SetPoint("LEFT", row, "LEFT", x, 0)
			end
		end
		x = x + col.width + padding
	end
end

function module:UpdateLedgerLayout()
	if not self.frame or not self.frame.ledger then
		return
	end
	local ledger = self.frame.ledger
	local scroll = ledger.scrollFrame
	if not scroll then
		return
	end
	local width = scroll:GetWidth()
	if not width or width <= 0 then
		return
	end
	width = width - 6
	local padding = 8
	local timeW = 110
	local catW = 110
	local qtyW = 40
	local deltaW = 90
	local netW = 90
	local itemW = width - (timeW + catW + qtyW + deltaW + netW + padding * 4)
	if itemW < 120 then
		itemW = 120
	end

	local columns = {
		{ key = "time", width = timeW, justify = "LEFT" },
		{ key = "category", width = catW, justify = "LEFT" },
		{ key = "item", width = itemW, justify = "LEFT" },
		{ key = "qty", width = qtyW, justify = "RIGHT" },
		{ key = "delta", width = deltaW, justify = "RIGHT" },
		{ key = "net", width = netW, justify = "RIGHT" },
	}

	local x = 0
	for i = 1, #columns do
		local col = columns[i]
		local header = ledger.headers[col.key]
		if header then
			header:SetWidth(col.width)
			header:ClearAllPoints()
			header:SetPoint("BOTTOMLEFT", scroll, "TOPLEFT", x, 4)
			if header.text then
				header.text:SetJustifyH(col.justify)
			end
		end
		for _, row in ipairs(ledger.rows) do
			local cell = row[col.key]
			if cell then
				cell:SetWidth(col.width)
				cell:SetJustifyH(col.justify)
				cell:SetPoint("LEFT", row, "LEFT", x, 0)
			end
		end
		x = x + col.width + padding
	end
end

function module:UpdateLedger()
	if not self.frame or not self.frame.ledger then
		return
	end
	local ledger = self.frame.ledger
	local scope = self.view.scope or "CHAR"
	local timeframe = self.view.timeframe or "SESSION"
	local search = self.view.search or ""

	local records = self:GetFilteredRecords(scope, timeframe, search)
	self:SortRecords(records)
	self.displayRecords = records

	local scrollFrame = ledger.scrollFrame
	local rowHeight = ledger.rowHeight
	local offset = FauxScrollFrame_GetOffset(scrollFrame)
	local total = #records
	FauxScrollFrame_Update(scrollFrame, total, #ledger.rows, rowHeight)

	for i = 1, #ledger.rows do
		local row = ledger.rows[i]
		local index = i + offset
		local record = records[index]
		if record then
			row.record = record
			local deltaValue = record.delta or 0
			if record.cat == CATEGORIES.AUCTION_SALE and record.gross then
				deltaValue = record.gross
			end
			row.time:SetText(date("%m/%d %H:%M", record.ts or 0))
			row.category:SetText(self:GetCategoryLabel(record.cat, record.sub))
			row.item:SetText(record.itemLink or record.note or "")
			row.qty:SetText(record.qty or 1)
			row.delta:SetText(self:FormatMoney(deltaValue))
			row.net:SetText(self:FormatMoney(record.net or record.delta or 0))
			row:Show()
		else
			row.record = nil
			row:Hide()
		end
	end
end

function module:CreateSummaryTab(parent)
	local summary = CreateFrame("Frame", nil, parent)
	summary:SetAllPoints(parent)
	local ES = E:GetModule("Skins")
	local function SkinDropDown(dropdown, width)
		if not dropdown then
			return
		end
		dropdown:SetHeight(22)
		if ES and ES.HandleDropDownBox then
			ES:HandleDropDownBox(dropdown, width, "Transparent")
		end
		local name = dropdown:GetName()
		local text = dropdown.Text or (name and _G[name.."Text"])
		if text and dropdown.backdrop then
			text:ClearAllPoints()
			text:SetPoint("LEFT", dropdown.backdrop, "LEFT", 6, 0)
			text:SetPoint("RIGHT", dropdown.backdrop, "RIGHT", -18, 0)
			text:SetJustifyH("LEFT")
		end
		local button = dropdown.Button or (name and _G[name.."Button"])
		if button then
			button:ClearAllPoints()
			button:SetAllPoints(dropdown)
		end
	end
	summary:SetScript("OnShow", function()
		self:UpdateSummaryLayout()
		self:UpdateCharacterLayout()
		self:UpdateCharacterSummary()
		self:UpdateSummaryGraph()
	end)

	local headerRow = CreateFrame("Frame", nil, summary)
	headerRow:SetPoint("TOPLEFT", summary, "TOPLEFT", 10, -10)
	headerRow:SetPoint("RIGHT", summary, "RIGHT", -10, 0)
	headerRow:SetHeight(24)

	local scopeGroup = CreateFrame("Frame", nil, headerRow)
	scopeGroup:SetHeight(24)

	local timeGroup = CreateFrame("Frame", nil, headerRow)
	timeGroup:SetHeight(24)

	local scopeLabel = scopeGroup:CreateFontString(nil, "OVERLAY")
	scopeLabel:Point("LEFT", scopeGroup, "LEFT", 0, 0)
	scopeLabel:FontTemplate()
	scopeLabel:SetText(L["Scope"])

	local scopeDropDown = CreateFrame("Frame", "AzUI_SalesLedgerScopeDropDown", scopeGroup, "UIDropDownMenuTemplate")
	scopeDropDown:SetPoint("LEFT", scopeLabel, "RIGHT", 6, 0)
	UIDropDownMenu_SetWidth(scopeDropDown, 140)
	UIDropDownMenu_JustifyText(scopeDropDown, "LEFT")
	SkinDropDown(scopeDropDown, 140)
	UIDropDownMenu_Initialize(scopeDropDown, function()
		local items = { "CHAR", "REALM", "ACCOUNT" }
		for i = 1, #items do
			local key = items[i]
			local info = UIDropDownMenu_CreateInfo()
			info.text = self:GetScopeLabel(key)
			info.arg1 = key
			info.func = function(_, arg1)
				self.view.scope = arg1
				UIDropDownMenu_SetText(scopeDropDown, self:GetScopeLabel(arg1))
				self:UpdateSummary()
				self:UpdateLedger()
			end
			info.checked = (self.view.scope == key)
			UIDropDownMenu_AddButton(info)
		end
	end)

	local timeLabel = timeGroup:CreateFontString(nil, "OVERLAY")
	timeLabel:Point("LEFT", timeGroup, "LEFT", 0, 0)
	timeLabel:FontTemplate()
	timeLabel:SetText(L["Timeframe"])

	local timeDropDown = CreateFrame("Frame", "AzUI_SalesLedgerTimeDropDown", timeGroup, "UIDropDownMenuTemplate")
	timeDropDown:SetPoint("LEFT", timeLabel, "RIGHT", 6, 0)
	UIDropDownMenu_SetWidth(timeDropDown, 140)
	UIDropDownMenu_JustifyText(timeDropDown, "LEFT")
	SkinDropDown(timeDropDown, 140)
	UIDropDownMenu_Initialize(timeDropDown, function()
		local items = { "SESSION", "TODAY", "WEEK", "ROLLING", "LIFETIME" }
		for i = 1, #items do
			local key = items[i]
			local info = UIDropDownMenu_CreateInfo()
			info.text = self:GetTimeframeLabel(key)
			info.arg1 = key
			info.func = function(_, arg1)
				self.view.timeframe = arg1
				UIDropDownMenu_SetText(timeDropDown, self:GetTimeframeLabel(arg1))
				self:UpdateSummary()
				self:UpdateLedger()
			end
			info.checked = (self.view.timeframe == key)
			UIDropDownMenu_AddButton(info)
		end
	end)

	local metricRow = CreateFrame("Frame", nil, summary)
	metricRow:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", 0, -8)
	metricRow:SetPoint("RIGHT", summary, "RIGHT", -10, 0)
	metricRow:SetHeight(18)

	local earnedText = metricRow:CreateFontString(nil, "OVERLAY")
	earnedText:FontTemplate()
	earnedText:SetJustifyH("LEFT")

	local spentText = metricRow:CreateFontString(nil, "OVERLAY")
	spentText:FontTemplate()
	spentText:SetJustifyH("LEFT")

	local netText = metricRow:CreateFontString(nil, "OVERLAY")
	netText:FontTemplate()
	netText:SetJustifyH("LEFT")

	local profitText = metricRow:CreateFontString(nil, "OVERLAY")
	profitText:FontTemplate()
	profitText:SetJustifyH("LEFT")

	local graphHeader = summary:CreateFontString(nil, "OVERLAY")
	graphHeader:Point("TOPLEFT", metricRow, "BOTTOMLEFT", 0, -16)
	graphHeader:FontTemplate()
	graphHeader:SetText(L["Net"])

	local graph = CreateFrame("Frame", nil, summary)
	graph:SetPoint("TOPLEFT", graphHeader, "BOTTOMLEFT", 0, -6)
	graph:SetPoint("RIGHT", summary, "RIGHT", -10, 0)
	graph:SetHeight(120)
	graph.bars = {}

	graph.bg = graph:CreateTexture(nil, "BACKGROUND")
	graph.bg:SetAllPoints()
	graph.bg:SetColorTexture(0, 0, 0, 0.2)

	local charSummary = CreateFrame("Frame", nil, summary)
	charSummary:SetPoint("TOPLEFT", graph, "BOTTOMLEFT", 0, -12)
	charSummary:SetPoint("BOTTOMRIGHT", summary, "BOTTOMRIGHT", -10, 10)
	charSummary.rowHeight = 18
	charSummary.rows = {}
	charSummary.headers = {}

	local scrollFrame = CreateFrame("ScrollFrame", nil, charSummary, "FauxScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", charSummary, "TOPLEFT", 0, -20)
	scrollFrame:SetPoint("BOTTOMRIGHT", charSummary, "BOTTOMRIGHT", -26, 0)
	scrollFrame:SetScript("OnVerticalScroll", function(_, offset)
		FauxScrollFrame_OnVerticalScroll(scrollFrame, offset, charSummary.rowHeight, function() self:UpdateCharacterSummary() end)
	end)
	charSummary.scrollFrame = scrollFrame

	local charColumns = {
		{ key = "name", label = L["Character"] },
		{ key = "gold", label = L["Gold"] },
	}

	for i = 1, #charColumns do
		local col = charColumns[i]
		local header = charSummary:CreateFontString(nil, "OVERLAY")
		header:FontTemplate()
		header:SetText(col.label)
		charSummary.headers[col.key] = header
	end

	for i = 1, 8 do
		local row = CreateFrame("Frame", nil, charSummary)
		row:SetHeight(charSummary.rowHeight)
		row:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, -((i - 1) * charSummary.rowHeight))
		row:SetPoint("RIGHT", scrollFrame, "RIGHT", -4, 0)

		row.name = row:CreateFontString(nil, "OVERLAY")
		row.gold = row:CreateFontString(nil, "OVERLAY")

		row.name:FontTemplate()
		row.gold:FontTemplate()

		charSummary.rows[i] = row
	end

	summary.scopeDropDown = scopeDropDown
	summary.timeDropDown = timeDropDown
	summary.headerRow = headerRow
	summary.scopeGroup = scopeGroup
	summary.timeGroup = timeGroup
	summary.metricRow = metricRow
	summary.metricTexts = {
		earned = earnedText,
		spent = spentText,
		net = netText,
		profit = profitText,
	}
	summary.graphHeader = graphHeader
	summary.graph = graph
	summary.charSummary = charSummary

	return summary
end

function module:CreateLedgerTab(parent)
	local ledger = CreateFrame("Frame", nil, parent)
	ledger:SetAllPoints(parent)
	ledger.rowHeight = 20
	ledger.rows = {}
	ledger.headers = {}
	ledger:SetScript("OnShow", function()
		self:UpdateLedgerLayout()
		self:UpdateLedger()
	end)

	local scrollFrame = CreateFrame("ScrollFrame", nil, ledger, "FauxScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", ledger, "TOPLEFT", 0, -24)
	scrollFrame:SetPoint("BOTTOMRIGHT", ledger, "BOTTOMRIGHT", -26, 0)
	scrollFrame:SetScript("OnVerticalScroll", function(_, offset)
		FauxScrollFrame_OnVerticalScroll(scrollFrame, offset, ledger.rowHeight, function() self:UpdateLedger() end)
	end)
	ledger.scrollFrame = scrollFrame

	local columns = {
		{ key = "time", label = L["Time"] },
		{ key = "category", label = L["Category"] },
		{ key = "item", label = L["Item"] },
		{ key = "qty", label = L["Qty"] },
		{ key = "delta", label = L["Gold Delta"] },
		{ key = "net", label = L["Net"] },
	}

	for i = 1, #columns do
		local col = columns[i]
		local header = CreateFrame("Button", nil, ledger)
		header.text = header:CreateFontString(nil, "OVERLAY")
		header.text:FontTemplate()
		header.text:SetAllPoints()
		header.text:SetText(col.label)
		header:SetHeight(18)
		header:SetScript("OnClick", function()
			if not self.sort then
				self.sort = { key = col.key, asc = false }
			elseif self.sort.key == col.key then
				self.sort.asc = not self.sort.asc
			else
				self.sort.key = col.key
				self.sort.asc = false
			end
			self:UpdateLedger()
		end)
		ledger.headers[col.key] = header
	end

	local rowCount = 18
	for i = 1, rowCount do
		local row = CreateFrame("Button", nil, ledger)
		row:SetHeight(ledger.rowHeight)
		row:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, -((i - 1) * ledger.rowHeight))
		row:SetPoint("RIGHT", scrollFrame, "RIGHT", -4, 0)

		row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
		row.highlight:SetAllPoints()
		row.highlight:SetColorTexture(1, 1, 1, 0.08)

		row.time = row:CreateFontString(nil, "OVERLAY")
		row.category = row:CreateFontString(nil, "OVERLAY")
		row.item = row:CreateFontString(nil, "OVERLAY")
		row.qty = row:CreateFontString(nil, "OVERLAY")
		row.delta = row:CreateFontString(nil, "OVERLAY")
		row.net = row:CreateFontString(nil, "OVERLAY")

		row.time:FontTemplate()
		row.category:FontTemplate()
		row.item:FontTemplate()
		row.qty:FontTemplate()
		row.delta:FontTemplate()
		row.net:FontTemplate()

		row:SetScript("OnEnter", function()
			if not row.record then
				return
			end
			GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
			GameTooltip:ClearLines()
			if row.record.itemLink and row.record.itemLink:find("|H") then
				GameTooltip:SetHyperlink(row.record.itemLink)
			else
				GameTooltip:AddLine(row.record.itemLink or row.record.note or L["Details"])
			end
			GameTooltip:AddLine(self:GetCategoryLabel(row.record.cat, row.record.sub), 1, 1, 1)
			if row.record.gross then
				GameTooltip:AddDoubleLine(L["Gross"], self:FormatMoney(row.record.gross), 1, 1, 1, 1, 1, 1)
			end
			if row.record.cut then
				GameTooltip:AddDoubleLine(L["Auction Cut"], self:FormatMoney(-row.record.cut), 1, 1, 1, 1, 1, 1)
			end
			if row.record.deposit then
				GameTooltip:AddDoubleLine(L["Auction Deposit"], self:FormatMoney(-row.record.deposit), 1, 1, 1, 1, 1, 1)
			end
			GameTooltip:AddDoubleLine(L["Net"], self:FormatMoney(row.record.net or row.record.delta or 0), 1, 1, 1, 1, 1, 1)
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)

		ledger.rows[i] = row
	end
	return ledger
end

function module:CreateFiltersTab(parent)
	local filters = CreateFrame("Frame", nil, parent)
	filters:SetAllPoints(parent)

	local searchLabel = filters:CreateFontString(nil, "OVERLAY")
	searchLabel:Point("TOPLEFT", filters, "TOPLEFT", 10, -10)
	searchLabel:FontTemplate()
	searchLabel:SetText(L["Filter"])

	local searchBox = CreateFrame("EditBox", nil, filters, "InputBoxTemplate")
	searchBox:SetSize(200, 20)
	searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 10, 0)
	searchBox:SetAutoFocus(false)
	searchBox:SetScript("OnTextChanged", function(self)
		module.view.search = self:GetText() or ""
		module:UpdateLedger()
	end)

	local clearButton = CreateFrame("Button", nil, filters, "UIPanelButtonTemplate")
	clearButton:SetSize(60, 20)
	clearButton:SetPoint("LEFT", searchBox, "RIGHT", 6, 0)
	clearButton:SetText(L["Clear"])
	clearButton:SetScript("OnClick", function()
		searchBox:SetText("")
	end)

	local categories = {
		CATEGORIES.QUEST,
		CATEGORIES.LOOT,
		CATEGORIES.VENDOR_SALE,
		CATEGORIES.VENDOR_PURCHASE,
		CATEGORIES.AUCTION_SALE,
		CATEGORIES.AUCTION_PURCHASE,
		CATEGORIES.AUCTION_EXPIRED,
		CATEGORIES.AUCTION_CANCELED,
		CATEGORIES.MAIL,
		CATEGORIES.TRADE,
		CATEGORIES.COD,
		CATEGORIES.REPAIR,
		CATEGORIES.TAXI,
		CATEGORIES.TRAINING,
		CATEGORIES.RESPEC,
		CATEGORIES.GUILD_REPAIR,
		CATEGORIES.GUILD_BANK,
		CATEGORIES.OTHER,
	}

	local startY = -40
	local columnWidth = 180
	local column = 0
	local row = 0
	for i = 1, #categories do
		local key = categories[i]
		local check = CreateFrame("CheckButton", nil, filters, "UICheckButtonTemplate")
		check:SetPoint("TOPLEFT", filters, "TOPLEFT", 10 + (column * columnWidth), startY - (row * 24))
		check.Text:SetText(self:GetCategoryLabel(key))
		check:SetChecked(self.db.filters.categories[key] ~= false)
		check:SetScript("OnClick", function(btn)
			self.db.filters.categories[key] = btn:GetChecked()
			self:UpdateLedger()
			self:UpdateSummary()
		end)
		row = row + 1
		if row >= 8 then
			row = 0
			column = column + 1
		end
	end

	return filters
end

function module:CreateMainFrame()
	if self.frame then
		return
	end
	local ES = E:GetModule("Skins")
	local frame = CreateFrame("Frame", "AzUI_SalesLedgerFrame", E.UIParent, "BackdropTemplate")
	local width = (self.db.size and self.db.size.width) or 720
	local height = (self.db.size and self.db.size.height) or 420
	frame:SetSize(width, height)
	if self.db.position and self.db.position.point then
		frame:SetPoint(self.db.position.point, UIParent, self.db.position.point, self.db.position.x or 0, self.db.position.y or 0)
	else
		frame:SetPoint("CENTER")
	end
	frame:SetMovable(true)
	frame:SetResizable(false)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function()
		if InCombatLockdown() then return end
		frame:StartMoving()
	end)
	frame:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		self:SavePosition()
	end)
	frame:SetScript("OnSizeChanged", function(_, w, h)
		self:SaveSize(w, h)
		self:UpdateLedgerLayout()
		self:UpdateCharacterLayout()
		self:UpdateSummaryGraph()
		self:UpdateSummaryLayout()
	end)
	frame:SetScript("OnShow", function()
		self:UpdateLedgerLayout()
		self:UpdateCharacterLayout()
	end)

	frame:CreateBackdrop("Transparent")
	frame.backdrop:Styling()

	local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 3, 3)
	if ES and ES.HandleCloseButton then
		ES:HandleCloseButton(closeButton)
	end

	local title = frame:CreateFontString(nil, "OVERLAY")
	title:Point("TOP", frame, "TOP", 0, -8)
	title:FontTemplate(nil, 14, "OUTLINE")
	title:SetText(L["Sales Ledger"])

	local tabWidth = 110
	local tabHeight = 22
	local tabSpacing = 6

	frame.content = CreateFrame("Frame", nil, frame)
	frame.content:SetPoint("TOPLEFT", frame, "TOPLEFT", tabWidth + 20, -50)
	frame.content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)

	frame.pages = {}
	frame.pages[1] = self:CreateSummaryTab(frame.content)
	frame.pages[2] = self:CreateLedgerTab(frame.content)
	frame.pages[3] = self:CreateFiltersTab(frame.content)
	frame.summary = frame.pages[1]
	frame.ledger = frame.pages[2]
	frame.filters = frame.pages[3]

	self.frame = frame

	local tabNames = { L["Summary"], L["Ledger"], L["Filters"] }
	local frameName = frame:GetName() or "AzUI_SalesLedgerFrame"
	local tabHolder = CreateFrame("Frame", frameName.."TabHolder", frame)
	tabHolder:SetSize(tabWidth, (#tabNames * (tabHeight + tabSpacing)) - tabSpacing)
	tabHolder:SetPoint("LEFT", frame, "LEFT", 8, 0)
	local tabLogo = frame:CreateTexture(nil, "ARTWORK")
	tabLogo:SetTexture([[Interface\AddOns\ElvUI_AzUI\Core\Media\Textures\AzUI_Banner.tga]])
	tabLogo:SetSize(tabWidth, tabWidth)
	tabLogo:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 10)
	tabLogo:SetAlpha(0.85)
	frame.tabLogo = tabLogo
	frame.tabs = {}
	for i = 1, #tabNames do
		local tab = CreateFrame("Button", frameName.."Tab"..i, tabHolder, "UIPanelButtonTemplate")
		tab:SetSize(tabWidth, tabHeight)
		tab:SetText(tabNames[i])
		tab:SetScript("OnClick", function() self:SelectTab(i) end)
		if ES and ES.HandleButton then
			ES:HandleButton(tab, true, nil, nil, true, "Transparent")
			tab:HookScript("OnLeave", function(self)
				if self.__selected then
					SetTabBackdrop(self, true)
				end
			end)
		end
		if i == 1 then
			tab:SetPoint("TOP", tabHolder, "TOP", 0, 0)
		else
			tab:SetPoint("TOP", frame.tabs[i - 1], "BOTTOM", 0, -tabSpacing)
		end
		frame.tabs[i] = tab
	end
	self:SelectTab(1)

	frame:Hide()
	self:UpdateLedgerLayout()
end

function module:Initialize()
	if E.Retail then
		self.StopRunning = "Retail"
		return
	end

	self:RegisterSlashCommands()

	if not E.db.mui.salesLedger or not E.db.mui.salesLedger.enable then
		return
	end

	self.db = E.db.mui.salesLedger
	self.global = E.global.mui.salesLedger

	self.global.records = self.global.records or {}
	self.global.aggregates = self.global.aggregates or {}
	self.global.auctions = self.global.auctions or { pending = {} }
	self.global.characters = self.global.characters or {}

	self.pendingQueue = {}
	self.pendingBids = {}
	self.pendingSales = {}
	self.lastMoney = GetMoney()
	self:CreateAlert()

	self.auctionPatterns = {
		sold = BuildSystemPattern(_G.ERR_AUCTION_SOLD_S),
		expired = BuildSystemPattern(_G.ERR_AUCTION_EXPIRED_S),
		canceled = BuildSystemPattern(_G.ERR_AUCTION_REMOVED_S),
		outbid = BuildSystemPattern(_G.ERR_AUCTION_OUTBID_S),
	}
	self.auctionMailPatterns = {
		sold = BuildSystemPattern(_G.AUCTION_SOLD_MAIL_SUBJECT),
		outbid = BuildSystemPattern(_G.AUCTION_OUTBID_MAIL_SUBJECT),
		expired = BuildSystemPattern(_G.AUCTION_EXPIRED_MAIL_SUBJECT),
		removed = BuildSystemPattern(_G.AUCTION_REMOVED_MAIL_SUBJECT),
	}

	self:RegisterEvent("PLAYER_MONEY")
	self:RegisterEvent("QUEST_TURNED_IN")
	self:RegisterEvent("CHAT_MSG_MONEY")
	self:RegisterEvent("CHAT_MSG_SYSTEM")
	self:RegisterEvent("TRADE_ACCEPT_UPDATE")
	self:RegisterEvent("TRADE_CLOSED")
	self:RegisterEvent("PLAYER_LOGOUT")
	self:RegisterEvent("AUCTION_OWNED_LIST_UPDATE")
	self:RegisterEvent("AUCTION_HOUSE_SHOW")
	if C_AuctionHouse then
		self:RegisterEvent("OWNED_AUCTIONS_UPDATED")
	end

	if _G.StartAuction then
		self:SecureHook("StartAuction", "OnStartAuction")
	end
	if _G.PostAuction then
		self:SecureHook("PostAuction", "OnPostAuction")
	end
	if _G.PlaceAuctionBid then
		self:SecureHook("PlaceAuctionBid", "OnPlaceAuctionBid")
	end
	if _G.BuyMerchantItem then
		self:SecureHook("BuyMerchantItem", "OnBuyMerchantItem")
	end
	if _G.BuybackItem then
		self:SecureHook("BuybackItem", "OnBuybackItem")
	end
	if _G.SellMerchantItem then
		self:SecureHook("SellMerchantItem", "OnSellMerchantItem")
	end
	if _G.RepairAllItems then
		self:SecureHook("RepairAllItems", "OnRepairAllItems")
	end
	if _G.TakeTaxiNode then
		self:SecureHook("TakeTaxiNode", "OnTakeTaxiNode")
	end
	if _G.BuyTrainerService then
		self:SecureHook("BuyTrainerService", "OnBuyTrainerService")
	end
	if _G.ResetTalents then
		self:SecureHook("ResetTalents", "OnResetTalents")
	end
	if _G.DepositGuildBankMoney then
		self:SecureHook("DepositGuildBankMoney", "OnDepositGuildBankMoney")
	end
	if _G.WithdrawGuildBankMoney then
		self:SecureHook("WithdrawGuildBankMoney", "OnWithdrawGuildBankMoney")
	end
	if _G.SendMail then
		self:SecureHook("SendMail", "OnSendMail")
	end
	if _G.TakeInboxMoney then
		self:SecureHook("TakeInboxMoney", "OnTakeInboxMoney")
	end
	if _G.TakeInboxItem then
		self:SecureHook("TakeInboxItem", "OnTakeInboxItem")
	end
	if _G.AutoLootMailItem then
		self:SecureHook("AutoLootMailItem", "OnAutoLootMailItem")
	end

	if self.db.purge and self.db.purge.runOnLogin then
		self:RunPurge()
	end

	self:UpdateCharacterSnapshot(false)

	self:InitializeUI()
	self:InitializeDataText()
end

function module:InitializeUI()
	if self.frame then
		return
	end
	self.view = self.view or {
		scope = self.db.scopeDefault or "CHAR",
		timeframe = self.db.datatext and self.db.datatext.defaultView or "SESSION",
		search = "",
	}
	self.db.position = self.db.position or { point = "CENTER", x = 0, y = 0 }
	self.db.size = self.db.size or { width = 720, height = 420 }
	self.sort = self.sort or { key = "time", asc = false }
	self:CreateMainFrame()
	self:UpdateSummary()
end

function module:RegisterSlashCommands()
	if self.slashRegistered then
		return
	end
	MER:RegisterChatCommand("azsales", function() module:SlashToggle() end)
	MER:RegisterChatCommand("azs", function() module:SlashToggle() end)
	self.slashRegistered = true
end

function module:SlashToggle()
	if ChatEdit_GetActiveWindow then
		local editBox = ChatEdit_GetActiveWindow()
		if editBox and editBox:IsShown() then
			local text = editBox:GetText()
			if text and (text:lower():find("^/azs") or text:lower():find("^/azsales")) then
				editBox:SetText("")
			end
		end
	end
	if not E.db.mui.salesLedger or not E.db.mui.salesLedger.enable then
		E:Print(L["Sales Ledger is disabled. Enable it in AzUI > Modules and reload."])
		return
	end
	if not self.db then
		self.db = E.db.mui.salesLedger
		self.global = E.global.mui.salesLedger
	end
	if not self.frame then
		self:InitializeUI()
	end
	self:ToggleFrame()
end

function module:InitializeDataText()
	if not self.db.datatext or not self.db.datatext.enable then
		return
	end
	local DT = E:GetModule("DataTexts")
	if not DT then
		return
	end

	local function Update(self)
		local scope = module.db.scopeDefault or "CHAR"
		local view = module.db.datatext.defaultView or "SESSION"
		local bucket = module:GetBucketForTimeframe(scope, view) or {}
		local value = module:FormatMoney(bucket.net or 0)
		if module.dtHex then
			self.text:SetText(module.dtHex .. value)
		else
			self.text:SetText(value)
		end
	end

	local function OnEvent(self)
		Update(self)
	end

	local function OnClick()
		module:ToggleFrame()
	end

	local function OnEnter(self)
		DT:SetupTooltip(self)
		DT.tooltip:AddLine(L["Sales Ledger"])
		DT.tooltip:AddLine(" ")

		local scope = module.db.scopeDefault or "CHAR"
		local timeframes = { "SESSION", "TODAY", "WEEK", "ROLLING", "LIFETIME" }
		for i = 1, #timeframes do
			local timeframe = timeframes[i]
			local bucket = module:GetBucketForTimeframe(scope, timeframe) or {}
			DT.tooltip:AddDoubleLine(module:GetTimeframeLabel(timeframe), module:FormatMoney(bucket.net or 0), 1, 1, 1, 1, 1, 1)
		end
		DT.tooltip:Show()
	end

	local function OnLeave()
		DT.tooltip:Hide()
	end

	local function ValueColorUpdate(self, hex)
		module.dtHex = hex
		Update(self)
	end

	DT:RegisterDatatext("AzUI Sales", MER.Title, { "PLAYER_MONEY", "CHAT_MSG_SYSTEM", "CHAT_MSG_MONEY", "QUEST_TURNED_IN" }, OnEvent, Update, OnClick, OnEnter, OnLeave, nil, nil, ValueColorUpdate)

	self.dtUpdate = function()
		if DT.UpdateAll then
			DT:UpdateAll()
		elseif DT.ForceUpdate then
			DT:ForceUpdate()
		end
	end
end

function module:CreateAlert()
	if self.alert then
		return
	end
	local alert = CreateFrame("Frame", "AzUI_SalesLedgerAlert", E.UIParent, "BackdropTemplate")
	alert:SetSize(380, 44)
	alert:SetPoint("CENTER", 0, 0)
	alert:SetFrameStrata("HIGH")
	alert:SetClampedToScreen(true)
	alert:EnableMouse(false)
	alert:Hide()
	alert:CreateBackdrop("Transparent")
	alert.backdrop:Styling()

	alert.icon = alert:CreateTexture(nil, "ARTWORK")
	alert.icon:SetSize(32, 32)
	alert.icon:SetPoint("LEFT", alert, "LEFT", 12, 0)

	alert.title = alert:CreateFontString(nil, "OVERLAY")
	alert.title:SetPoint("LEFT", alert.icon, "RIGHT", 10, 0)
	alert.title:SetPoint("RIGHT", alert, "RIGHT", -12, 0)
	alert.title:SetJustifyH("LEFT")
	alert.title:SetJustifyV("MIDDLE")
	alert.title:SetWordWrap(false)

	alert.text = alert:CreateFontString(nil, "OVERLAY")
	alert.text:Hide()

	self.alert = alert
	self.alertQueue = {}
	self:RefreshAlert()
	if not alert.mover then
		E:CreateMover(alert, "AzUI_SalesLedgerAlertMover", L["Sales Ledger Alert"], nil, nil, nil, "ALL,SOLO,AzUI", function()
			return self.db and self.db.notifications and self.db.notifications.enable and self.db.notifications.fade
		end, "mui,modules,salesLedger,notifications")
	end
end

function module:RefreshAlert()
	if not self.alert then
		return
	end
	local font = self.db.notifications.font
	if font then
		F.SetFontDB(self.alert.title, font)
		F.SetFontDB(self.alert.text, font)
	end
end

function module:FadeIn(seconds, func)
	local fadeInfo = {}
	fadeInfo.mode = "IN"
	fadeInfo.timeToFade = seconds
	fadeInfo.startAlpha = 0
	fadeInfo.endAlpha = 1
	fadeInfo.finishedFunc = func
	E:UIFrameFade(self.alert, fadeInfo)
end

function module:FadeOut(seconds, func)
	local fadeInfo = {}
	fadeInfo.mode = "OUT"
	fadeInfo.timeToFade = seconds
	fadeInfo.startAlpha = 1
	fadeInfo.endAlpha = 0
	fadeInfo.finishedFunc = func
	E:UIFrameFade(self.alert, fadeInfo)
end

function module:ShowAlert(title, message, icon)
	self:CreateAlert()
	if self.alertAnimating then
		tinsert(self.alertQueue, { title = title, message = message, icon = icon })
		return
	end

	self.alertAnimating = true
	self.alert.title:SetText(title or "")
	if self.alert.text then
		self.alert.text:SetText("")
	end
	if icon then
		self.alert.icon:SetTexture(icon)
		self.alert.icon:Show()
	else
		self.alert.icon:SetTexture(nil)
		self.alert.icon:Hide()
	end

	self.alert:SetAlpha(0)
	self.alert:Show()

	self:FadeIn(2, function()
		C_Timer.After(1, function()
			self:FadeOut(2, function()
				self.alert:Hide()
				self.alertAnimating = false
				if self.alertQueue and #self.alertQueue > 0 then
					local nextAlert = tremove(self.alertQueue, 1)
					if nextAlert then
						self:ShowAlert(nextAlert.title, nextAlert.message, nextAlert.icon)
					end
				end
			end)
		end)
	end)
end

function module:FlushSaleBuffer()
	local buffer = self.saleBuffer or {}
	self.saleBuffer = {}
	self.saleTimer = nil
	if #buffer == 0 then
		return
	end

	if #buffer == 1 then
		local record = buffer[1]
		local qty = record.qty or 1
		local itemText = record.itemLink or L["Item"]
		if qty > 1 then
			itemText = itemText .. " x" .. qty
		end
		local netText = self:FormatMoney(record.net or record.delta or 0)
		local icon = GetRecordIcon(record)
		local line = format("%s - %s", itemText, netText)
		self:ShowAlert(line, nil, icon)
		return
	end

	local totalNet = 0
	local totalQty = 0
	for i = 1, #buffer do
		local record = buffer[i]
		totalNet = totalNet + (record.net or record.delta or 0)
		totalQty = totalQty + (record.qty or 1)
	end
	local title = format(L["%d Items Sold"], totalQty)
	local line = format("%s - %s", title, self:FormatMoney(totalNet))
	local icon
	for i = 1, #buffer do
		icon = GetRecordIcon(buffer[i])
		if icon then
			break
		end
	end
	if not icon then
		icon = "Interface\\Icons\\INV_Misc_Coin_01"
	end
	self:ShowAlert(line, nil, icon)
end

function module:QueueAuctionNotification(record)
	if not record then
		return
	end
	if not self.db.notifications or not self.db.notifications.enable then
		return
	end
	if not self.db.notifications.fade then
		return
	end
	self.saleBuffer = self.saleBuffer or {}
	tinsert(self.saleBuffer, record)
	if self.saleTimer then
		return
	end
	local window = self.db.notifications.combineWindow or 3
	window = max(2, min(5, window))
	self.saleTimer = C_Timer.NewTimer(window, function()
		self:FlushSaleBuffer()
	end)
end

function module:SendSaleChat(record)
	if not record or not self.db.notifications or not self.db.notifications.enable or not self.db.notifications.chat then
		return
	end
	local qty = record.qty or 1
	local gross = record.gross or 0
	local perItem = qty > 0 and floor(gross / qty) or gross
	local grossText = self:FormatMoney(gross)
	local perItemText = self:FormatMoney(perItem)
	local netText = self:FormatMoney(record.net or record.delta or 0)
	local itemText = record.itemLink or L["Item"]
	local msg = format(L["Auction Sold: %s x%d for %s (%s each), net %s"], itemText, qty, grossText, perItemText, netText)
	if record.buyer and record.buyer ~= "" then
		msg = msg .. format(" - %s: %s", L["Buyer"], record.buyer)
	end
	E:Print(msg)
end

MER:RegisterModule(module:GetName())
