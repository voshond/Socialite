-- Shared helpers for specs: a fresh mocked client with Socialite loaded.
local Mock = require("mock.socialite")
local Loader = require("wowmock.loader")

local Helpers = { Mock = Mock, Loader = Loader }

-- AceConfig-3.0.xml lists AceConfigDropdown inside an XML comment.
Loader.Skip({ "AceConfigDropdown-3.0" })

-- Every file the TOC loads, in order, after expanding XML includes.
function Helpers.TocFiles(tocPath)
	local out = {}
	local function Collect(path)
		if path:find("AceConfigDropdown-3.0", 1, true) then return end
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

-- Fresh mock client + freshly loaded Socialite. Fires ADDON_LOADED unless
-- options.loaded == false. options.saved seeds SocialiteSettings.
function Helpers.LoadAddon(options)
	options = options or {}
	Mock.Install()
	_G.SocialiteSettings = options.saved
	local ns = Loader.LoadToc("./Socialite.toc", "Socialite")
	if options.loaded ~= false then
		Mock.FireEvent("ADDON_LOADED", "Socialite")
	end
	return ns
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
