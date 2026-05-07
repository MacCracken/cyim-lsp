# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.1.0] — 2026-05-06

Initial scaffold release. Establishes the plugin's structure +
dist concatenation order so cyim 1.4.0 can land
`[plugins.cyim-lsp]` cleanly. All hook callbacks are no-op stubs
at this version; the real LSP behaviour (subprocess spawn,
JSON-RPC protocol roundtrip, diagnostic collection, definition /
references) lands at v0.2.0+.

Pinned against cyim's plugin ABI as frozen in cyim ADR 0004
(cyim 1.3.6).

### Added

- **`cyrius init cyim-lsp` scaffold.** Standard layout: `src/`,
  `tests/`, `docs/{adr,architecture,development,examples,guides}`,
  `lib/` (vendored stdlib), `build/`. Cyrius pin: 5.9.16.
- **`src/jsonrpc.cyr`** — placeholder for JSON-RPC 2.0 framing
  (Content-Length headers, message build/parse). v0.1.0 ships
  only `jsonrpc_version()` returning `"2.0"`; full encoding
  lands at v0.2.0.
- **`src/lsp_client.cyr`** — placeholder for LSP protocol
  handlers (initialize, didSave, didChange, publishDiagnostics).
  v0.1.0 ships only stubs (`lsp_client_running()`,
  `lsp_client_describe()`).
- **`src/plugin_init.cyr`** — `cyim_lsp_init()` registers no-op
  callbacks for cyim's six plugin hook types (post_save,
  post_change, status_segment, diagnostic_provider, ex_command
  for `:lsp-restart` / `:lsp-status`). normal_key bindings (gd,
  gr) are deferred to v0.2.0 pending cyim's plugin-prefix-keymap
  ABI.
- **`src/main.cyr`** — standalone CLI driver for ad-hoc smoke
  + JSON-RPC framing tests without needing cyim. Not bundled
  into the distfile.
- **`src/test.cyr`** — `cyrius test`-runnable smoke (3 assertions
  across 3 groups); covers `jsonrpc_version`, `lsp_client_running`,
  `lsp_client_describe`.
- **`cyrius.cyml`** with `[lib]` section pointing at the three
  plugin-side modules in dependency order: jsonrpc.cyr →
  lsp_client.cyr → plugin_init.cyr. `cyrius distlib` produces
  `dist/cyim-lsp.cyr` (164 lines) from this list.

### Notes

- **ABI surface targeted**: cyim 1.3.6 / ADR 0004's frozen
  surface. All six hook registration functions, callback
  signatures, and the 24 B diag record layout are stable across
  cyim 1.x.
- **No external repo deps**. The plugin consumes only cyrius
  stdlib (json, process, etc.) and cyim's plugin ABI at
  fold-in time.
- **First plugin in the sandhi pattern.** Follows the same
  shape vyakarana (cyim M2) and niyama (cyim 1.3.0) established;
  becomes the worked example for future cyim plugins.
