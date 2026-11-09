-- Shared helpers for specs: a fresh mocked client with Socialite loaded.
local Mock = require("mock.socialite")
local Loader = require("wowmock.loader")

local Helpers = { Mock = Mock, Loader = Loader }

-- Every file the TOC loads, in order, after expanding XML includes.
function Helpers.TocFiles(tocPath)
	local out = {}
	local function Collect(path)
		if path:match("%.xml$") then
			local dir = path:match("^(.*)/[^/]+$")
			local xml = assert(io.open(path)):read("*a"):gsub("<!%-%-.-%-%->", "")
			for file in xml:gmatch('<%a+%s+file%s*=%s*["\']([^"\']+)["\']') do
				Collect(dir .. "/" .. file:gsub("\\", "/"))
			end
		else
			out[#out + 1] = path
		end
	end
	for _, file in ipairs(Loader.TocFiles(tocPath)) do Collect(file) end
	return out
end

-- Globals the fresh client has; anything else was made by loaded addons.
local clientGlobals

-- A fresh mock client without the previous load's addon globals: addons like
-- Titan reuse named frames they find (_G.TitanPanelBackground_Bar), which
-- would otherwise be the previous client's dead objects.
function Helpers.Install()
	if clientGlobals then
		for key in pairs(_G) do
			if not clientGlobals[key] then _G[key] = nil end
		end
	end
	Mock.Install()
	clientGlobals = {}
	for key in pairs(_G) do clientGlobals[key] = true end
end

-- Fresh mock client + freshly loaded Socialite. Fires ADDON_LOADED unless
-- options.loaded == false. options.saved seeds SocialiteSettings.
function Helpers.LoadAddon(options)
	options = options or {}
	Helpers.Install()
	_G.SocialiteSettings = options.saved
	local ns = Loader.LoadToc("./Socialite.toc", "Socialite")
	if options.loaded ~= false then
		Mock.FireEvent("ADDON_LOADED", "Socialite")
	end
	return ns
end

-- Fresh mock client with Titan Panel loaded first and Socialite after it,
-- then the login events that make Titan build its bars and LDB buttons.
-- Socialite goes on Titan's top bar the way the player adds it from Titan's
-- menu; returns the addon namespace and its Titan button.
function Helpers.LoadWithTitan(options)
	options = options or {}
	require("mock.titan")
	Helpers.Install()
	_G.SocialiteSettings = options.saved
	Loader.LoadAddon("Titan")
	local ns = Loader.LoadToc("./Socialite.toc", "Socialite")
	Mock.FireEvent("ADDON_LOADED", "Titan")
	Mock.FireEvent("ADDON_LOADED", "Socialite")
	Mock.FireEvent("PLAYER_LOGIN")
	Mock.FireEvent("PLAYER_ENTERING_WORLD", true, false)
	Mock.RunTimers()
	Titan_G.plugins.AddOnBar("Bar", "Socialite")
	return ns, _G[TitanUtils_ButtonName("Socialite")]
end

-- Whether object belongs to the current mock client (not a previous load's).
function Helpers.IsLive(object)
	for _, live in ipairs(Mock.objects) do
		if live == object then return true end
	end
	return false
end

-- The text a Titan button shows.
function Helpers.TitanText(button)
	return _G[button:GetName() .. "Text"]:GetText()
end

-- Socialite's tooltip frame when it is anchored to frame.
function Helpers.TooltipAnchoredTo(frame)
	for _, object in ipairs(Mock.objects) do
		local point = object.__type == "ScrollFrame" and object.__state.points[1]
		if point and point[2] == frame then return object end
	end
end

-- Opens the data broker tooltip the way hovering the data text does.
function Helpers.OpenTooltip(ns)
	ns.dataobj.OnEnter(UIParent)
end

local function LineText(line)
	local parts = {}
	for _, cell in ipairs(line.cells) do
		if cell then parts[#parts + 1] = cell.fontString:GetText() or "" end
	end
	return table.concat(parts, " ")
end

-- The shown tooltip line whose cells contain text (plain match).
function Helpers.TooltipLine(text)
	for _, widget in ipairs(Mock.objects) do
		if rawget(widget, "cells") and widget:IsShown() and LineText(widget):find(text, 1, true) then
			return widget
		end
	end
	error("no tooltip line contains " .. text, 2)
end

-- Clicks the tooltip line containing text, with the given modifiers held.
function Helpers.ClickLine(text, button, modifiers)
	local line = Helpers.TooltipLine(text)
	Mock.SetModifiers(modifiers or {})
	line:RunScript("OnMouseDown", button or "LeftButton")
	Mock.SetModifiers({})
end

return Helpers
