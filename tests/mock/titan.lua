--[[
Titan Panel's XML frames for wowmock, which only loads the Lua side of XML
files. Mirrors Titan/Titan.xml and Titan/TitanTemplate.xml: the named frames
exist before Titan's Lua runs, and CreateFrame with a Titan template builds
the template's children and scripts, then runs its OnLoad like the client.
]]
local Mock = require("wowmock")

local noop = function() end

local function Child(name, suffix)
	return name and name .. suffix or nil
end

local function ButtonScripts(frame)
	frame:SetScript("OnLoad", function(self) Titan_G.plugins.OnLoad(self) end)
	frame:SetScript("OnShow", function(self) Titan_G.plugins.OnShow(self) end)
	frame:SetScript("OnClick", function(self, button) Titan_G.plugins.OnClick(self, button) end)
	frame:SetScript("OnEnter", function(self) Titan_G.plugins.OnEnter(self) end)
	frame:SetScript("OnLeave", function(self) Titan_G.plugins.OnLeave(self) end)
	frame.__state.shown = false
end

local function ButtonText(frame, name)
	local text = frame:CreateFontString(Child(name, "Text"), "ARTWORK", "GameFontNormalSmall")
	text:SetPoint("LEFT", frame, "LEFT", 0, 1)
	text:SetJustifyH("LEFT")
	frame:SetFontString(text)
	return text
end

local function Icon(frame, name, width)
	local icon = frame:CreateTexture(Child(name, "Icon"), "ARTWORK")
	icon:SetSize(width, 16)
	icon:SetPoint("LEFT", frame, "LEFT")
	return icon
end

local TEMPLATES = {
	TitanPanelButtonTemplate = function(frame)
		ButtonScripts(frame)
	end,
	TitanPanelTextTemplate = function(frame, name)
		ButtonScripts(frame)
		frame:SetSize(0, 16)
		ButtonText(frame, name)
	end,
	TitanPanelIconTemplate = function(frame, name)
		ButtonScripts(frame)
		frame:SetSize(16, 16)
		Icon(frame, name, 16)
	end,
	TitanPanelComboTemplate = function(frame, name)
		ButtonScripts(frame)
		frame:SetSize(0, 16)
		Icon(frame, name, 0)
		ButtonText(frame, name)
	end,
	TitanOptionsSliderTemplate = function(frame, name)
		frame:SetSize(10, 100)
		for _, suffix in ipairs({ "Title", "Text", "Low", "High" }) do
			frame:CreateFontString(Child(name, suffix), "ARTWORK", "GameFontGreenSmall")
		end
		frame:SetScript("OnLoad", function(self) Titan_G.control.Slider_OnLoad(self) end)
	end,
	TitanPanelBarButtonHiderTemplate = function(frame)
		frame:SetFrameStrata("BACKGROUND")
		frame:SetSize(2560, 24)
		frame:SetScript("OnLoad", function(self) self:RegisterForClicks("LeftButtonUp", "RightButtonDown") end)
	end,
	Titan_Bar__Display_Template = function(frame)
		frame:SetFrameStrata("DIALOG")
	end,
}

