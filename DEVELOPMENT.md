# Development

## Tests

Specs run offline against a small WoW client mock; nothing to install beyond LuaJIT (or Lua 5.1).

```sh
sudo pacman -S luajit            # Arch; Debian/Ubuntu: sudo apt-get install luajit
bash scripts/run-tests.sh        # syntax-check every addon Lua file, then run every spec
bash scripts/run-tests.sh smoke  # only spec paths containing "smoke"
bash scripts/run-tests.sh -t "Shift"     # only tests whose full name contains the text
bash scripts/run-tests.sh --tag invite   # only tests tagged #invite in a describe/it name
bash scripts/run-tests.sh -j --times     # spec files in parallel, with timings
```

A run fails on any failing test, any syntax error, or when the filters select no tests.
CI (`.github/workflows/tests.yml`) runs the same script on every pull request.

Layout:

- `tests/run.lua`: busted-style runner (`describe`, `it`, `before_each`, `after_each`, `assert.*`).
- `tests/mock/wow.lua`: the client mock. `Mock.Install()` resets it; `Mock.FireEvent`, `Mock.RunScript`,
  `Mock.SetModifiers({ shift = true })`, `Mock.SetGuild/SetFriends/SetBattleNet` seed state, and
  `Mock.Calls("C_PartyInfo.InviteUnit")` returns what recorded APIs were called with.
- `tests/helpers.lua`: `Helpers.LoadAddon()` loads `Socialite.toc` (expanding `embeds.xml` and the vendored
  libs) into a fresh mock and fires `ADDON_LOADED`.
- `tests/spec/*_spec.lua`: the specs.

Add a global to the mock only when Socialite or a vendored lib needs it.

## Installing into the game

```sh
scripts/install.sh               # copy the addon into the Forever client's Interface/AddOns/Socialite
scripts/install.sh --link        # symlink AddOns/Socialite to this checkout instead
scripts/install.sh --uninstall   # remove it (SavedVariables in WTF/ are kept)
WOW_DIR=/path/to/_retail_ scripts/install.sh   # another client
```

Copy mode only ships addon files (TOC, Lua, XML, `i18n/`, `vendor/`, icon, licence); `tests/`, `scripts/`
and git metadata stay out. In game: `/reload`, or restart the client after adding files to the TOC.
