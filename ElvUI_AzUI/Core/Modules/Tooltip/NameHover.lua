local MER, F, E, L, V, P, G = unpack(ElvUI_AzUI)
local MI = MER:GetModule('MER_Misc')

local CreateFrame = CreateFrame
local GetCursorPosition = GetCursorPosition
local GetMouseFocus = GetMouseFocus
local IsAddOnLoaded = IsAddOnLoaded
local UnitCanAttack = UnitCanAttack
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitReaction = UnitReaction
local UnitIsAFK = UnitIsAFK
local UnitIsDND = UnitIsDND
local UnitIsDead = UnitIsDead
local UnitIsPlayer = UnitIsPlayer
local UnitName = UnitName
local UIParent = UIParent
local UNKNOWN = UNKNOWN

local function Getcolor()
	local reaction = UnitReaction("mouseover", "player") or 5

	if UnitIsPlayer("mouseover") then
		local _, class = UnitClass("mouseover")
		local color = E:ClassColor(class)
		return color.r, color.g, color.b
	elseif UnitCanAttack("player", "mouseover") then
		if UnitIsDead("mouseover") then
			return 136/255, 136/255, 136/255
		else
			if reaction < 4 then
				return 1, 68/255, 68/255
			elseif reaction == 4 then
				return 1, 1, 68/255
			end
		end
	else
		if reaction < 4 then
			return 48/255, 113/255, 191/255
		else
			return 1, 1, 1
		end
	end
end

local function AddTargetInfos(self, unit)
	local unitTarget = unit..'target'
	if unit ~= 'player' and UnitExists(unitTarget) then
		local targetColor
		if UnitIsPlayer(unitTarget) and (not E.Retail or not UnitHasVehicleUI(unitTarget)) then
			local _, class = UnitClass(unitTarget)
			targetColor = E:ClassColor(class) or _G.PRIEST_COLOR
		else
			local reaction = UnitReaction(unitTarget, 'player')
			targetColor = _G.FACTION_BAR_COLORS[reaction] or _G.PRIEST_COLOR
		end

		self.target:SetText(' |cffffffff>|r '..' '..UnitName(unitTarget))
		self.target:SetTextColor(targetColor.r, targetColor.g, targetColor.b)
	else
		self.target:SetText('')
	end
end

function MI:LoadnameHover()
	if not E.db.mui.nameHover.enable or IsAddOnLoaded("bdNameHover") then return end

	local db = E.db.mui.nameHover
	local tooltip = CreateFrame("frame", nil)
	tooltip:SetFrameStrata("TOOLTIP")
	tooltip.text = tooltip:CreateFontString(nil, "OVERLAY")
	tooltip.text:FontTemplate(nil, db.fontSize or 7, db.fontOutline or "OUTLINE")

	tooltip.target = tooltip:CreateFontString(nil, "OVERLAY")
	tooltip.target:FontTemplate(nil, db.fontSize or 7, db.fontOutline or "OUTLINE")

	-- Show unit name at mouse
