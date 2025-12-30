local MER, F, E, L, V, P, G = unpack(ElvUI_AzUI)

MER.Utilities.Async = {}
local U = MER.Utilities.Async

local ipairs = ipairs
local pairs = pairs
local select = select
local tostring = tostring
local type = type

local Item = Item
local Spell = Spell

local cache = {
	item = {},
	spell = {}
}

function U.WithItemID(itemID, callback)
	if type(itemID) ~= "number" then
		return
	end

	if not callback then
		callback = function()
		end
	end

	if type(callback) ~= "function" then
		return
	end

	if cache.item[itemID] then
		callback(cache.item[itemID])
		return cache.item[itemID]
	end

	local success, itemInstance = pcall(Item.CreateFromItemID, Item, itemID)
	if not success or not itemInstance then
		if F.Developer and F.Developer.LogDebug then
			local errorMessage = success and "Unknown error" or itemInstance
			F.Developer.LogDebug(("Failed to create item instance for itemID: %s. Error: %s"):format(itemID, errorMessage))
		end
		return
	end

	if itemInstance:IsItemEmpty() then
		if F.Developer and F.Developer.LogDebug then
			F.Developer.LogDebug("Failed to create item instance for itemID: " .. itemID)
		end
		return
	end

	local resolvedItemID = itemInstance:GetItemID()
	if type(resolvedItemID) ~= "number" then
		if F.Developer and F.Developer.LogDebug then
			F.Developer.LogDebug(("Aborting ContinueOnItemLoad for invalid itemID: %s"):format(tostring(itemID)))
		end
		return
	end

	local ok, err = pcall(
		itemInstance.ContinueOnItemLoad,
		itemInstance,
		function()
			callback(itemInstance)
		end
	)
	if not ok and F.Developer and F.Developer.LogDebug then
		F.Developer.LogDebug(("ContinueOnItemLoad failed for itemID %s. Error: %s"):format(itemID, err or "Unknown"))
		return
	end

	cache.item[itemID] = itemInstance

	return itemInstance
end

function U.WithSpellID(spellID, callback)
	if type(spellID) ~= "number" then
		return
	end

	if not callback then
		callback = function()
		end
	end

	if type(callback) ~= "function" then
		return
	end

	if cache.spell[spellID] then
		callback(cache.spell[spellID])
		return cache.spell[spellID]
	end

	local spellInstance = Spell:CreateFromSpellID(spellID)

	if spellInstance:IsSpellEmpty() then
		F.Developer.LogDebug("Failed to create spell instance for spellID: " .. spellID)
		return
	end

	spellInstance:ContinueOnSpellLoad(
		function()
			callback(spellInstance)
		end
	)

	cache.spell[spellID] = spellInstance

	return spellInstance
end

function U.WithItemIDTable(itemIDTable, tType, callback)
	if type(itemIDTable) ~= "table" then
		return
	end

	if not callback then
		callback = function()
		end
	end

	if type(callback) ~= "function" then
		return
	end

	if type(tType) ~= "string" then
		tType = "value"
	end

	if tType == "list" then
		for _, itemID in ipairs(itemIDTable) do
			U.WithItemID(itemID, callback)
		end
	end

	if tType == "value" then
		for _, itemID in pairs(itemIDTable) do
			U.WithItemID(itemID, callback)
		end
	end

	if tType == "key" then
		for itemID, _ in pairs(itemIDTable) do
			U.WithItemID(itemID, callback)
		end
	end
end

function U.WithSpellIDTable(spellIDTable, tType, callback)
	if type(spellIDTable) ~= "table" then
		return
	end

	if not callback then
		callback = function()
		end
	end

	if type(callback) ~= "function" then
		return
	end

	if type(tType) ~= "string" then
		tType = "value"
	end

	if tType == "list" then
		for _, spellID in ipairs(spellIDTable) do
			U.WithSpellID(spellID, callback)
		end
	end

	if tType == "value" then
		for _, spellID in pairs(spellIDTable) do
			U.WithSpellID(spellID, callback)
		end
	end

	if tType == "key" then
		for spellID, _ in pairs(spellIDTable) do
			U.WithSpellID(spellID, callback)
		end
	end
end

function U.WithItemSlotID(itemSlotID, callback)
	if type(itemSlotID) ~= "number" then
		return
	end

	if not callback then
		callback = function()
		end
	end

	if type(callback) ~= "function" then
		return
	end

	local itemInstance = Item:CreateFromEquipmentSlot(itemSlotID)
	if itemInstance:IsItemEmpty() then
		F.Developer.LogDebug("Failed to create item instance for itemSlotID: " .. itemSlotID)
		return
	end

	local resolvedItemID = itemInstance:GetItemID()
	if type(resolvedItemID) ~= "number" then
		if F.Developer and F.Developer.LogDebug then
			F.Developer.LogDebug(("Aborting ContinueOnItemLoad for equipment slot %s: invalid item reference"):format(itemSlotID))
		end
		return
	end

	local ok, err = pcall(
		itemInstance.ContinueOnItemLoad,
		itemInstance,
		function()
			callback(itemInstance)
		end
	)
	if not ok and F.Developer and F.Developer.LogDebug then
		F.Developer.LogDebug(("ContinueOnItemLoad failed for equipment slot %s. Error: %s"):format(itemSlotID, err or "Unknown"))
		return
	end

	return itemInstance
end
