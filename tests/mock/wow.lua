--[[
Minimal WoW client mock for Socialite specs: only what Socialite and its
vendored libraries touch. Mock.Install() resets every global it owns, so each
test can start from a clean client.

Frames answer any unknown Capitalized method with a no-op (layout calls the
specs don't care about); methods whose return values matter are real.
]]
local Mock = {}

local noop = function() end

-- Widgets ----------------------------------------------------------------------

local Widget = {}
local WidgetMeta = {
	__index = function(_, key)
		local method = Widget[key]
		if method ~= nil then return method end
		if type(key) == "string" and key:match("^%u") then return noop end
	end,
}

local function NewWidget(objectType, name, parent)
	local widget = setmetatable({
		__type = objectType,
		__name = name,
		__parent = parent,
		__scripts = {},
		__events = {},
		__shown = true,
		__width = 0,
		__height = 0,
		__scale = 1,
		__level = 1,
		__text = nil,
		__value = 0,
		__min = 0,
		__max = 0,
	}, WidgetMeta)
	Mock.widgets[#Mock.widgets + 1] = widget
	if name then _G[name] = widget end
	return widget
end

function Widget:GetObjectType() return self.__type end
function Widget:IsObjectType(objectType)
	return objectType == self.__type or objectType == "Region" or objectType == "Frame" and self.__type ~= "Texture" and self.__type ~= "FontString"
end
function Widget:GetName() return self.__name end
function Widget:GetParent() return self.__parent end
function Widget:SetParent(parent) self.__parent = parent end
function Widget:Show()
	local wasShown = self.__shown
	self.__shown = true
	if not wasShown then Mock.RunScript(self, "OnShow") end
end
function Widget:Hide()
	local wasShown = self.__shown
	self.__shown = false
	if wasShown then Mock.RunScript(self, "OnHide") end
end
function Widget:SetShown(shown) if shown then self:Show() else self:Hide() end end
function Widget:IsShown() return self.__shown end
function Widget:IsVisible() return self.__shown end
function Widget:IsMouseOver() return false end
function Widget:GetWidth() return self.__width end
function Widget:GetHeight() return self.__height end
function Widget:SetWidth(width) self.__width = width end
function Widget:SetHeight(height) self.__height = height end
function Widget:SetSize(width, height) self.__width, self.__height = width, height end
function Widget:GetSize() return self.__width, self.__height end
function Widget:GetScale() return self.__scale end
function Widget:SetScale(scale) self.__scale = scale end
function Widget:GetEffectiveScale() return self.__scale end
function Widget:GetFrameLevel() return self.__level end
function Widget:SetFrameLevel(level) self.__level = level end
function Widget:GetFrameStrata() return "MEDIUM" end
function Widget:GetNumPoints() return 0 end
function Widget:GetCenter() return nil end
function Widget:GetTop() return nil end
function Widget:GetBottom() return nil end
function Widget:GetLeft() return nil end
function Widget:GetRight() return nil end
function Widget:SetScript(script, handler) self.__scripts[script] = handler end
function Widget:GetScript(script) return self.__scripts[script] end
function Widget:HasScript() return true end
function Widget:HookScript(script, handler)
	local previous = self.__scripts[script]
	self.__scripts[script] = function(...)
		if previous then previous(...) end
		handler(...)
	end
end
function Widget:RegisterEvent(event) self.__events[event] = true end
function Widget:UnregisterEvent(event) self.__events[event] = nil end
function Widget:UnregisterAllEvents() self.__events = {} end
function Widget:IsEventRegistered(event) return self.__events[event] == true end
function Widget:CreateTexture(name) return NewWidget("Texture", name, self) end
function Widget:CreateFontString(name) return NewWidget("FontString", name, self) end
function Widget:CreateMaskTexture(name) return NewWidget("Texture", name, self) end
function Widget:CreateAnimationGroup() return NewWidget("AnimationGroup", nil, self) end
function Widget:CreateAnimation() return NewWidget("Animation", nil, self) end
function Widget:GetChildren() return end
function Widget:GetRegions() return end
function Widget:SetText(text) self.__text = text end
function Widget:GetText() return self.__text end
function Widget:SetFormattedText(format, ...) self.__text = format:format(...) end
function Widget:GetStringWidth() return #tostring(self.__text or "") * 6 end
function Widget:GetStringHeight() return 12 end
function Widget:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
function Widget:GetFontObject() return Mock.fontObject end
function Widget:GetTextColor() return 1, 1, 1, 1 end
function Widget:GetVertexColor() return 1, 1, 1, 1 end
function Widget:GetValue() return self.__value end
function Widget:SetValue(value)
	self.__value = value
	Mock.RunScript(self, "OnValueChanged", value)
end
function Widget:GetMinMaxValues() return self.__min, self.__max end
function Widget:SetMinMaxValues(min, max) self.__min, self.__max = min, max end
function Widget:GetValueStep() return 1 end
function Widget:GetTexture() return nil end
function Widget:GetThumbTexture() return NewWidget("Texture", nil, self) end
function Widget:GetHighlightTexture() return NewWidget("Texture", nil, self) end
function Widget:GetNormalTexture() return NewWidget("Texture", nil, self) end
function Widget:GetPushedTexture() return NewWidget("Texture", nil, self) end
function Widget:GetFontString() return self.__fontString or NewWidget("FontString", nil, self) end
function Widget:IsEnabled() return true end
function Widget:GetID() return 0 end
function Widget:GetNumLetters() return #tostring(self.__text or "") end
function Widget:GetCursorPosition() return 0 end
function Widget:HasFocus() return false end
function Widget:GetHitRectInsets() return 0, 0, 0, 0 end
function Widget:IsMouseEnabled() return false end
function Widget:GetVerticalScroll() return 0 end
function Widget:GetVerticalScrollRange() return 0 end

-- Runs a widget script with the widget as self, the way the client does.
function Mock.RunScript(widget, script, ...)
	local handler = widget.__scripts[script]
	if handler then return handler(widget, ...) end
end

-- Fires an event on every frame that registered it.
function Mock.FireEvent(event, ...)
	for _, widget in ipairs(Mock.widgets) do
		if widget.__events[event] then
			Mock.RunScript(widget, "OnEvent", event, ...)
		end
	end
end

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

-- Game data -----------------------------------------------------------------------

-- Guild members: { name = "Name-Realm", rank, rankIndex, level, class, zone, note,
-- officerNote, status (0/1/2), classFileName, isMobile }. Only online members.
function Mock.SetGuild(members, guildName)
	Mock.state.guildName = guildName or "Test Guild"
	Mock.state.guild = members
end

-- Character friends: C_FriendList.GetFriendInfoByIndex tables, online first.
function Mock.SetFriends(friends)
	Mock.state.friends = friends
end

-- Battle.net friends: C_BattleNet.GetFriendAccountInfo tables, each with a
-- gameAccounts array of GetFriendGameAccountInfo tables.
function Mock.SetBattleNet(accounts)
	Mock.state.bnet = accounts
end

function Mock.SetModifiers(modifiers)
	Mock.state.shift = modifiers.shift == true
	Mock.state.alt = modifiers.alt == true
	Mock.state.ctrl = modifiers.ctrl == true
end

local function OnlineFriends()
	local online = 0
	for _, friend in ipairs(Mock.state.friends) do
		if friend.connected ~= false then online = online + 1 end
	end
	return online
end

-- Install --------------------------------------------------------------------------

local OWNED = {
	"LibStub", "SocialiteSettings", "SlashCmdList", "hash_SlashCmdList",
	"SLASH_SOCIALITE1", "ACECONSOLE_SOCIALITE1", "AddonCompartmentFrame",
}

function Mock.Install()
	Mock.widgets = {}
	Mock.calls = {}
	Mock.printed = {}
	Mock.state = { guild = {}, friends = {}, bnet = {}, guildName = nil, shift = false, alt = false, ctrl = false }
	for _, name in ipairs(OWNED) do _G[name] = nil end

	local G = _G
	G.print = function(...)
		local parts = {}
		for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
		Mock.printed[#Mock.printed + 1] = table.concat(parts, " ")
	end

	-- Lua aliases the client provides.
	G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
	table.wipe = G.wipe
	G.tinsert, G.tremove, G.sort = table.insert, table.remove, table.sort
	G.strfind, G.strmatch, G.strsub, G.strlen = string.find, string.match, string.sub, string.len
	G.strlower, G.strupper, G.strrep, G.strbyte, G.strchar = string.lower, string.upper, string.rep, string.byte, string.char
	G.format, G.gsub, G.gmatch = string.format, string.gsub, string.gmatch
	G.floor, G.ceil, G.abs, G.min, G.max, G.mod = math.floor, math.ceil, math.abs, math.min, math.max, math.fmod
	G.strtrim = function(text) return (text:gsub("^%s+", ""):gsub("%s+$", "")) end
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
	G.securecallfunction = function(fn, ...) return fn(...) end
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
	G.issecretvalue = function() return false end
	G.GetTime = function() return 0 end
	G.GetLocale = function() return "enUS" end
	G.GetBuildInfo = function() return "12.0.1", "00000", "Jan 1 2026", 120001 end
	G.InCombatLockdown = function() return false end
	G.GetCursorPosition = function() return 0, 0 end
	G.PlaySound = noop
	G.GetBindingText = function(key) return key end

	-- Frames and fonts.
	G.CreateFrame = function(objectType, name, parent) return NewWidget(objectType, name, parent) end
	G.UIParent = NewWidget("Frame", "UIParent")
	G.UIParent:SetSize(1920, 1080)
	G.WorldFrame = NewWidget("Frame", "WorldFrame")
	G.Minimap = NewWidget("Minimap", "Minimap")
	G.GameTooltip = NewWidget("GameTooltip", "GameTooltip")
	Mock.fontObject = NewWidget("Font", "GameFontNormal")
	for _, font in ipairs({ "GameTooltipText", "GameTooltipHeaderText", "GameFontHighlight", "GameFontHighlightSmall",
		"GameFontNormalSmall", "GameFontNormalLarge", "GameFontDisable", "GameFontHighlightLarge", "ChatFontNormal" }) do
		G[font] = NewWidget("Font", font)
	end
	G.CreateFont = function(name) return NewWidget("Font", name) end
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

	-- Addons, settings and slash commands.
	G.C_AddOns = {
		IsAddOnLoaded = function() return false end,
		GetAddOnMetadata = function() return nil end,
	}
	G.SlashCmdList = {}
	G.hash_SlashCmdList = {}
	G.Settings = {
		RegisterCanvasLayoutCategory = function(frame, name) return { ID = name, frame = frame, name = name } end,
		RegisterCanvasLayoutSubcategory = function(_, frame, name) return { ID = name, frame = frame, name = name } end,
		RegisterAddOnCategory = noop,
		GetCategory = function() return nil end,
		OpenToCategory = Recorder("Settings.OpenToCategory"),
	}

	-- Player, group and chat.
	G.GetRealmName = function() return "TestRealm" end
	G.UnitName = function() return "Player", nil end
	G.UnitFactionGroup = function() return "Alliance", "Alliance" end
	G.IsInGroup = function() return false end
	G.IsInRaid = function() return false end
	G.UnitInParty = function() return false end
	G.UnitInRaid = function() return nil end
	G.IsShiftKeyDown = function() return Mock.state.shift end
	G.IsAltKeyDown = function() return Mock.state.alt end
	G.IsControlKeyDown = function() return Mock.state.ctrl end
	G.Ambiguate = function(name, _)
		return (name:gsub("%-" .. G.GetRealmName() .. "$", ""))
	end
	G.C_PartyInfo = { InviteUnit = Recorder("C_PartyInfo.InviteUnit") }
	G.ChatFrame_SendTell = Recorder("ChatFrame_SendTell")
	G.ChatFrame_SendBNetTell = Recorder("ChatFrame_SendBNetTell")
	G.ChatFrameUtil = nil
	G.FriendsFrame_ShowDropdown = Recorder("FriendsFrame_ShowDropdown")
	G.FriendsFrame_ShowBNDropdown = Recorder("FriendsFrame_ShowBNDropdown")
	G.FriendsFrame_BattlenetInvite = Recorder("FriendsFrame_BattlenetInvite")
	G.BNInviteFriend = Recorder("BNInviteFriend")
	G.ToggleFriendsFrame = Recorder("ToggleFriendsFrame")
	G.ToggleGuildFrame = Recorder("ToggleGuildFrame")
	G.MenuUtil = { CreateContextMenu = Recorder("MenuUtil.CreateContextMenu") }

	-- Character friends.
	G.C_FriendList = {
		GetNumFriends = function() return #Mock.state.friends end,
		GetNumOnlineFriends = OnlineFriends,
		GetFriendInfoByIndex = function(index) return Mock.state.friends[index] end,
		GetFriendInfo = function(name)
			for _, friend in ipairs(Mock.state.friends) do
				if friend.name == name then return friend end
			end
		end,
		SendWho = Recorder("C_FriendList.SendWho"),
	}

	-- Battle.net friends.
	G.BNGetNumFriends = function() return #Mock.state.bnet, #Mock.state.bnet end
	G.BNGetFriendIndex = function(bnetAccountID)
		for index, account in ipairs(Mock.state.bnet) do
			if account.bnetAccountID == bnetAccountID then return index end
		end
	end
	G.CanGroupWithAccount = function(bnetAccountID)
		local index = G.BNGetFriendIndex(bnetAccountID)
		return index ~= nil and Mock.state.bnet[index].canGroup == true
	end
	G.C_BattleNet = {
		GetFriendAccountInfo = function(index) return Mock.state.bnet[index] end,
		GetFriendNumGameAccounts = function(index)
			local account = Mock.state.bnet[index]
			return account and #(account.gameAccounts or {}) or 0
		end,
		GetFriendGameAccountInfo = function(index, accountIndex)
			local account = Mock.state.bnet[index]
			return account and account.gameAccounts and account.gameAccounts[accountIndex]
		end,
	}

	-- Guild.
	G.IsInGuild = function() return Mock.state.guildName ~= nil end
	G.GetGuildInfo = function() return Mock.state.guildName end
	G.GetNumGuildMembers = function() return #Mock.state.guild, #Mock.state.guild end
	G.GetGuildRosterShowOffline = function() return false end
	G.SetGuildRosterShowOffline = noop
	G.CanViewOfficerNote = function() return true end
	G.GetGuildRosterInfo = function(index)
		local m = Mock.state.guild[index]
		if not m then return nil end
		return m.name, m.rank or "Member", m.rankIndex or 1, m.level or 80, m.class or "Warrior", m.zone or "",
			m.note or "", m.officerNote or "", true, m.status or 0, m.classFileName or "WARRIOR", 0, 0, m.isMobile == true
	end
end

return Mock