-- Show unit name at mouse
tooltip:SetScript("OnUpdate", function(tt)
    -- Explicitly get GetMouseFocus from the global environment
    local GetMouseFocus_Global = _G.GetMouseFocus

    -- *** Crucial Check for the "upvalue nil" error ***
    -- If GetMouseFocus_Global is still nil here, there's a very serious environmental problem.
    if not GetMouseFocus_Global then
        tt:Hide()
        return
    end

    local focusedFrame = GetMouseFocus_Global() -- Use the globally referenced function

    -- Condition 1: If there's no frame focused OR the focused frame is forbidden
    if not focusedFrame or focusedFrame:IsForbidden() then
        tt:Hide()
        return
    end

    -- Condition 2: If the focused frame is not the WorldFrame (meaning it's a UI element)
    if focusedFrame:GetName() ~= "WorldFrame" then
        tt:Hide()
        return
    end

    -- Condition 3: If no unit exists under the mouseover cursor
    -- UnitExists should also be a global, but unlikely to be nil if GetMouseFocus is fixed.
    if not UnitExists("mouseover") then
        tt:Hide()
        return
    end

    -- If all hide conditions are false, then we should show and position the tooltip
    local x, y = GetCursorPosition()
    tt.text:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y + 15)

    if db and db.targettarget then
        tt.target:SetPoint("LEFT", tt.text, "RIGHT", 0, 0)
    end

    tt:Show() -- Explicitly show the tooltip if it passed all checks
end)

	tooltip:SetScript("OnEvent", function(tt)
tooltip:SetScript("OnUpdate", function(tt)
    local GetMouseFocus_Global = _G.GetMouseFocus

    -- *** NEW CRITICAL CHECK ***
    -- If GetMouseFocus_Global is nil, we cannot proceed with mouse focus logic.
    -- Print a message (which you're already getting) and return immediately.
    if not GetMouseFocus_Global then
        -- This print statement is what you're seeing, indicating the problem.
        -- We'll keep it for debugging confirmation, but the 'return' is key.
        -- You might want to hide the tooltip too, if it was visible.
        if tt and tt.Hide then tt:Hide() end -- Safely hide if tt exists
        return
    end

    -- If we reach here, GetMouseFocus_Global is not nil, and we can use it.
    local focusedFrame = GetMouseFocus_Global()

    -- Your existing logic from the previous fix starts here:
    if not focusedFrame or focusedFrame:IsForbidden() then
        tt:Hide()
        return
    end

    if focusedFrame:GetName() ~= "WorldFrame" then
        tt:Hide()
        return
    end

    if not UnitExists("mouseover") then
        tt:Hide()
        return
    end

    local x, y = GetCursorPosition()
    tt.text:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y + 15)

    -- Assuming 'db' is available in this scope for the module
    if db and db.targettarget then
        tt.target:SetPoint("LEFT", tt.text, "RIGHT", 0, 0)
    end

    tt:Show()
end)

		local name = UnitName("mouseover") or UNKNOWN
		local text = E:StripString(name)
		local AFK = UnitIsAFK("mouseover")
		local DND = UnitIsDND("mouseover")
		local _, UnitClass = UnitClass("mouseover")
		local reaction = UnitReaction("mouseover", "player")

		local colorDB = E.db.mui.gradient

		local prefix = ""

		if AFK then prefix = "|cffFF9900<AFK>|r " end
		if DND then prefix = "|cffFF3333<DND>|r " end

		if colorDB and colorDB.enable then
			if UnitIsPlayer("mouseover") and UnitClass then
				if colorDB.customColor.enable then
					tt.text:SetText(prefix .. F.GradientNameCustom(text, UnitClass))
				else
					tt.text:SetText(prefix .. F.GradientName(text, UnitClass))
				end
			else
				if reaction and reaction >= 5 then
					if colorDB.customColor.enable then
						tt.text:SetText(prefix .. F.GradientNameCustom(text, "NPCFRIENDLY"))
					else
						tt.text:SetText(prefix .. F.GradientName(text, "NPCFRIENDLY"))
					end
				elseif reaction and reaction == 4 then
					if colorDB.customColor.enable then
						tt.text:SetText(prefix .. F.GradientNameCustom(text, "NPCNEUTRAL"))
					else
						tt.text:SetText(prefix .. F.GradientName(text, "NPCNEUTRAL"))
					end
				elseif reaction and reaction == 3 then
					if colorDB.customColor.enable then
						tt.text:SetText(prefix .. F.GradientNameCustom(text, "NPCUNFRIENDLY"))
					else
						tt.text:SetText(prefix .. F.GradientName(text, "NPCUNFRIENDLY"))
					end
				elseif reaction and reaction == 2 or reaction == 1 then
					if colorDB.customColor.enable then
						tt.text:SetText(prefix .. F.GradientNameCustom(text, "NPCHOSTILE"))
					else
						tt.text:SetText(prefix .. F.GradientName(text, "NPCHOSTILE"))
					end
				end
			end
		else
			tt.text:SetText(prefix..text)
			tt.text:SetTextColor(Getcolor())
		end

		if db and db.targettarget then
			AddTargetInfos(tt, "mouseover")
		end

		tt:Show()
	end)

	tooltip:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
end
