--[[
Socialite's extension of the shared wowmock client: the social APIs (guild,
character friends, Battle.net), the chat and group actions its click handlers
call, and the few client globals Socialite and its vendored libraries use that
the shared mock doesn't install.

Mock.SetGuild / SetFriends / SetBattleNet seed the social data, and actions
are recorded per global name (Mock.Calls("C_PartyInfo.InviteUnit")).
]]
local Mock = require("wowmock")

local noop = function() end

-- Recorded calls ---------------------------------------------------------------

-- Returns a global stand-in that appends its arguments to Mock.calls[name].
local function Recorder(name, result)
	return function(...)
		local list = Mock.calls[name] or {}
		Mock.calls[name] = list
		list[#list + 1] = { n = select("#", ...), ... }
		return result
	end
end

function Mock.Calls(name)
	return Mock.calls[name] or {}
end

-- Game data ----------------------------------------------------------------------

-- Guild members: { name = "Name-Realm", rank, rankIndex, level, class, zone, note,
-- officerNote, status (0/1/2), classFileName, isMobile }. Only online members.
function Mock.SetGuild(members, guildName)
	Mock.social.guildName = guildName or "Test Guild"
	Mock.social.guild = members
end

-- Character friends: C_FriendList.GetFriendInfoByIndex tables, online first.
function Mock.SetFriends(friends)
	Mock.social.friends = friends
end

-- Battle.net friends: C_BattleNet.GetFriendAccountInfo tables, each with a
-- gameAccounts array of GetFriendGameAccountInfo tables.
function Mock.SetBattleNet(accounts)
	Mock.social.bnet = accounts
end

function Mock.SetModifiers(modifiers)
	Mock.social.shift = modifiers.shift == true
	Mock.social.alt = modifiers.alt == true
	Mock.social.ctrl = modifiers.ctrl == true
end

local function OnlineFriends()
	local online = 0
	for _, friend in ipairs(Mock.social.friends) do
		if friend.connected ~= false then online = online + 1 end
	end
	return online
end

-- Widget methods the shared mock records without a useful return value.
local Methods = Mock.Methods
Methods.IsMouseOver = Methods.IsMouseOver or function() return false end
Methods.IsEnabled = Methods.IsEnabled or function() return true end
Methods.GetStringHeight = Methods.GetStringHeight or function() return 12 end
Methods.GetFontObject = Methods.GetFontObject or function(self) return self.__state.fontObject end

-- Like real frames, unknown lowercase keys (addon fields such as
-- tooltip.anchor) read as nil; client methods are all capitalized.
local function FieldsReadNil(objectMT)
	if objectMT.__socialiteFields then return end
	local index = objectMT.__index
	objectMT.__index = function(obj, key)
		if type(key) == "string" and key:match("^%l") and not Methods[key] then return nil end
		return index(obj, key)
	end
	objectMT.__socialiteFields = true
end

-- The client's widget hierarchy: every Frame and Texture is a Region.
local NOT_REGIONS = { Font = true, AnimationGroup = true, Animation = true, Alpha = true, Translation = true,
	Scale = true, Rotation = true, MenuDescription = true, MenuElement = true }
local NOT_FRAMES = { Texture = true, MaskTexture = true, FontString = true, Line = true }
local BUTTONS = { Button = true, CheckButton = true }
function Methods:IsObjectType(objectType)
	local own = self.__type
	if objectType == own or objectType == "Object" then return true end
	if NOT_REGIONS[own] then return false end
	if objectType == "Region" or objectType == "ScriptRegion" then return true end
	if objectType == "Frame" then return not NOT_FRAMES[own] end
	if objectType == "Button" then return BUTTONS[own] == true end
	return false
end

-- Button texture slots: Set<Slot>Texture takes a file or a texture, and
-- Get<Slot>Texture returns the slot's texture region.
local function SlotTexture(self, slot)
	local key = "slot" .. slot
	if not self.__state[key] then self.__state[key] = Mock.NewObject("Texture", self) end
	return self.__state[key]
end
for _, slot in ipairs({ "Normal", "Pushed", "Highlight", "Disabled", "Checked", "DisabledChecked" }) do
	Methods["Set" .. slot .. "Texture"] = function(self, asset)
		if type(asset) == "table" then
			self.__state["slot" .. slot] = asset
		else
			SlotTexture(self, slot):SetTexture(asset)
		end
	end
	Methods["Get" .. slot .. "Texture"] = function(self) return SlotTexture(self, slot) end
end

local function InstallClient(G)
	-- Lua aliases the client provides.
	G.tremove, G.sort = table.remove, table.sort
	G.strfind, G.strmatch, G.strsub, G.strlen = string.find, string.match, string.sub, string.len
	G.strlower, G.strupper, G.strrep, G.strbyte, G.strchar = string.lower, string.upper, string.rep, string.byte, string.char
	G.format, G.gsub, G.gmatch = string.format, string.gsub, string.gmatch
	G.floor, G.ceil, G.abs, G.min, G.max, G.mod = math.floor, math.ceil, math.abs, math.min, math.max, math.fmod
	G.strsplit = function(separator, text, limit)
		local parts, start, delimiters = {}, 1, "[" .. separator:gsub("%p", "%%%0") .. "]"
		while not limit or #parts < limit - 1 do
			local first, last = text:find(delimiters, start)
			if not first then break end
			parts[#parts + 1] = text:sub(start, first - 1)
			start = last + 1
		end
		parts[#parts + 1] = text:sub(start)
		return unpack(parts)
	end
	G.strjoin = function(separator, ...) return table.concat({ ... }, separator) end
	G.tostringall = function(...)
		local out = {}
		for i = 1, select("#", ...) do out[i] = tostring((select(i, ...))) end
		return unpack(out, 1, select("#", ...))
	end
	G.geterrorhandler = function() return function(err) error(err, 0) end end
	G.seterrorhandler = noop
	G.securecall = function(fn, ...)
		if type(fn) == "string" then fn = G[fn] end
		return fn(...)
	end
	G.hooksecurefunc = function(target, name, hook)
		if type(target) == "string" then target, name, hook = G, target, name end
		local original = target[name]
		target[name] = function(...)
			local results = { original(...) }
			hook(...)
			return unpack(results)
		end
	end
	G.GetCursorPosition = function() return 0, 0 end
	G.PlaySound = noop
	G.GetBindingText = function(key) return key end

	-- Frames and fonts.
	UIParent:SetSize(1920, 1080)
	G.WorldFrame = Mock.NewObject("Frame", nil, "WorldFrame")
	G.GameTooltip = Mock.NewObject("GameTooltip", UIParent, "GameTooltip")
	for _, font in ipairs({ "GameTooltipText", "GameTooltipHeaderText", "GameFontHighlight", "GameFontHighlightSmall",
		"GameFontNormalSmall", "GameFontNormalLarge", "GameFontDisable", "GameFontHighlightLarge", "ChatFontNormal" }) do
		CreateFont(font):SetFont([[Fonts\FRIZQT__.TTF]], 12, "")
	end
	G.C_UIColor = {
		GetColors = function()
			return {
				{ baseTag = "NORMAL_FONT_COLOR", color = { r = 1, g = 0.82, b = 0 } },
				{ baseTag = "HIGHLIGHT_FONT_COLOR", color = { r = 1, g = 1, b = 1 } },
			}
		end,
	}
	G.NORMAL_FONT_COLOR = { r = 1, g = 0.82, b = 0 }
	G.HIGHLIGHT_FONT_COLOR = { r = 1, g = 1, b = 1 }
	G.NORMAL_FONT_COLOR_CODE = "|cffffd200"
	G.HIGHLIGHT_FONT_COLOR_CODE = "|cffffffff"
	G.DISABLED_FONT_COLOR_CODE = "|cff808080"
	G.FONT_COLOR_CODE_CLOSE = "|r"
	G.RAID_CLASS_COLORS = {
		WARRIOR = { colorStr = "ffc69b6d" },
		MAGE = { colorStr = "ff3fc7eb" },
		PRIEST = { colorStr = "ffffffff" },
	}
	G.LOCALIZED_CLASS_NAMES_MALE = { WARRIOR = "Warrior", MAGE = "Mage", PRIEST = "Priest" }
	G.LOCALIZED_CLASS_NAMES_FEMALE = { WARRIOR = "Warrior", MAGE = "Mage", PRIEST = "Priest" }

	-- Strings.
	G.CHAT_FLAG_AFK = "<AFK>"
	G.CHAT_FLAG_DND = "<DND>"
	G.FRIENDS_TEXTURE_AFK = "Interface\\FriendsFrame\\StatusIcon-Away"
	G.FRIENDS_TEXTURE_DND = "Interface\\FriendsFrame\\StatusIcon-DnD"
	G.BNET_CLIENT_WOW = "WoW"
	G.BNET_CLIENT_APP = "App"
	G.BNET_CLIENT_WTCG = "WTCG"
	G.FRIENDS_LIST_PLAYING = "Playing"
	G.CANNOT_COOPERATE_LABEL = "*"
	G.FRIENDS_TOOLTIP_WOW_TOON_TEMPLATE = "%s, Level %s %s %s"
	G.WHISPER, G.INVITE, G.WHO = "Whisper", "Invite", "Who"
	G.ACCEPT, G.CANCEL, G.OKAY, G.CLOSE = "Accept", "Cancel", "Okay", "Close"

	-- Settings and slash commands.
	G.hash_SlashCmdList = {}
	G.Settings = {
		RegisterCanvasLayoutCategory = function(frame, name) return { ID = name, frame = frame, name = name } end,
		RegisterCanvasLayoutSubcategory = function(_, frame, name) return { ID = name, frame = frame, name = name } end,
		RegisterAddOnCategory = noop,
		GetCategory = function() return nil end,
		OpenToCategory = Recorder("Settings.OpenToCategory"),
	}
end

local function InstallSocial(G)
	-- Player, group and chat.
	G.UnitName = function() return "Player", nil end
	G.UnitInParty = function() return false end
	G.UnitInRaid = function() return nil end
	G.IsShiftKeyDown = function() return Mock.social.shift end
	G.IsAltKeyDown = function() return Mock.social.alt end
	G.IsControlKeyDown = function() return Mock.social.ctrl end
	G.Ambiguate = function(name, _)
		return (name:gsub("%-" .. G.GetRealmName() .. "$", ""))
	end
	G.C_PartyInfo = { InviteUnit = Recorder("C_PartyInfo.InviteUnit") }
	G.ChatFrame_SendTell = Recorder("ChatFrame_SendTell")
	G.ChatFrame_SendBNetTell = Recorder("ChatFrame_SendBNetTell")
	G.FriendsFrame_ShowDropdown = Recorder("FriendsFrame_ShowDropdown")
	G.FriendsFrame_ShowBNDropdown = Recorder("FriendsFrame_ShowBNDropdown")
	G.FriendsFrame_BattlenetInvite = Recorder("FriendsFrame_BattlenetInvite")
	G.BNInviteFriend = Recorder("BNInviteFriend")
	G.ToggleFriendsFrame = Recorder("ToggleFriendsFrame")
	G.ToggleGuildFrame = Recorder("ToggleGuildFrame")
	G.MenuUtil = { CreateContextMenu = Recorder("MenuUtil.CreateContextMenu") }

	-- Character friends.
	G.C_FriendList = {
		GetNumFriends = function() return #Mock.social.friends end,
		GetNumOnlineFriends = OnlineFriends,
		GetFriendInfoByIndex = function(index) return Mock.social.friends[index] end,
		GetFriendInfo = function(name)
			for _, friend in ipairs(Mock.social.friends) do
				if friend.name == name then return friend end
			end
		end,
		SendWho = Recorder("C_FriendList.SendWho"),
	}

	-- Battle.net friends.
	G.BNGetNumFriends = function() return #Mock.social.bnet, #Mock.social.bnet end
	G.BNGetFriendIndex = function(bnetAccountID)
		for index, account in ipairs(Mock.social.bnet) do
			if account.bnetAccountID == bnetAccountID then return index end
		end
	end
	G.CanGroupWithAccount = function(bnetAccountID)
		local index = G.BNGetFriendIndex(bnetAccountID)
		return index ~= nil and Mock.social.bnet[index].canGroup == true
	end
	G.C_BattleNet = {
		GetFriendAccountInfo = function(index) return Mock.social.bnet[index] end,
		GetFriendNumGameAccounts = function(index)
			local account = Mock.social.bnet[index]
			return account and #(account.gameAccounts or {}) or 0
		end,
		GetFriendGameAccountInfo = function(index, accountIndex)
			local account = Mock.social.bnet[index]
			return account and account.gameAccounts and account.gameAccounts[accountIndex]
		end,
	}

	-- Guild.
	G.IsInGuild = function() return Mock.social.guildName ~= nil end
	G.GetGuildInfo = function() return Mock.social.guildName end
	G.GetNumGuildMembers = function() return #Mock.social.guild, #Mock.social.guild end
	G.GetGuildRosterShowOffline = function() return Mock.social.showOffline end
	G.SetGuildRosterShowOffline = function(show) Mock.social.showOffline = show end
	G.CanViewOfficerNote = function() return true end
	G.GetGuildRosterInfo = function(index)
		local m = Mock.social.guild[index]
		if not m then return nil end
		return m.name, m.rank or "Member", m.rankIndex or 1, m.level or 80, m.class or "Warrior", m.zone or "",
			m.note or "", m.officerNote or "", true, m.status or 0, m.classFileName or "WARRIOR", 0, 0, m.isMobile == true
	end
end

Mock.Extend("Socialite", {
	globals = {
		"SocialiteSettings", "SLASH_SOCIALITE1", "ACECONSOLE_SOCIALITE1", "AddonCompartmentFrame",
		"SLASH_ACECONSOLE_SOCIALITE1",
	},
	install = function()
		Mock.calls = {}
		Mock.social = { guild = {}, friends = {}, bnet = {}, guildName = nil, showOffline = false,
			shift = false, alt = false, ctrl = false }
		FieldsReadNil(getmetatable(UIParent))
		InstallClient(_G)
		InstallSocial(_G)
	end,
})

return Mock
