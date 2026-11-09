return {
	specs = { "tests/spec/" },
	path = { "./tests/?.lua" },
	-- Titan Panel 9.3.4 (Interface 16001), the WoWInterface archive build.
	-- It ships only as release zips, so it is pinned by URL and sha256.
	releases = {
		{
			name = "Titan",
			url = "https://cdn.wowinterface.com/downloads/getfile.php?id=8092&aid=172859",
			sha256 = "1412e4fa931773365721a665bd94211fd61b406ad0f543e5885b82a1e1b1f35e",
			toc = "Titan/Titan.toc",
		},
	},
	syntax = {
		include = { "." },
		exclude = { "./tests/*", "./.*" },
	},
}
