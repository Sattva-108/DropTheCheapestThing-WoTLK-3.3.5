local core = LibStub("AceAddon-3.0"):GetAddon("DropTheCheapestThing")
local module = core:NewModule("Config")
-- Import AceTimer
local AceTimer = LibStub("AceTimer-3.0")
local db

function module:removable_item(itemID, list_name)
local list_setting = list_name == "Never Consider" and "never" or "always"
	local item_name, _, _, _, _, _, _, _, _, item_icon = GetItemInfo(itemID)

	--print("Function called with list_name: " .. list_name)  -- New debug statement
	--print("List setting: " .. list_setting)
	--print("ItemID: " .. itemID)


	return {
		type = "execute",
		name = item_name or 'itemid:' .. tostring(itemID),
		desc = not item_name and "Item isn't cached" or "Click to remove from the " .. list_setting .. " consider list",
		image = item_icon,
		width = "30%",
		arg = itemID,
		func = function()
			core.db.profile[list_setting .. "_consider"][itemID] = nil
			core:BAG_UPDATE()

			local args = module.options.args[list_setting].args.remove.args
			args[tostring(itemID)] = nil

			LibStub("AceConfigRegistry-3.0"):NotifyChange("DropTheCheapestThing")

			-- Refresh the GUI
			module:Refresh()

		end,
	}
end

local categoryOrder = {
	["Trade Goods"] = 100,
	["Consumable"] = 200,
	["Miscellaneous"] = 300,
	["Armor"] = 400,
	["Weapon"] = 500,
	["Container"] = 600,
	["Gem"] = 700,
	["Key"] = 800,
	["Money"] = 900,
	["Reagent"] = 1000,
	["Recipe"] = 1100,
	["Projectile"] = 1200,
	["Quest"] = 1300,
	["Quiver"] = 1400,
	["Junk"] = 1400,
}

function module:CreateCategory(name, group)
	if not group.args[name] then
		local order = categoryOrder[name] or 50  -- Fallback to higher order if unknown category
		group.args[name] = {
			type = "group",
			name = name,
			inline = true,
			order = order,
			args = {}
		}
	end
	return group.args[name]
end



