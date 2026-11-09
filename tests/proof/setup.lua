package.path = "./tests/?.lua;" .. package.path

local Helpers = require("helpers")
local Proof = require("wowproof")
local MockState = require("wowproof.adapters.mock_state")
local Raster = require("wowproof.raster")
local BlizzardArt = require("wowproof.sources.wow_ui_textures")
local ClientFiles = require("wowproof.sources.wago_casc")
local AtlasTable = require("wowproof.sources.atlas_table")

local Mock = Helpers.Mock

local ADDON_PREFIX = "interface\\addons\\"
local TEXTURE_EXTENSIONS = { "", ".tga", ".png", ".blp" }
-- Where each addon's Interface\AddOns\<Name>\ files live in this checkout.
local ADDON_DIRS = { socialite = ".", titan = Helpers.Loader.addonsDir .. "/Titan/Titan" }
-- Gethe/wow-ui-textures, from the lib's clientdata/forever.json.
local ART_REF = "d23deaf8f44a7d280dc974a5c9d5321c013db59b"
-- The client atlases Socialite's mock uses, from the lib's atlas catalog:
--   python3 -B .wut/scripts/atlas_catalog.py --fetch --scan 'tests/mock/*.lua' --output tests/proof/atlases.lua
local ATLASES = dofile("tests/proof/atlases.lua")
-- A screen as wide as the client's, cut to the top band Titan's bar and the
-- tooltip below it need.
local SCREEN = { width = 1920, height = 360 }
local ART_DIR = os.getenv("SOCIALITE_PROOF_ART") or ".proof-art"
local ART_FETCH = os.getenv("SOCIALITE_PROOF_ART_FETCH") ~= "0"

local Setup = {}

local blizzardArt = BlizzardArt({
	ref = ART_REF,
	dir = ART_DIR,
	fetch = ART_FETCH,
	token = os.getenv("GITHUB_TOKEN") or os.getenv("GH_TOKEN"),
})
local clientFiles = ClientFiles({ build = ATLASES.build, dir = ART_DIR, fetch = ART_FETCH })

-- C_Texture.GetAtlasInfo answers like the client for the pinned atlases.
Mock.Extend("SocialiteProof", {
	install = function()
		UIParent:SetSize(SCREEN.width, SCREEN.height)
		for name, atlas in pairs(ATLASES.atlases) do
			Mock.atlasInfo[name] = { width = atlas.width, height = atlas.height,
				uv = { atlas.left, atlas.right, atlas.top, atlas.bottom } }
		end
	end,
})

-- Socialite's and Titan's own textures, by their Interface\AddOns path.
function Setup.AddonTexture(path)
	if type(path) ~= "string" or path:lower():sub(1, #ADDON_PREFIX) ~= ADDON_PREFIX then return nil end
	local addon, rest = path:sub(#ADDON_PREFIX + 1):match("^([^\\/]+)[\\/](.+)$")
	local dir = addon and ADDON_DIRS[addon:lower()]
	if not dir then return nil end
	local file = dir .. "/" .. rest:gsub("\\", "/")
	for _, extension in ipairs(TEXTURE_EXTENSIONS) do
		local candidate = file .. extension
		if Raster.Exists(candidate) and candidate:lower():match("%.[tpb][gnl][agp]$") then return candidate end
	end
	return nil
end

function Setup.Texture(path)
	return Setup.AddonTexture(path) or blizzardArt(path) or clientFiles(path)
end

function Setup.Adapter()
	return MockState({
		isSecret = Mock.IsSecret,
		reveal = function(value) return value.secretValue end,
		objects = function() return Mock.objects end,
		globals = _G,
	})
end

-- Every scenario must paint Titan's bar skin: a live background texture of
-- the top bar that resolves to Titan's own .tga.
function Setup.CheckTitanSkin()
	local background = _G.TitanPanelBackground_Bar
	assert(background and Helpers.IsLive(background), "Titan's top bar has no live background texture")
	assert(background:IsVisible(), "Titan's top bar background is hidden")
	local file = Setup.Texture(background:GetTexture())
	assert(file and file:match("%.tga$"), "Titan's bar skin " .. tostring(background:GetTexture()) .. " resolves to " .. tostring(file))
end

function Setup.Proof(options)
	options = options or {}
	return Proof.New({
		adapter = Setup.Adapter(),
		outDir = options.outDir or os.getenv("SOCIALITE_PROOF_DIR") or ".proof",
		title = "Socialite UI proof",
		screen = SCREEN,
		assets = { textures = Setup.Texture, atlases = AtlasTable(ATLASES.atlases) },
	})
end

return Setup
