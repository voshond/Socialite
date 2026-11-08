local Helpers = require("helpers")
local Mock = Helpers.Mock

local GUILD = {
	{ name = "Guildie-TestRealm", class = "Warrior", zone = "Dornogal" },
	{ name = "Faraway-OtherRealm", class = "Mage" },
	{ name = "Phoney-TestRealm", class = "Priest", isMobile = true },
}

local FRIENDS = {
	{ name = "Buddy", className = "Mage", level = 80, connected = true, area = "Stormwind", notes = "" },
}

local function Character(overrides)
	local info = {
		characterName = "Palchar", clientProgram = "WoW", realmName = "TestRealm", realmID = 1,
		factionName = "Alliance", raceName = "Human", className = "Priest", areaName = "Stormwind",
		characterLevel = 80, hasFocus = true, gameAccountID = 99,
	}
	for key, value in pairs(overrides or {}) do info[key] = value end
	return info
end

local function BattleNetFriend(overrides)
	local account = {
		bnetAccountID = 7, accountName = "Pal", battleTag = "Pal#1234", isBattleTagFriend = true,
		gameAccountInfo = { isAFK = false, isDND = false, clientProgram = "WoW" },
		canGroup = true, gameAccounts = { Character() },
	}
	for key, value in pairs(overrides or {}) do account[key] = value end
	return account
end

local function Open(bnet)
	local ns = Helpers.LoadAddon()
	Mock.SetGuild(GUILD)
	Mock.SetFriends(FRIENDS)
	Mock.SetBattleNet(bnet or { BattleNetFriend() })
	Helpers.OpenTooltip(ns)
	assert.same({}, Mock.printed, "tooltip rendered without errors")
	return ns
end

local function Args(name, index)
	local call = Mock.Calls(name)[index or 1]
	return call and { unpack(call, 1, call.n) }
end

describe("tooltip clicks", function()
	describe("guild line", function()
		it("Shift+Left invites the full Name-Realm #invite", function()
			Open()
			Helpers.ClickLine("Guildie", "LeftButton", { shift = true })
			assert.same({ "Guildie-TestRealm" }, Args("C_PartyInfo.InviteUnit"))
			assert.equals(0, #Mock.Calls("ChatFrame_SendTell"))
		end)

		it("Shift+Left invites a cross-realm member by Name-Realm #invite", function()
			Open()
			Helpers.ClickLine("Faraway-OtherRealm", "LeftButton", { shift = true })
			assert.same({ "Faraway-OtherRealm" }, Args("C_PartyInfo.InviteUnit"))
		end)

		it("Shift+Left on a mobile member does not invite or whisper #invite", function()
			Open()
			Helpers.ClickLine("Phoney", "LeftButton", { shift = true })
			assert.equals(0, #Mock.Calls("C_PartyInfo.InviteUnit"))
			assert.equals(0, #Mock.Calls("ChatFrame_SendTell"))
		end)

		it("plain Left whispers #whisper", function()
			Open()
			Helpers.ClickLine("Guildie", "LeftButton")
			assert.same({ "Guildie-TestRealm" }, Args("ChatFrame_SendTell"))
			assert.equals(0, #Mock.Calls("C_PartyInfo.InviteUnit"))
		end)

		it("Alt+Left whispers instead of inviting #whisper", function()
			Open()
			Helpers.ClickLine("Guildie", "LeftButton", { alt = true })
			assert.same({ "Guildie-TestRealm" }, Args("ChatFrame_SendTell"))
			assert.equals(0, #Mock.Calls("C_PartyInfo.InviteUnit"))
		end)

		it("Right opens the guild context menu", function()
			Open()
			Helpers.ClickLine("Guildie", "RightButton")
			assert.equals(1, #Mock.Calls("MenuUtil.CreateContextMenu"))
			assert.equals(0, #Mock.Calls("C_PartyInfo.InviteUnit"))
		end)
	end)

	describe("friend line", function()
		it("Shift+Left invites #invite", function()
			Open()
			Helpers.ClickLine("Buddy", "LeftButton", { shift = true })
			assert.same({ "Buddy" }, Args("C_PartyInfo.InviteUnit"))
			assert.equals(0, #Mock.Calls("ChatFrame_SendTell"))
		end)

		it("plain Left whispers #whisper", function()
			Open()
			Helpers.ClickLine("Buddy", "LeftButton")
			assert.same({ "Buddy" }, Args("ChatFrame_SendTell"))
			assert.equals(0, #Mock.Calls("C_PartyInfo.InviteUnit"))
		end)

		it("Alt+Left whispers instead of inviting #whisper", function()
			Open()
			Helpers.ClickLine("Buddy", "LeftButton", { alt = true })
			assert.same({ "Buddy" }, Args("ChatFrame_SendTell"))
			assert.equals(0, #Mock.Calls("C_PartyInfo.InviteUnit"))
		end)
	end)

	describe("Battle.net line", function()
		it("Shift+Left invites through FriendsFrame_BattlenetInvite #invite", function()
			Open()
			Helpers.ClickLine("Pal#1234", "LeftButton", { shift = true })
			assert.same({ nil, 7 }, Args("FriendsFrame_BattlenetInvite"))
			assert.equals(0, #Mock.Calls("ChatFrame_SendBNetTell"))
		end)

		it("Shift+Left invites the single eligible game account without FriendsFrame_BattlenetInvite #invite", function()
			Open()
			FriendsFrame_BattlenetInvite = nil
			Helpers.ClickLine("Pal#1234", "LeftButton", { shift = true })
			assert.same({ 99 }, Args("BNInviteFriend"))
		end)

		it("Shift+Left does nothing when CanGroupWithAccount is false #invite", function()
			Open({ BattleNetFriend({ canGroup = false }) })
			Helpers.ClickLine("Pal#1234", "LeftButton", { shift = true })
			assert.equals(0, #Mock.Calls("FriendsFrame_BattlenetInvite"))
			assert.equals(0, #Mock.Calls("BNInviteFriend"))
			assert.equals(0, #Mock.Calls("ChatFrame_SendBNetTell"))
		end)

		it("plain Left whispers #whisper", function()
			Open()
			Helpers.ClickLine("Pal#1234", "LeftButton")
			assert.same({ "Pal" }, Args("ChatFrame_SendBNetTell"))
			assert.equals(0, #Mock.Calls("FriendsFrame_BattlenetInvite"))
		end)

		it("Alt+Left whispers instead of inviting #whisper", function()
			Open()
			Helpers.ClickLine("Pal#1234", "LeftButton", { alt = true })
			assert.same({ "Pal" }, Args("ChatFrame_SendBNetTell"))
			assert.equals(0, #Mock.Calls("FriendsFrame_BattlenetInvite"))
		end)
	end)

	describe("section header", function()
		it("collapses and expands the friends list", function()
			local ns = Open()
			Helpers.ClickLine(NORMAL_FONT_COLOR_CODE .. ns.L.TOOLTIP_FRIENDS .. ":", "LeftButton")
			assert.is_true(ns.db.CollapseFriends)
			assert.has_error(function() Helpers.TooltipLine("Buddy") end)
			Helpers.ClickLine(NORMAL_FONT_COLOR_CODE .. ns.L.TOOLTIP_FRIENDS .. ":", "LeftButton")
			assert.is_false(ns.db.CollapseFriends)
			assert.is_not_nil(Helpers.TooltipLine("Buddy"))
		end)
	end)
end)
