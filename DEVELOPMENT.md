# Development

## Tests

Specs run offline on the shared [wow-ui-testing](https://github.com/voshond/wow-ui-testing) library: its
`wowtest` runner and `wowmock` client mock. Nothing to install beyond LuaJIT (or Lua 5.1), curl and unzip.

```sh
sudo pacman -S luajit            # Arch; Debian/Ubuntu: sudo apt-get install luajit
bash scripts/run-tests.sh        # fetch the lib, syntax-check every addon Lua file, then run every spec
bash scripts/run-tests.sh smoke  # only spec paths containing "smoke"
bash scripts/run-tests.sh -t "Shift"     # only tests whose full name contains the text
bash scripts/run-tests.sh --tag invite   # only tests tagged #invite in a describe/it name
bash scripts/run-tests.sh -j --times     # spec files in parallel, with timings
```

A run fails on any failing test, any syntax error, or when the filters select no tests.
CI (`.github/workflows/tests.yml`) runs the same script on every pull request.

The library is pinned by commit in `.wut-version`. `scripts/fetch-wut.sh` (run by `run-tests.sh`) downloads that
commit into the gitignored `.wut/` and does nothing when it is already there. While working on the library,
`WUT_DIR=../wow-ui-testing bash scripts/run-tests.sh` uses that checkout instead. To bump it, put the new full
commit SHA (and its tag as a comment) in `.wut-version`. The download uses `GITHUB_TOKEN`, `GH_TOKEN` or a
logged-in `gh` when there is one.

Tests also load Titan Panel, the way most players run Socialite: as a Titan button fed by its LDB data
object. Titan only ships as release zips, so `tests/wut.config.lua` pins one under `releases` by its
WoWInterface archive URL and sha256. `fetch-wut.sh` checks the download against it and unpacks it into
`.wut/addons/Titan/`. It is never committed or packaged. To bump it, take the new version's `aid=` archive link
from the WoWInterface page, then update `url` and `sha256` (`curl -sL <url> | sha256sum`).
`Helpers.LoadWithTitan()` loads Titan, then Socialite, fires the login events and adds Socialite to Titan's top
bar. It returns the namespace and the Titan button.

Layout:

- `tests/wut.config.lua`: the runner config: spec dir, `package.path`, and the syntax check over every Lua file
  outside `tests/` and dot folders (`vendor/` included).
- `tests/mock/socialite.lua`: Socialite's extension of `wowmock` (`Mock.Extend`): guild, friend and Battle.net
  APIs seeded with `Mock.SetGuild/SetFriends/SetBattleNet`, `Mock.SetModifiers({ shift = true })`, and chat and
  group actions recorded for `Mock.Calls("C_PartyInfo.InviteUnit")`. Client chat lands in `Mock.messages`.
- `tests/mock/titan.lua`: the frames and templates from Titan's XML (wowmock only runs the Lua in XML files),
  plus the client globals Titan reads.
- `tests/helpers.lua`: `Helpers.LoadAddon()` loads `Socialite.toc` (expanding `embeds.xml` and the vendored
  libs) into a fresh mock and fires `ADDON_LOADED`; `Helpers.ClickLine` clicks a tooltip line.
- `tests/spec/*_spec.lua`: the specs.

Add a global to `tests/mock/socialite.lua` only when Socialite or a vendored lib needs it; pieces every addon
needs belong in the library.

## UI proof

```sh
bash scripts/proof.sh            # render every scenario to .proof/, plus .proof/index.html
bash scripts/proof.sh collapsed  # only scenarios whose name contains "collapsed"
```

Each scenario loads Titan Panel and Socialite like the specs do, seeds guild, friend and Battle.net data, and hovers
the Socialite button on Titan's top bar. It then renders the bar and the open tooltip with the library's `wowproof`
to `.proof/<scenario>.svg` and `.png`. The scenarios are a full tooltip, a collapsed guild header (it must have no
member rows) and the empty state. They live in `tests/proof/scenarios.lua`. A scenario fails if the tooltip didn't
open, its checks fail, or the client printed anything.

It needs LuaJIT, `rsvg-convert` (librsvg) for PNGs, ImageMagick for Titan's `.tga` art, and `curl` and `jq` for
Blizzard art. Blizzard art comes through the library's pinned sources (Gethe/wow-ui-textures and wago.tools for the
client build) and is cached in the gitignored `.proof-art/`. The client atlases the mock uses (the Forever tooltip
nine-slice) are pinned in `tests/proof/atlases.lua`. Regenerate it after the mock starts using a new atlas or a `.wut-version` bump changes the build (the nine-slice names come from the library's `wowmock/templates.lua`):

```sh
python3 -B .wut/scripts/atlas_catalog.py --fetch --scan 'tests/mock/*.lua' '.wut/wowmock/templates.lua' \
	--output tests/proof/atlases.lua
```

CI renders the proof on every pull request and uploads `.proof/` as the `ui-proof` artifact.

## Installing into the game

```sh
scripts/install.sh               # copy the addon into the Forever client's Interface/AddOns/Socialite
scripts/install.sh --link        # symlink AddOns/Socialite to this checkout instead
scripts/install.sh --uninstall   # remove it (SavedVariables in WTF/ are kept)
WOW_DIR=/path/to/_retail_ scripts/install.sh   # another client
```

Copy mode only ships addon files (TOC, Lua, XML, `i18n/`, `vendor/`, icon, licence); `tests/`, `scripts/`
and git metadata stay out. In game: `/reload`, or restart the client after adding files to the TOC.
