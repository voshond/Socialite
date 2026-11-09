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

-- The client's widget hierarchy: every Frame and Texture is a Region.
local NOT_REGIONS = { Font = true, AnimationGroup = true, Animation = true, Alpha = true, Translation = true,
	Scale = true, Rotation = true, MenuDescription = true, MenuElement = true }
local NOT_FRAMES = { Texture = true, MaskTexture = true, FontString = true, Line = true }
local BUTTONS = { Button = true, CheckButton = true }
Methods.IsMouseOver = Methods.IsMouseOver or function() return false end
Methods.IsEnabled = Methods.IsEnabled or function() return true end
Methods.HasScript = Methods.HasScript or function() return true end
Methods.GetStringHeight = Methods.GetStringHeight or function() return 12 end
Methods.GetFontObject = Methods.GetFontObject or function(self) return self.__state.fontObject end

-- Like the client, anchors accept a frame name for the relative frame.
local SetPoint, SetAllPoints = Methods.SetPoint, Methods.SetAllPoints
function Methods:SetPoint(point, relativeTo, ...)
	if type(relativeTo) == "string" then relativeTo = _G[relativeTo] end
	return SetPoint(self, point, relativeTo, ...)
end
function Methods:SetAllPoints(relativeTo)
	if type(relativeTo) == "string" then relativeTo = _G[relativeTo] end
	return SetAllPoints(self, relativeTo)
end

-- Like the client, a reparented frame moves to its new parent's level + 1.
local SetParent = Methods.SetParent
function Methods:SetParent(parent)
	SetParent(self, parent)
	local level = parent and rawget(parent, "__state") and parent.__state.level
	if level and not self.__state.fixedLevel and not NOT_FRAMES[self.__type] then self:SetFrameLevel(level + 1) end
end

-- Text width estimate: visible characters times font size times 0.62, a
-- little wider than the sans-serif the proof renders with.
local function FontSize(region)
	local font = region.__state.font
	if font and font[2] then return font[2] end
	local object = region.__state.fontObject
	if type(object) == "string" then object = rawget(_G, object) end
	local objectFont = type(object) == "table" and rawget(object, "__state") and object.__state.font
	return objectFont and objectFont[2] or 12
end
function Methods:GetStringWidth()
	local text = self.__state.text
	if type(text) ~= "string" then return 0 end
	local plain = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "WW")
	return #plain * FontSize(self) * 0.62
end

-- ScrollFrame: the client lays the scroll child out at the frame's top left,
-- moved up by the vertical scroll.
function Methods:SetScrollChild(child)
	self.__state.scrollChild = child
	child.__state.points = { { "TOPLEFT", self, "TOPLEFT", 0, self.__state.verticalScroll or 0 } }
end
function Methods:GetScrollChild() return self.__state.scrollChild end
function Methods:SetVerticalScroll(offset)
	self.__state.verticalScroll = offset
	local child = self.__state.scrollChild
	if child then child.__state.points = { { "TOPLEFT", self, "TOPLEFT", 0, offset } } end
end
function Methods:GetVerticalScroll() return self.__state.verticalScroll or 0 end

-- Screen geometry from the anchors, through wowproof's layout. The client
-- measures from the bottom left; the layout from the top left.
local Layout = require("wowproof.layout")

