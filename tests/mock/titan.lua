--[[
Titan Panel for wowmock: the client calls Titan's setup makes that the shared
mock leaves to InstallUI, and Titan's globals, cleared on every install so a
fresh client doesn't see the previous load's Titan.
]]
local Mock = require("wowmock")

Mock.Extend("Titan", {
	globals = {
		"Titan_G", "TitanPanelTopAnchor", "TitanPanelBottomAnchor", "TitanPanelTooltip", "TitanPanelBarButton",
		"LDBTitan", "TitanSettings", "TitanSkins", "TitanAll", "ServerTimeOffsets", "ServerHourFormat",
	},
	install = function()
		_G.UnitXP = function() return 0 end
		_G.UnitXPMax = function() return 1000 end
		_G.C_PetBattles = { IsInBattle = function() return false end }
	end,
})

return Mock