local function SplitTemplates(template)
	local titan, others = {}, {}
	for part in (template or ""):gmatch("[^,%s]+") do
		if TEMPLATES[part] then titan[#titan + 1] = part else others[#others + 1] = part end
	end
	if (template or ""):find("Titan_Bar__Display_Template", 1, true) then others[#others + 1] = "BackdropTemplate" end
	return titan, #others > 0 and table.concat(others, ",") or nil
end

-- The client's bit library: LuaJIT has it, Lua 5.1 needs a stand-in.
local function Bitwise(keep)
	return function(a, b)
		local result, place = 0, 1
		a, b = a % 2 ^ 32, b % 2 ^ 32
		for _ = 1, 32 do
			if keep(a % 2, b % 2) then result = result + place end
			a, b, place = math.floor(a / 2), math.floor(b / 2), place * 2
		end
		return result
	end
end
local BIT = {
	band = Bitwise(function(x, y) return x == 1 and y == 1 end),
	bor = Bitwise(function(x, y) return x == 1 or y == 1 end),
	bxor = Bitwise(function(x, y) return x ~= y end),
}

-- FrameXML globals Titan reads that Socialite's mock doesn't install.
local function InstallClient(G)
	G.bit = G.bit or BIT
	G.GREEN_FONT_COLOR_CODE = "|cff20ff20"
	G.RED_FONT_COLOR_CODE = "|cffff2020"
	G.GRAY_FONT_COLOR_CODE = "|cff808080"
	G.LIGHTYELLOW_FONT_COLOR_CODE = "|cffffff9a"
	G.GRAY_FONT_COLOR = { r = 0.5, g = 0.5, b = 0.5 }
	G.RED_FONT_COLOR = { r = 1, g = 0.1, b = 0.1 }
	for name, text in pairs({ ALL = "All", BACKGROUND = "Background", COLOR = "Color", COMMAND = "Command",
		CUSTOM = "Custom", FACTION = "Faction", HELP_LABEL = "Help", HIDE = "Hide", HIGH = "High", LOW = "Low",
		IGNORE = "Ignore", LABEL_NOTE = "Note", MUTE = "Mute", MUTED = "Muted", NO = "No", NONE = "None", PVP = "PvP",
		RESET_POSITION = "Reset Position", SHORT = "Short", SHOW = "Show", USE = "Use", YES = "Yes",
		UKNOWNBEING = "Unknown Being", HUD_EDIT_MODE_MENU = "Edit Mode" }) do
		G[name] = text
	end
	G.issecurevariable = function() return false end
	-- Blizzard_UIDropDownMenu, which Titan hooks at load.
	G.UIDROPDOWNMENU_MAXLEVELS = 3
	G.UIDROPDOWNMENU_SHOW_TIME = 2
	G.DropDownList1 = Mock.NewObject("Button", UIParent, "DropDownList1")
	for _, name in ipairs({ "UIDropDownMenu_CreateFrames", "UIDropDownMenu_OnUpdate", "UIDropDownMenu_Initialize",
		"UIDropDownMenu_AddButton", "UIDropDownMenu_AddSeparator", "UIDropDownMenu_AddSpace",
		"UIDropDownMenu_StartCounting", "ToggleDropDownMenu" }) do
		G[name] = noop
	end
	-- Blizzard_Menu: no menu is ever open.
	local manager = { IsAnyMenuOpen = function() return false end, CloseMenus = noop }
	G.Menu = { GetManager = function() return manager end }
	G.ChatFrameUtil ={ DisplayTimePlayed = noop }
	G.UnitGUID = function(unit) if unit == "player" then return "Player-1-00000001" end end
	G.GetPlayerInfoByGUID = function(guid)
		if guid == "Player-1-00000001" then return "Warrior", "WARRIOR", "Human", "Human", 2, "Player", "TestRealm" end
	end
	G.UnitClassBase = function() return "WARRIOR", 1 end
	G.UnitLevel = function() return 80 end
	G.C_CreatureInfo = {
		GetClassInfo = function(classID)
			if classID == 1 then return { className = "Warrior", classFile = "WARRIOR", classID = 1 } end
		end,
	}
	G.UnitXP = function() return 0 end
	G.UnitXPMax = function() return 1000 end
	G.GetAverageItemLevel = function() return 100, 100, 100 end
	G.GetBindLocation = function() return "Stormwind City" end
	G.RequestTimePlayed = noop
	G.C_PetBattles = { IsInBattle = function() return false end }
	G.GetMoney = function() return 0 end
	G.GetZoneText = function() return "Stormwind City" end
	G.GetSubZoneText = function() return "" end
	Mock.loggedIn = false
	G.IsLoggedIn = function() return Mock.loggedIn end
	G.date, G.time = os.date, os.time
	G.GetScreenWidth = function() return UIParent:GetWidth() end
	G.GetScreenHeight = function() return UIParent:GetHeight() end
	G.GetAddOnMetadata = C_AddOns.GetAddOnMetadata
	G.StaticPopupDialogs = {}
	G.DEFAULT_CHAT_FRAME = Mock.NewObject("ScrollingMessageFrame", UIParent, "DEFAULT_CHAT_FRAME")
end

local function InstallTitanXml()
	InstallClient(_G)
	local CreateFrame = _G.CreateFrame
	_G.CreateFrame = function(frameType, name, parent, template, ...)
		local titan, others = SplitTemplates(template)
		local frame = CreateFrame(frameType, name, parent, others, ...)
		if #titan == 0 then return frame end
		for _, part in ipairs(titan) do TEMPLATES[part](frame, name) end
		frame:RunScript("OnLoad")
		return frame
	end

	local topAnchor = CreateFrame("Button", "TitanPanelTopAnchor", UIParent)
	topAnchor:SetSize(1, 1)
	local bottomAnchor = CreateFrame("Button", "TitanPanelBottomAnchor", UIParent)
	bottomAnchor:SetSize(1, 1)
	local tooltip = CreateFrame("GameTooltip", "TitanPanelTooltip", UIParent)
	tooltip.__state.shown = false
	CreateFrame("Button", "TitanPanelBarButton", UIParent):SetFrameStrata("BACKGROUND")
end

Mock.Extend("Titan", {
	globals = {
		"Titan_G", "TitanPanelTopAnchor", "TitanPanelBottomAnchor", "TitanPanelTooltip", "TitanPanelBarButton",
		"LDBTitan", "TitanSettings", "TitanSkins", "TitanAll", "ServerTimeOffsets", "ServerHourFormat",
	},
	install = InstallTitanXml,
})

return Mock
