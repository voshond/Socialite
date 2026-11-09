local Helpers = require("helpers")
local Mock = Helpers.Mock

describe("Socialite.toc #smoke", function()
	it("lists the vendored libs, i18n and addon files in load order", function()
		local files = Helpers.TocFiles("./Socialite.toc")
		local wanted = {
			"vendor/LibStub/LibStub.lua",
			"vendor/CallbackHandler-1.0/CallbackHandler-1.0.lua",
			"AceGUI-3.0.lua",
			"AceConfigDialog-3.0.lua",
			"AceConsole-3.0.lua",
			"vendor/LibDataBroker-1.1/LibDataBroker-1.1.lua",
			"vendor/LibDBIcon-1.0/LibDBIcon-1.0.lua",
			"./i18n/enUS.lua",
			"./tooltip.lua",
			"./functions.lua",
			"./Socialite.lua",
			"./config.lua",
		}
		local position = 0
		for _, suffix in ipairs(wanted) do
			local found
			for index = position + 1, #files do
				if files[index]:sub(-#suffix) == suffix then
					found = index
					break
				end
			end
			assert.is_not_nil(found, suffix .. " loaded after the previous file")
			position = found
		end
	end)

	it("loads without errors and registers ADDON_LOADED", function()
		local ns
		assert.has_no_error(function() ns = Helpers.LoadAddon({ loaded = false }) end)
		assert.is_not_nil(ns.L)
		assert.is_not_nil(ns.tooltip)
		assert.is_not_nil(ns.dataobj)
		assert.is_not_nil(ns.optionsFrame)
		assert.is_true(ns.frame:IsEventRegistered("ADDON_LOADED"))
		assert.is_nil(ns.db)
	end)

	it("ignores ADDON_LOADED for other addons", function()
		local ns = Helpers.LoadAddon({ loaded = false })
		Mock.FireEvent("ADDON_LOADED", "SomethingElse")
		assert.is_nil(ns.db)
	end)

	it("populates addon.db defaults on ADDON_LOADED", function()
		local ns = Helpers.LoadAddon()
		assert.equals(_G.SocialiteSettings, ns.db)
		assert.same({ hide = true }, ns.db.minimap)
		assert.is_true(ns.db.ShowRealID)
		assert.is_true(ns.db.ShowFriends)
		assert.is_true(ns.db.ShowGuild)
		assert.is_false(ns.db.ShowRealIDApp)
		assert.equals("rank", ns.db.GuildSortKey)
		assert.equals("icon", ns.db.ShowStatus)
		assert.equals("always", ns.db.TooltipInteraction)
		assert.equals(0, ns.db.TooltipWidth)
		assert.is_false(ns.frame:IsEventRegistered("ADDON_LOADED"))
	end)

	it("keeps saved settings and fills in missing ones", function()
		local ns = Helpers.LoadAddon({ saved = { ShowGuild = false, minimap = { hide = false } } })
		assert.is_false(ns.db.ShowGuild)
		assert.is_false(ns.db.minimap.hide)
		assert.is_true(ns.db.ShowFriends)
	end)

	it("renders an empty tooltip without errors", function()
		local ns = Helpers.LoadAddon()
		assert.has_no_error(function() ns.dataobj.OnEnter(UIParent) end)
		assert.same({}, Mock.messages)
	end)

	it("registers the /socialite command", function()
		Helpers.LoadAddon()
		assert.equals("/socialite", _G.SLASH_ACECONSOLE_SOCIALITE1)
	end)
end)
