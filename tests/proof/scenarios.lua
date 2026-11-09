-- Titan Panel's top bar with the Socialite button, hovered so its tooltip is open.
local Helpers = require("helpers")
local Mock = Helpers.Mock

local GUILD = {
	{ name = "Thrall-TestRealm", rank = "Guild Master", rankIndex = 0, level = 60, class = "Shaman", classFileName = "SHAMAN", zone = "Orgrimmar", note = "Warchief" },
	{ name = "Jaina-TestRealm", rank = "Officer", rankIndex = 1, level = 60, class = "Mage", classFileName = "MAGE", zone = "Theramore Isle" },
	{ name = "Guildie-TestRealm", rank = "Member", rankIndex = 2, level = 42, class = "Warrior", classFileName = "WARRIOR", zone = "Stranglethorn Vale", status = 1 },
	{ name = "Faraway-OtherRealm", rank = "Member", rankIndex = 2, level = 58, class = "Priest", classFileName = "PRIEST", zone = "Ironforge" },
	{ name = "Phoney-TestRealm", rank = "Initiate", rankIndex = 3, level = 12, class = "Warrior", classFileName = "WARRIOR", isMobile = true },
}

local FRIENDS = {
	{ name = "Buddy", className = "Mage", level = 60, connected = true, area = "Stormwind City", notes = "raid Thursday" },
	{ name = "Pal", className = "Priest", level = 35, connected = true, area = "Darkshore", notes = "", afk = true },
}

local function Character(name, overrides)
	local info = {
		characterName = name, clientProgram = "WoW", realmName = "TestRealm", realmID = 1,
		factionName = "Alliance", raceName = "Human", className = "Priest", areaName = "Stormwind City",
		characterLevel = 60, hasFocus = true, gameAccountID = 99,
	}
	for key, value in pairs(overrides or {}) do info[key] = value end
	return info
end

local BATTLE_NET = {
	{
		bnetAccountID = 7, accountName = "Anduin", battleTag = "Anduin#1234", isBattleTagFriend = true,
		gameAccountInfo = { isAFK = false, isDND = false, clientProgram = "WoW" },
		canGroup = true, gameAccounts = { Character("Wrynn") },
	},
	{
		bnetAccountID = 8, accountName = "Sylvanas", battleTag = "Sylvanas#4242", isBattleTagFriend = true,
		gameAccountInfo = { isAFK = true, isDND = false, clientProgram = "WoW" },
		canGroup = false, gameAccounts = { Character("Windrunner", { factionName = "Horde", raceName = "Undead", className = "Hunter", areaName = "Undercity", gameAccountID = 100 }) },
	},
}

-- Loads Titan and Socialite, seeds the social data and hovers the Titan button.
local function Hover(options)
	options = options or {}
	local ns, button = Helpers.LoadWithTitan({ saved = options.saved })
	if not options.empty then
		Mock.SetGuild(GUILD, "Socialite Testers")
		Mock.SetFriends(FRIENDS)
		Mock.SetBattleNet(BATTLE_NET)
	end
	Mock.FireEvent("GUILD_ROSTER_UPDATE")
	button:RunScript("OnEnter")
	assert(ns.tooltip:IsShown(), "Socialite's tooltip did not open")
	assert(#Mock.messages == 0, "client chat: " .. tostring(Mock.messages[1] and Mock.messages[1][1]))
	if options.check then options.check(ns) end
	return UIParent
end

local function NoLine(text)
	local ok = pcall(Helpers.TooltipLine, text)
	assert(not ok, text .. " is shown")
end

return {
	{
		name = "titan-tooltip-full",
		build = function()
			return Hover({ check = function()
				Helpers.TooltipLine("Thrall")
				Helpers.TooltipLine("Buddy")
				Helpers.TooltipLine("Anduin#1234")
			end })
		end,
	},
	{
		name = "titan-tooltip-guild-collapsed",
		build = function()
			return Hover({ saved = { CollapseGuild = true }, check = function()
				for _, member in ipairs(GUILD) do NoLine(member.name:match("^[^-]+")) end
				Helpers.TooltipLine("Buddy")
			end })
		end,
	},
	{
		name = "titan-tooltip-empty",
		build = function() return Hover({ empty = true }) end,
	},
}