-- Like the client, per axis an edge anchor (TOP, LEFT, ...) wins over the
-- centre component of another anchor: LEFT + RIGHT + TOP with a height puts
-- the region below TOP, not around the vertical centre LEFT names.
local function Axis(anchors, size)
	local edges = {}
	for _, anchor in ipairs(anchors) do
		if anchor[1] ~= 0.5 then edges[#edges + 1] = anchor end
	end
	if #edges > 0 then anchors = edges end
	local low, high
	for _, anchor in ipairs(anchors) do
		if not low or anchor[1] < low[1] then low = anchor end
		if not high or anchor[1] > high[1] then high = anchor end
	end
	if not low then return nil end
	if low[1] ~= high[1] then
		local span = (high[2] - low[2]) / (high[1] - low[1])
		return low[2] - low[1] * span, span
	end
	return low[2] - low[1] * size, size
end

function Layout:Resolve(region)
	local adapter = self.adapter
	local bar = adapter.FillOf and adapter.FillOf(region)
	if bar then return self:FillRect(bar) end
	local points = adapter.Points(region)
	local parent = adapter.Parent(region)
	if #points == 0 then
		if parent then return nil end
		return self.screen
	end
	local scale = self:Scale(region)
	local width, height = adapter.Size(region)
	width, height = self:IntrinsicSize(region, width or 0, height or 0)
	width, height = width * scale, height * scale
	local xs, ys = {}, {}
	for _, point in ipairs(points) do
		local target = self:Rect(point.relativeTo or parent)
		if not target then return nil end
		if point.all then
			xs[#xs + 1] = { 0, target.left }
			xs[#xs + 1] = { 1, target.left + target.width }
			ys[#ys + 1] = { 0, target.top }
			ys[#ys + 1] = { 1, target.top + target.height }
		else
			local own = Layout.FRACTIONS[point.point]
			local other = Layout.FRACTIONS[point.relativePoint or point.point]
			if not own or not other then
				error("unknown anchor point " .. tostring(point.point) .. "/" .. tostring(point.relativePoint), 2)
			end
			xs[#xs + 1] = { own[1], target.left + other[1] * target.width + (point.x or 0) * scale }
			ys[#ys + 1] = { own[2], target.top + other[2] * target.height - (point.y or 0) * scale }
		end
	end
	local left, resolvedWidth = Axis(xs, width)
	local top, resolvedHeight = Axis(ys, height)
	return { left = left, top = top, width = resolvedWidth, height = resolvedHeight }
end

local adapter = require("wowproof.adapters.mock_state")({ objects = function() return Mock.objects end })

local function ScreenRect(region)
	local width, height = UIParent:GetSize()
	local rect = Layout.New(adapter, { width = width, height = height }):Rect(region)
	if not rect then return nil end
	return rect.left, height - rect.top - rect.height, rect.width, rect.height
end

function Methods:GetLeft()
	local left = ScreenRect(self)
	return left
end
function Methods:GetRight()
	local left, _, width = ScreenRect(self)
	return left and left + width
end
function Methods:GetBottom()
	local _, bottom = ScreenRect(self)
	return bottom
end
function Methods:GetTop()
	local _, bottom, _, height = ScreenRect(self)
	return bottom and bottom + height
end
function Methods:GetCenter()
	local left, bottom, width, height = ScreenRect(self)
	if left then return left + width / 2, bottom + height / 2 end
end
function Methods:GetRect()
	return ScreenRect(self)
end

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

-- Blizzard_SharedXML TooltipBackdropTemplate: a NineSlice in Mainline's
-- TooltipDefaultLayout, coloured by TooltipBackdropOnLoad.
local TOOLTIP_LAYOUT = {
	{ key = "TopLeftCorner", atlas = "Tooltip-NineSlice-CornerTopLeft", point = "TOPLEFT" },
	{ key = "TopRightCorner", atlas = "Tooltip-NineSlice-CornerTopRight", point = "TOPRIGHT" },
	{ key = "BottomLeftCorner", atlas = "Tooltip-NineSlice-CornerBottomLeft", point = "BOTTOMLEFT" },
	{ key = "BottomRightCorner", atlas = "Tooltip-NineSlice-CornerBottomRight", point = "BOTTOMRIGHT" },
	{ key = "TopEdge", atlas = "_Tooltip-NineSlice-EdgeTop", point = "TOPLEFT", relativePoint = "TOPRIGHT",
		between = { "TopLeftCorner", "TopRightCorner" } },
	{ key = "BottomEdge", atlas = "_Tooltip-NineSlice-EdgeBottom", point = "BOTTOMLEFT", relativePoint = "BOTTOMRIGHT",
		between = { "BottomLeftCorner", "BottomRightCorner" } },
	{ key = "LeftEdge", atlas = "!Tooltip-NineSlice-EdgeLeft", point = "TOPLEFT", relativePoint = "BOTTOMLEFT",
		between = { "TopLeftCorner", "BottomLeftCorner" } },
	{ key = "RightEdge", atlas = "!Tooltip-NineSlice-EdgeRight", point = "TOPRIGHT", relativePoint = "BOTTOMRIGHT",
		between = { "TopRightCorner", "BottomRightCorner" } },
	{ key = "Center", atlas = "Tooltip-NineSlice-Center", layer = "BACKGROUND" },
}
local BORDER_PIECES = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
	"TopEdge", "BottomEdge", "LeftEdge", "RightEdge" }

local function ApplyTooltipBackdrop(frame)
	local nineSlice = CreateFrame("Frame", nil, frame)
	nineSlice:SetAllPoints(frame)
	frame.NineSlice = nineSlice
	for _, piece in ipairs(TOOLTIP_LAYOUT) do
		local texture = nineSlice:CreateTexture(nil, piece.layer or "BORDER")
		nineSlice[piece.key] = texture
		local info = C_Texture.GetAtlasInfo(piece.atlas)
		if info then
			texture:SetAtlas(piece.atlas, true)
			texture:SetSize(info.width, info.height)
		end
		if piece.key == "Center" then
			texture:SetPoint("TOPLEFT", nineSlice.TopLeftCorner, "BOTTOMRIGHT", -4, 4)
			texture:SetPoint("BOTTOMRIGHT", nineSlice.BottomRightCorner, "TOPLEFT", 4, -4)
		elseif piece.between then
			texture:SetPoint(piece.point, nineSlice[piece.between[1]], piece.relativePoint)
			texture:SetPoint(piece.relativePoint, nineSlice[piece.between[2]], piece.point)
		else
			texture:SetPoint(piece.point, nineSlice, piece.point)
		end
	end
	rawset(frame, "SetBackdropColor", function(_, r, g, b, a) nineSlice.Center:SetVertexColor(r, g, b, a) end)
	rawset(frame, "SetBackdropBorderColor", function(_, r, g, b, a)
		for _, key in ipairs(BORDER_PIECES) do nineSlice[key]:SetVertexColor(r, g, b, a) end
	end)
	local r, g, b = TOOLTIP_DEFAULT_BACKGROUND_COLOR:GetRGB()
	frame:SetBackdropColor(r, g, b, 1)
end

local function InstallClient(G)
	G.TooltipBackdropTemplateMixin = {}
	G.TOOLTIP_DEFAULT_BACKGROUND_COLOR = CreateColor(0.09, 0.09, 0.19)
	G.TOOLTIP_DEFAULT_COLOR = CreateColor(1, 1, 1)
	local CreateFrame = G.CreateFrame
	G.CreateFrame = function(frameType, name, parent, template, ...)
		local frame = CreateFrame(frameType, name, parent, template, ...)
		if template and template:find("TooltipBackdropTemplate", 1, true) then ApplyTooltipBackdrop(frame) end
		return frame
	end

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
