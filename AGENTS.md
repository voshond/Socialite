# Repository guidance

## Scope

- **Socialite** is an LDB data broker showing guild members, character friends and Battle.net friends in a
  tooltip. The addon lives at the repository root (`Socialite.toc`); one TOC serves Retail, Mists and Forever
  (`## Interface: 120100, 50504, 16001`). Write Lua 5.1-compatible code.
- Load order is the TOC: `embeds.xml` (vendored libs), `i18n/enUS.lua` (the only active locale), `tooltip.lua`,
  `functions.lua`, `Socialite.lua`, `config.lua`. Every file receives `local addonName, addon = ...`.
- `vendor/` holds pinned copies of LibStub, CallbackHandler, Ace3 (GUI, Config, Console), LibDataBroker and
  LibDBIcon. They are not normal edit targets.
- Never invent WoW API signatures; check Blizzard's UI source or the client.

## Code map

- `tooltip.lua`: the custom scrollable tooltip (`addon.tooltip`: `Clear`, `AddLine`, `AddColspanLine`,
  `SetLineScript`, `SmartAnchorTo`, ...).
- `functions.lua`: roster parsing and rendering (`addon:renderGuild`, `renderFriends`, `renderBattleNet`) and the
  line click handlers (whisper, invite, context menus).
- `Socialite.lua`: saved-variable defaults on `ADDON_LOADED` (`addon.db` = `SocialiteSettings`), the LDB data
  object, data text and `addon:updateTooltip`.
- `config.lua`: AceConfig options and `/socialite`.

## Tests and install

- Run `bash scripts/run-tests.sh` before handing work back; it syntax-checks every Lua file and runs
  `tests/spec/*_spec.lua` under LuaJIT (Lua 5.1 fallback). Filters: a path fragment, `-t "name text"`,
  `--tag tag`. See `DEVELOPMENT.md`.
- Behaviour changes come with specs. Use `tests/helpers.lua` (`Helpers.LoadAddon()`) and the mock's seeding and
  call recording rather than ad-hoc globals; extend `tests/mock/wow.lua` minimally when code needs a new API.
- `scripts/install.sh` copies (or `--link`s) the addon into the Forever client; override the client with
  `WOW_DIR`. Don't install into the game unless asked.
- Releases are built by the BigWigs packager (`.github/workflows/deploy-packager.yml`, `.pkgmeta`); keep
  dev-only folders in `.pkgmeta`'s ignore list.
