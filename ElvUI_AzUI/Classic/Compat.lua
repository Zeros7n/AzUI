local specAPI = C_SpecializationInfo
local type = type
local pairs = pairs
local GetNumTalents = GetNumTalents

local function copyShallow(tbl)
	if not tbl then
		return
	end

	local copy = {}
	for key, value in pairs(tbl) do
		copy[key] = value
	end

	return copy
end

local function resolveSpecIndex(query)
	if not specAPI or not specAPI.GetSpecialization then
		return
	end

	local specializationIndex = query.specializationIndex
	if specializationIndex and specializationIndex > 0 then
		return specializationIndex
	end

	local spec = specAPI.GetSpecialization(query.isInspect, query.isPet, query.target, query.groupIndex)
	if spec and spec > 0 then
		return spec
	end

	spec = specAPI.GetSpecialization()
	if spec and spec > 0 then
		return spec
	end
end

local function resolveTalentIndex(query, getTalentInfo)
	if query.talentIndex and query.talentIndex > 0 then
		return query.talentIndex
	end

	local tier = query.tier
	local column = query.column
	if type(tier) ~= "number" or type(column) ~= "number" then
		return
	end

	local specIndex = query.specializationIndex or resolveSpecIndex(query) or 1
	if GetNumTalents and getTalentInfo then
		local numTalents = GetNumTalents(specIndex)
		if type(numTalents) == "number" and numTalents > 0 then
			local searchQuery = copyShallow(query)
			if searchQuery then
				searchQuery.specializationIndex = specIndex
				for talentIndex = 1, numTalents do
					searchQuery.talentIndex = talentIndex
					searchQuery.tier = nil
					searchQuery.column = nil
					local info = getTalentInfo(searchQuery)
					if info then
						local infoTier = info.tier or info.tierIndex or info.row
						local infoColumn = info.column or info.columnIndex or info.columnID
						if infoTier == tier and infoColumn == column then
							return talentIndex
						end
					end
				end
			end
		end
	end

	local numColumns = _G.NUM_TALENT_COLUMNS or 4
	return (tier - 1) * numColumns + column
end

if specAPI and specAPI.GetTalentInfo and specAPI.GetSpecialization then
	local originalGetTalentInfo = specAPI.GetTalentInfo

	specAPI.GetTalentInfo = function(query, ...)
		if type(query) == "table" then
			local newQuery = copyShallow(query)
			if newQuery then
				if not newQuery.specializationIndex then
					newQuery.specializationIndex = resolveSpecIndex(newQuery) or 1
				end

				if not newQuery.talentIndex and (newQuery.tier or newQuery.column) then
					newQuery.talentIndex = resolveTalentIndex(newQuery, originalGetTalentInfo)
				end

				query = newQuery
			end
		end

		return originalGetTalentInfo(query, ...)
	end
end
