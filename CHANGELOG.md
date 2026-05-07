# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.2.0] — 2026-05-06

M1 — JSON-RPC framing.

Replaces the v0.1.0 stub `jsonrpc.cyr` with a real implementation
of the four functions cyim-lsp needs to talk to a server:

- **`jsonrpc_build_notification(method, params)`** — builds a
  framed `Content-Length: <N>\r\n\r\n{...}` cstring containing
  `{"jsonrpc":"2.0","method":"<method>","params":<params>}`.
  `params` is a pre-serialized JSON value (object, array, or
  null) — keeps the API surface tight.
- **`jsonrpc_build_request(id, method, params)`** — same as
  notification with an `"id":<id>` field for response correlation.
- **`jsonrpc_parse_frame(buf, len, off_out, len_out)`** — strips
  the Content-Length header, returns body offset + length.
  Tri-state return: `1` (valid), `0` (incomplete — caller
  accumulates more bytes), `-1` (malformed — caller drops).
- **`jsonrpc_next_id()`** — auto-incrementing i64 message-id
  allocator. Notifications don't consume an id; only requests do.

The envelope is hand-rolled rather than going through json
stdlib's `json_build` because the JSON-RPC envelope shape is
fixed (3 keys for notification, 4 for request) and embedding
pre-serialized `params` keeps callers in control of the params
shape. v0.3.0 (subprocess + initialize handshake) and beyond
will use json stdlib for the more complex incoming-message
parsing where dynamic key extraction matters.

### Added

- **Real `src/jsonrpc.cyr` implementation** (~200 lines, replaces
  the v0.1.0 stub). Hand-rolled envelope construction; bounded
  buffer alloc with explicit cap calculation; `_jr_append` /
  `_jr_itoa` / `_jr_frame` internal helpers (underscore-prefixed,
  not part of the public ABI).
- **`tests/jsonrpc.tcyr`** (180 lines, 21 assertions across 13
  groups). Coverage: monotonic id allocator, build → parse
  round-trip with body-bytes verification, request id-field
  inclusion, three rejection paths (wrong prefix / non-digit
  length / empty length), incomplete-buffer states (header-only,
  body-truncated, < 16 bytes), zero-length body, notification
  doesn't consume an id.
- **`fuzz/jsonrpc.fcyr`** (random byte feeder). 5000 random
  buffers (length 0–256) through `jsonrpc_parse_frame`; asserts
  return code is one of {1, 0, -1} and that `body_off + body_len
  <= len` on success. Catches OOB reads, integer-overflow on
  adversarial digit runs, and crashes on malformed Content-Length-
  shaped bytes. PASS at v0.2.0.

### Changed

- **`src/jsonrpc.cyr`** — promoted from v0.1.0 stub
  (`jsonrpc_version()` only) to full M1 surface. The placeholder
  comment block in v0.1.0 said "full encoding lands at v0.2.0";
  this is that release.

### Notes

- **Subprocess + protocol handshake (M2 / v0.3.0) is the next
  bite.** v0.2.0 is testable in isolation — round-trip via
  `tests/jsonrpc.tcyr` proves the framing without needing a
  real cyrius-lsp running.
- **No new stdlib deps.** `cyrius.cyml` declared `json` and
  `process` at v0.1.0; v0.2.0's hand-rolled approach uses
  neither yet. They come into play at M2+ (process spawn) and
  M5 (publishDiagnostics parsing).
- **Plugin ABI surface unchanged.** v0.2.0 is internal-only;
  cyim doesn't see a behaviour difference. The plugin-init
  callbacks remain no-op stubs until M3 (didOpen / didChange /
  didSave) wires real protocol behavior.

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
