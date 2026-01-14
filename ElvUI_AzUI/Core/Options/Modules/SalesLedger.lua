local MER, F, E, L, V, P, G = unpack(ElvUI_AzUI)
local module = MER:GetModule('MER_SalesLedger')
local options = MER.options.modules.args

local scopeValues = {
	CHAR = L["Character"],
	REALM = L["Realm"],
	ACCOUNT = L["Account"],
}

local timeframeValues = {
	SESSION = L["Session"],
	TODAY = L["Today"],
	WEEK = L["This Week"],
	ROLLING = L["Rolling"],
	LIFETIME = L["Lifetime"],
}

local purgeModeValues = {
	RAW_ONLY = L["Raw Only"],
	RAW_AND_SUMMARY = L["Raw + Summary"],
}

options.salesLedger = {
	type = "group",
	name = L["Sales Ledger"],
	get = function(info) return E.db.mui.salesLedger[info[#info]] end,
	set = function(info, value) E.db.mui.salesLedger[info[#info]] = value; E:StaticPopup_Show("PRIVATE_RL"); end,
	disabled = function() return module and module.StopRunning end,
	args = {
		header = {
			order = 1,
			type = "header",
			name = F.cOption(L["Sales Ledger"], 'orange'),
		},
		enable = {
			order = 2,
			type = "toggle",
			name = L["Enable"],
			width = "full",
		},
		general = {
			order = 3,
			type = "group",
			name = F.cOption(L["General"], 'orange'),
			guiInline = true,
			get = function(info) return E.db.mui.salesLedger[info[#info]] end,
			set = function(info, value)
				E.db.mui.salesLedger[info[#info]] = value
				if module and module.NotifyUpdate then
					module:NotifyUpdate()
				end
			end,
			args = {
				scopeDefault = {
					order = 1,
					type = "select",
					name = L["Default Scope"],
					values = scopeValues,
				},
				rollingDays = {
					order = 2,
					type = "range",
					name = L["Rolling Days"],
					min = 1, max = 90, step = 1,
				},
				trackUnclassified = {
					order = 3,
					type = "toggle",
					name = L["Track Unclassified"],
				},
			},
		},
		datatext = {
			order = 4,
			type = "group",
			name = F.cOption(L["DataText"], 'orange'),
			guiInline = true,
			get = function(info) return E.db.mui.salesLedger.datatext[info[#info]] end,
			set = function(info, value)
				E.db.mui.salesLedger.datatext[info[#info]] = value
				E:StaticPopup_Show("PRIVATE_RL")
			end,
			args = {
				enable = {
					order = 1,
					type = "toggle",
					name = L["Enable"],
				},
				defaultView = {
					order = 2,
					type = "select",
					name = L["Default View"],
					values = timeframeValues,
				},
			},
		},
		notifications = {
			order = 5,
			type = "group",
			name = F.cOption(L["Notifications"], 'orange'),
			guiInline = true,
			get = function(info) return E.db.mui.salesLedger.notifications[info[#info]] end,
			set = function(info, value)
				E.db.mui.salesLedger.notifications[info[#info]] = value
				if module and module.RefreshAlert then
					module:RefreshAlert()
				end
			end,
			args = {
				enable = {
					order = 1,
					type = "toggle",
					name = L["Enable"],
				},
				chat = {
					order = 2,
					type = "toggle",
					name = L["Chat Message"],
				},
				fade = {
					order = 3,
					type = "toggle",
					name = L["Fade Alert"],
				},
				combineWindow = {
					order = 4,
					type = "range",
					name = L["Combine Window"],
					min = 2, max = 5, step = 0.1,
				},
				font = {
					order = 5,
					type = "group",
					name = L["Font"],
					guiInline = true,
					get = function(info) return E.db.mui.salesLedger.notifications.font[info[#info]] end,
					set = function(info, value)
						E.db.mui.salesLedger.notifications.font[info[#info]] = value
						if module and module.RefreshAlert then
							module:RefreshAlert()
						end
					end,
					args = {
						name = {
							order = 1,
							type = "select",
							dialogControl = "LSM30_Font",
							name = L["Font"],
							values = E.LSM:HashTable("font"),
						},
						size = {
							order = 2,
							type = "range",
							name = L["Size"],
							min = 8, max = 48, step = 1,
						},
						style = {
							order = 3,
							type = "select",
							name = L["Font Outline"],
							values = {
								['NONE'] = L["None"],
								['OUTLINE'] = L["OUTLINE"],
								['MONOCHROME'] = L["MONOCHROME"],
								['MONOCHROMEOUTLINE'] = L["MONOCROMEOUTLINE"],
								['THICKOUTLINE'] = L["THICKOUTLINE"],
							},
						},
					},
				},
			},
		},
		purge = {
			order = 6,
			type = "group",
			name = F.cOption(L["Purge"], 'orange'),
			guiInline = true,
			get = function(info) return E.db.mui.salesLedger.purge[info[#info]] end,
			set = function(info, value) E.db.mui.salesLedger.purge[info[#info]] = value end,
			args = {
				enabled = {
					order = 1,
					type = "toggle",
					name = L["Enable"],
				},
				days = {
					order = 2,
					type = "range",
					name = L["Keep Days"],
					min = 0, max = 365, step = 1,
				},
				mode = {
					order = 3,
					type = "select",
					name = L["Purge Mode"],
					values = purgeModeValues,
				},
				runOnLogin = {
					order = 4,
					type = "toggle",
					name = L["Run on Login"],
				},
				purgeNow = {
					order = 5,
					type = "execute",
					name = L["Purge Now"],
					func = function()
						if module and module.RunPurge then
							module:RunPurge()
							module:NotifyUpdate()
						end
					end,
				},
			},
		},
		categories = {
			order = 7,
			type = "group",
			name = F.cOption(L["Categories"], 'orange'),
			guiInline = true,
			get = function(info) return E.db.mui.salesLedger.filters.categories[info[#info]] end,
			set = function(info, value)
				E.db.mui.salesLedger.filters.categories[info[#info]] = value
				if module and module.NotifyUpdate then
					module:NotifyUpdate()
				end
			end,
			args = {
				quest = { order = 1, type = "toggle", name = L["Quest"] },
				loot = { order = 2, type = "toggle", name = L["Loot"] },
				vendorSale = { order = 3, type = "toggle", name = L["Vendor Sale"] },
				vendorPurchase = { order = 4, type = "toggle", name = L["Vendor Purchase"] },
				auctionSale = { order = 5, type = "toggle", name = L["Auction Sale"] },
				auctionPurchase = { order = 6, type = "toggle", name = L["Auction Purchase"] },
				auctionExpired = { order = 7, type = "toggle", name = L["Auction Expired"] },
				auctionCanceled = { order = 8, type = "toggle", name = L["Auction Canceled"] },
				mail = { order = 9, type = "toggle", name = L["Mail"] },
				trade = { order = 10, type = "toggle", name = L["Trade"] },
				cod = { order = 11, type = "toggle", name = L["COD"] },
				repair = { order = 12, type = "toggle", name = L["Repair"] },
				taxi = { order = 13, type = "toggle", name = L["Taxi"] },
				training = { order = 14, type = "toggle", name = L["Training"] },
				respec = { order = 15, type = "toggle", name = L["Respec"] },
				guildRepair = { order = 16, type = "toggle", name = L["Guild Repair"] },
				guildBank = { order = 17, type = "toggle", name = L["Guild Bank"] },
				other = { order = 18, type = "toggle", name = L["Other"] },
			},
		},
	},
}
