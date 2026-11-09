return {
	specs = { "tests/spec/" },
	path = { "./tests/?.lua" },
	syntax = {
		include = { "." },
		exclude = { "./tests/*", "./.*" },
	},
}
