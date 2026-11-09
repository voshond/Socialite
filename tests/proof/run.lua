local Setup = dofile("tests/proof/setup.lua")
local Runner = require("wowproof.runner")

local write = io.write
local function Print(line) write(line, "\n") end

local scenarios = dofile("tests/proof/scenarios.lua")
for _, scenario in ipairs(scenarios) do
	local build = scenario.build
	scenario.build = function()
		local region = build()
		Setup.CheckTitanSkin()
		return region
	end
end

local _, failed = Runner.Run({
	proof = Setup.Proof(),
	scenarios = scenarios,
	filters = arg,
	print = Print,
})
os.exit(failed == 0 and 0 or 1, true)
