--[[
Titan Panel for wowmock: Titan's globals, cleared on every install so a fresh
client doesn't see the previous load's Titan.
]]
local Mock = require("wowmock")

Mock.Extend("Titan", {
	globals = {
		"Titan_G", "TitanPanelTopAnchor", "TitanPanelBottomAnchor", "TitanPanelTooltip", "TitanPanelBarButton",
		"LDBTitan", "TitanSettings", "TitanSkins", "TitanAll", "ServerTimeOffsets", "ServerHourFormat",
	},
})

return Mock
