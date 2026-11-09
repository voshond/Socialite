local Helpers = require("helpers")
local Mock = Helpers.Mock

local GUILD = {
	{ name = "Guildie-TestRealm", class = "Warrior", zone = "Dornogal" },
	{ name = "Faraway-OtherRealm", class = "Mage" },
}

local FRIENDS = {
	{ name = "Buddy", className = "Mage", level = 80, connected = true, area = "Stormwind", notes = "" },
}

local function RosterArrives()
	Mock.SetGuild(GUILD)
	Mock.SetFriends(FRIENDS)
	Mock.FireEvent("GUILD_ROSTER_UPDATE")
end

describe("Titan Panel #titan", function()
	it("loads Titan Panel and Socialite without errors", function()
		Helpers.LoadWithTitan()
		assert.is_true(Titan_G.InitializedPEW)
		assert.same({}, Mock.messages)
	end)

	it("makes a Titan button for Socialite on the top bar", function()
		local _, button = Helpers.LoadWithTitan()
		assert.is_not_nil(button)
		assert.equals("Socialite", button.TitanName)
		assert.equals("LDB", button.TitanCreatedBy)
		assert.is_true(button:IsVisible())
		assert.is_true(button:GetTop() > UIParent:GetHeight() - 30, "button sits on the top bar")
	end)

	it("shows the data object's text and follows its changes", function()
		local ns, button = Helpers.LoadWithTitan()
		RosterArrives()
		assert.is_not_nil(ns.dataobj.text:find("|cff00FF002|r", 1, true), "data object counts the guild")
		assert.is_not_nil(Helpers.TitanText(button):find(ns.dataobj.text, 1, true))
		ns.dataobj.text = "Socialite: 7"
		assert.is_not_nil(Helpers.TitanText(button):find("Socialite: 7", 1, true))
	end)

	it("opens Socialite's tooltip at the button on hover", function()
		local ns, button = Helpers.LoadWithTitan()
		RosterArrives()
		assert.is_false(ns.tooltip:IsShown())
		button:RunScript("OnEnter")
		assert.is_true(ns.tooltip:IsShown())
		assert.is_not_nil(Helpers.TooltipAnchoredTo(button), "tooltip anchored to the Titan button")
		assert.is_not_nil(Helpers.TooltipLine("Guildie"))
		assert.is_not_nil(Helpers.TooltipLine("Buddy"))
		assert.same({}, Mock.messages)
	end)
end)
