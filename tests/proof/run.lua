local Setup = dofile("tests/proof/setup.lua")
local Runner = require("wowproof.runner")

local write = io.write
local function Print(line) write(line, "\n") end

local _, failed = Runner.Run({
	proof = Setup.Proof(),
	scenarios = dofile("tests/proof/scenarios.lua"),
	filters = arg,
	print = Print,
})
os.exit(failed == 0 and 0 or 1, true)