local function item_list_group(name, order, description, db_table)
	local group = {
		type = "group",
		name = name,
		order = order,
		args = {},
	}
	group.args.about = {
		type = "description",
		name = description,
		order = 0,
	}
	group.args.add = {
		type = "input",
		name = "Add",
		desc = "Add an item, either by pasting the item link, dragging the item into the field, or entering the itemid.",
		get = function(info) return '' end,
		set = function(info, v)
			local itemid = core.link_to_id(v) or tonumber(v)
			db_table[itemid] = true

			-- Get and create a proper category for a new item, then add it
			local itemName, _, _, _, _, itemType = GetItemInfo(itemid)
			if itemName and itemType then
				local category = module:CreateCategory(itemType, group.args.remove)
				category.args[tostring(itemid)] = module:removable_item(itemid, name)
			end

			core:BAG_UPDATE()
			-- Schedule a timer to call ClearFocus() after a delay
			AceTimer:ScheduleTimer(function() _G["AceGUI-3.0EditBox1"]:ClearFocus() end, 0.01)
		end,
		validate = function(info, v)
			if v:match("^%d+$") or v:match("item:%d+") then
				return true
			end
		end,
		order = 10,
	}
	group.args.remove = {
		type = "group",
		inline = true,
		name = "Remove",
		order = 20,
		func = function(info)
			db_table[info.arg] = nil
			group.args.remove.args[info[#info]] = nil
			core:BAG_UPDATE()
		end,
		args = {
			about = {
				type = "description",
				name = "Remove an item.",
				order = 0,
			},
		},
	}
	for itemID in pairs(db_table) do
		--print("ItemID:", itemID)
		local itemName, _, _, _, _, itemType = GetItemInfo(itemID)
		if itemName and itemType then
			--print("ItemName:", itemName, "ItemType:", itemType)
			local category = module:CreateCategory(itemType, group.args.remove)
			category.args[tostring(itemID)] = module:removable_item(itemID, name)
		else
			--print("Item info missing for:", itemID)
		end
	end
	return group
end

function module:OnInitialize()
	db = core.db

	local options = {
		type = "group",
		name = "DropTheCheapestThing",
		get = function(info) return db.profile[info[#info]] end,
		set = function(info, v) db.profile[info[#info]] = v; core:BAG_UPDATE() end,
		args = {
			general = {
				type = "group",
				name = "General",
				order = 10,
				args = {
					threshold = {
						type = "range",
						name = "Quality Threshold (Drop)",
						desc = "Choose the maximum quality of item that will be considered for dropping. 0 is grey, 1 is white, 2 is green, etc.",
						min = 0, max = 7, step = 1,
						order = 10,
					},
					sell_threshold = {
						type = "range",
						name = "Quality Threshold (Sell)",
						desc = "Choose the maximum quality of item that will be considered for selling. 0 is grey, 1 is white, 2 is green, etc.",
						min = 0, max = 7, step = 1,
						order = 15,
					},
					auction = {
						type = "group",
						name = "Auction values",
						inline = true,
						order = 20,
						args = {
							auction = {
								type = "toggle",
								name = "Auction values",
								desc = "If a supported auction addon is installed, use the higher of the vendor and buyout prices as the item's value.",
								order = 10,
							},
							auction_threshold = {
								type = "range",
								name = "Auction threshold",
								desc = "Only consider auction values for items of at least this quality.",
								min = 0, max = 7, step = 1,
								order = 20,
							},
						},
					},
					full_stacks = {
						type = "toggle",
						name = "Use full stack value",
						order = 30,
					},
				},
				plugins = {},
			},
			always = item_list_group("Always Consider", 20, "Items listed here will *always* be considered junk and sold/dropped, regardless of the quality threshold that has been chosen. Be careful with this -- you'll never be prompted about it, and it will have no qualms about dropping things that could be auctioned for 5000g.", db.profile.always_consider),
			never = item_list_group("Never Consider", 30, "Items listed here will *never* be considered junk and sold/dropped, regardless of the quality threshold that has been chosen.", db.profile.never_consider),
		},
		plugins = {
			--profiles = { profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(db), },
		},
	}
	self.options = options

	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("DropTheCheapestThing", options)
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions("DropTheCheapestThing", "DropTheCheapestThing")
end

local AceConfigDialog = LibStub("AceConfigDialog-3.0")

local function SetDialogPosition(dialog)
	local frame = dialog.frame
	frame:ClearAllPoints()

	local adiBagsContainer = _G["AdiBagsContainer1"]
	if IsAddOnLoaded("AdiBags") and adiBagsContainer and adiBagsContainer:IsShown() then
		frame:SetPoint("TOP", adiBagsContainer, "BOTTOM", 0, -10) -- Attach the top of our frame to the bottom of AdiBagsContainer1
	else
		frame:SetPoint("CENTER", 0, -200) -- Set the position of the frame 200 px below the center
	end
end

function module:ShowConfig()
	--AceConfigDialog:SetDefaultSize("DropTheCheapestThing", 800, 200) -- Specify custom width and height of GUI here
	AceConfigDialog:SelectGroup("DropTheCheapestThing", "always") -- Open Always Consider tab
	AceConfigDialog:Open("DropTheCheapestThing")

	local adiBagsContainer = _G["AdiBagsContainer1"]
	if IsAddOnLoaded("AdiBags") and adiBagsContainer and not adiBagsContainer:IsShown() then
		adiBagsContainer:Show() -- show AdiBags bag
	end

	local dialog = AceConfigDialog.OpenFrames["DropTheCheapestThing"]

	if dialog then
		-- Apply the custom position only once, after opening the frame
		hooksecurefunc(dialog.frame, "Show", function()
			-- Only apply SetDialogPosition to frames belonging to your addon
			if dialog == AceConfigDialog.OpenFrames["DropTheCheapestThing"] then
				if not module:IsConfigShown() then
					--SetDialogPosition(dialog)

				end
			end
		end)
	end
end

function module:HideConfig()
	local dialog = AceConfigDialog.OpenFrames["DropTheCheapestThing"]
	if dialog then
		dialog:Hide()
	end
end

function module:IsConfigShown()
	local dialog = AceConfigDialog.OpenFrames["DropTheCheapestThing"]
	if dialog then
		return dialog:IsShown()
	else
		return false
	end
end

function module:ToggleConfig()
	local adiBagsContainer = _G["AdiBagsContainer1"]

	if self:IsConfigShown() then
		self:HideConfig()

		-- If AdiBags is loaded and the bag is shown, hide it when closing the config
		if IsAddOnLoaded("AdiBags") and adiBagsContainer and adiBagsContainer:IsShown() then
			adiBagsContainer:Hide()
		end
	else
		self:ShowConfig()

		-- If AdiBags is loaded and the bag is not shown, show it when opening the config
		if IsAddOnLoaded("AdiBags") and adiBagsContainer and not adiBagsContainer:IsShown() then
			adiBagsContainer:Show()
		end
	end
end

function module:AddItemToAlwaysConsider(itemID)
	if not itemID then
		return
	end

	-- Add the new item to the 'always consider' list in the GUI
	local always_consider = self.options.args.always.args.remove
	local itemName, _, _, _, _, itemType = GetItemInfo(itemID)
	if itemName and itemType then
		local category = module:CreateCategory(itemType, always_consider)
		category.args[tostring(itemID)] = module:removable_item(itemID, "Always Consider")
	end

	core.db.profile.always_consider[itemID] = true
	core:BAG_UPDATE()

	LibStub("AceConfigRegistry-3.0"):NotifyChange("DropTheCheapestThing")
end

function module:AddItemToNeverConsider(itemID)
	if not itemID then
		return
	end

	-- Add the new item to the 'never consider' list in the GUI
	local never_consider = self.options.args.never.args.remove
	local itemName, _, _, _, _, itemType = GetItemInfo(itemID)
	if itemName and itemType then
		local category = module:CreateCategory(itemType, never_consider)
		category.args[tostring(itemID)] = module:removable_item(itemID, "Never Consider")
	end

	core.db.profile.never_consider[itemID] = true
	core:BAG_UPDATE()

	LibStub("AceConfigRegistry-3.0"):NotifyChange("DropTheCheapestThing")
end


function module:Refresh()
	-- Rebuild Always Consider group
	local always_group = item_list_group("Always Consider", 20, "Items listed here will *always* be considered junk and sold/dropped, regardless of the quality threshold that has been chosen. Be careful with this -- you'll never be prompted about it, and it will have no qualms about dropping things that could be auctioned for 5000g.", db.profile.always_consider)
	module.options.args.always = always_group

	-- Rebuild Never Consider group
	local never_group = item_list_group("Never Consider", 30, "Items listed here will *never* be considered junk and sold/dropped, regardless of the quality threshold that has been chosen.", db.profile.never_consider)
	module.options.args.never = never_group
end



SLASH_DROPTHECHEAPESTTHING1 = "/dropcheap"
SLASH_DROPTHECHEAPESTTHING2 = "/dtct"
function SlashCmdList.DROPTHECHEAPESTTHING()
	module:ShowConfig()
end
