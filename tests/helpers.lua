-- Shared helpers for specs: a fresh mocked client with Socialite loaded.
local Mock = dofile("tests/mock/wow.lua")

local Helpers = { Mock = Mock }

-- Files are read and compiled once per run. Calling a compiled chunk again
-- runs its main body afresh (new locals and closures), like a fresh load.
local chunks, includes, tocs = {}, {}, {}

local function Compile(path)
	local chunk = chunks[path]
	if not chunk then
		chunk = assert(loadfile(path))
		chunks[path] = chunk
	end
	return chunk
end

local function Directory(path)
	return path:match("^(.*)/[^/]+$") or "."
end

-- Only <Script file="..."/> and <Include file="..."/> are followed; XML
-- comments (including the packager's @no-lib-strip@ markers) are skipped.
local function XmlIncludes(path)
	local files = includes[path]
	if not files then
		local dir = Directory(path)
		local xml = assert(io.open(path)):read("*a"):gsub("<!%-%-.-%-%->", "")
		files = {}
		for file in xml:gmatch('<%a+%s+file%s*=%s*["\']([^"\']+)["\']') do
			files[#files + 1] = dir .. "/" .. file:gsub("\\", "/")
		end
		includes[path] = files
	end
	return files
end

local function TocFiles(tocPath)
	local files = tocs[tocPath]
	if not files then
		local dir = Directory(tocPath)
		files = {}
		for line in io.lines(tocPath) do
			line = line:gsub("\r", ""):gsub("^%s+", ""):gsub("%s+$", "")
			if line ~= "" and not line:match("^#") then
				files[#files + 1] = dir .. "/" .. line:gsub("\\", "/")
			end
		end
		tocs[tocPath] = files
	end
	return files
end

local function LoadFile(path, addonName, ns)
	if path:match("%.xml$") then
		for _, file in ipairs(XmlIncludes(path)) do
			LoadFile(file, addonName, ns)
		end
	elseif path:match("%.lua$") then
		Compile(path)(addonName, ns)
	else
		error("tests can't load " .. path)
	end
end

-- Every file the TOC loads, in order, after expanding XML includes.
function Helpers.TocFiles(tocPath)
	local out = {}
	local function Collect(path)
		if path:match("%.xml$") then
			for _, file in ipairs(XmlIncludes(path)) do Collect(file) end
		else
			out[#out + 1] = path
		end
	end
	for _, file in ipairs(TocFiles(tocPath)) do Collect(file) end
	return out
end

-- Loads every file listed in a TOC, passing (addonName, ns) as the chunk
-- varargs exactly like the client does.
function Helpers.LoadToc(tocPath, addonName, ns)
	ns = ns or {}
	for _, file in ipairs(TocFiles(tocPath)) do
		LoadFile(file, addonName, ns)
	end
	return ns
end

-- Fresh mock client + freshly loaded Socialite. Fires ADDON_LOADED unless
-- options.loaded == false. options.saved seeds SocialiteSettings.
function Helpers.LoadAddon(options)
	options = options or {}
	Mock.Install()
	_G.SocialiteSettings = options.saved
	local ns = Helpers.LoadToc("./Socialite.toc", "Socialite")
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
	for _, widget in ipairs(Mock.widgets) do
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
	Mock.RunScript(line, "OnMouseDown", button or "LeftButton")
	Mock.SetModifiers({})
end

return Helpers
