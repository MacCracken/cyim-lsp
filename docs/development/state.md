# cyim-lsp — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**1.0.0** — Public API freeze shipped 2026-05-06. ADR 0001
formalises the surface (entry point, hooks, ex-commands,
struct layouts). cyim 1.4.0 picks up this contract.

**0.7.0** — M7 (closeout audit). 30-function dead-code floor
recorded; security re-scan clean.

**0.6.0** — M6 (navigation) shipped 2026-05-06. Ex-commands
`:lsp-goto-def` and `:lsp-find-refs`. Synchronous request/
response helper. Position conversions. v0.7.0 (closeout) +
v1.0.0 (API freeze) next.

**0.5.1** — M5 (inline diag highlighting) shipped 2026-05-06.
Per-diag tuples extracted via brace-depth + string-aware walker
over the publishDiagnostics body; `diagnostic_provider` hook
pushes them into cyim via `diag_new()`. Completes the
publishDiagnostics-to-render round-trip.

**0.5.0** — M4 (diagnostics counts). cyim 1.4.0 pickup target
shipped.

**0.4.0** — M3 (document sync).

**0.3.0** — M2 (subprocess lifecycle).

**0.2.0** — M1 (JSON-RPC framing).

**0.1.0** — scaffolded.

## Toolchain

- **Cyrius pin**: `5.9.16` (in `cyrius.cyml [package].cyrius`)
- **cyim ABI target**: 1.3.6 / [ADR 0004](https://github.com/MacCracken/cyim/blob/main/docs/adr/0004-plugin-abi-freeze.md)
  (frozen surface — stable across cyim 1.x)

## Source

- `src/jsonrpc.cyr` — JSON-RPC framing (v0.2.0). Public:
  `jsonrpc_version`, `jsonrpc_next_id`,
  `jsonrpc_build_notification`, `jsonrpc_build_request`,
  `jsonrpc_parse_frame`.
- **`src/subprocess.cyr`** — bidirectional-pipe primitives
  (v0.3.0). Public: `lsp_proc_spawn`, `lsp_proc_send`,
  `lsp_proc_recv`, `lsp_proc_close` (idempotent), `lsp_proc_kill`,
  `lsp_proc_pid`. 32 B handle struct; two pipe pairs for
  bidirectional traffic.
- **`src/lsp_client.cyr` — LSP protocol client (v0.3.0+)**.
  Public: `lsp_client_start(cmd_path)`,
  **`lsp_client_start_default()`** (v0.4.0: PATH lookup via
  `/usr/bin/env`), `lsp_client_stop`, `lsp_client_running`,
  `lsp_client_proc`, `lsp_client_describe`. Internal:
  `_lsp_initialize`, `_lsp_shutdown_handshake`,
  `_lsp_recv_frame` (8 KB cap), `_lsp_send_all`,
  `_lsp_client_start_with` (factored entry point).
- **`src/lsp_state.cyr` — per-buffer state (v0.4.0)**. Vec of
  32 B entries `{buf_ptr, version, opened, uri}`. Linear
  lookup. Public: `lsp_state_lookup` / `_create` /
  `_bump_version` / `_mark_opened` / `_is_opened` /
  `_version` / `_uri` / `_buf` / `_count`.
- **`src/lsp_documents.cyr` — document-sync handlers (v0.4.0)**.
  Public: `lsp_doc_did_change(s)`, `lsp_doc_did_save(s, path)`.
  Internal: JSON-string escape (`_lsp_jesc_byte`,
  `_lsp_buf_to_json_string`), URI helper (`_lsp_path_to_uri`),
  filter (`_lsp_path_is_cyr`), itoa, append, three message
  builders, lazy-start, didOpen sender. References cyim plugin
  ABI (`editor_buf`, `editor_file_path`, `buf_len`, `buf_get`)
  — only resolves at fold-in into cyim.
- **`src/lsp_diags.cyr` — per-URI diagnostic state (v0.5.0+)**.
  Public: `lsp_diags_handle_frame`, `lsp_diags_lookup`,
  `lsp_diags_count`, `lsp_diags_format_status`,
  **`lsp_diags_entry_count`**, **`lsp_diags_entry_tuple`**,
  **`lsp_diag_tuple_line/severity/msg`** (v0.5.1).
  Bytescan-based publishDiagnostics parser plus brace-depth +
  string-aware array walker. 48 B per-URI entry with severity
  counts + tuple-vec ptr (+40). 24 B per-diag tuple
  `{line, severity, msg}`. Two-pass JSON string parser handles
  short escapes; `\uXXXX` → `?` placeholder for v0.5.1.
- `src/plugin_init.cyr` — `cyim_lsp_init()` registers six no-op
  callbacks against cyim's plugin ABI; ex_commands
  `:lsp-restart` / `:lsp-status` registered. normal_key
  bindings (gd, gr) deferred to v0.6.0 pending plugin-prefix
  ABI in cyim.
- `src/main.cyr` — standalone driver (NOT in `[lib].modules`;
  for ad-hoc smoke / framing tests without cyim).
- `src/test.cyr` — `cyrius test` smoke (3 assertions).

## Build artifacts

- `build/cyim-lsp` — standalone driver binary
- `dist/cyim-lsp.cyr` — bundled distfile (178 lines), produced
  by `cyrius distlib`. cyim consumes via `include "lib/cyim-lsp.cyr"`
  after `cyrius deps` resolves the `[plugins.cyim-lsp]` entry.

## Tests

- `src/test.cyr` (`[build].test`) — 3 assertions, all PASS
- `tests/cyim-lsp.tcyr` — scaffold smoke (2 assertions, PASS)
- `tests/jsonrpc.tcyr` — 21 assertions, framing round-trip +
  edge cases (v0.2.0)
- `tests/subprocess.tcyr` — 15 assertions, /bin/cat mock
  round-trip (v0.3.0)
- `tests/lsp_documents.tcyr` — 39 assertions, doc-sync helpers
  (v0.4.0)
- **`tests/lsp_diags.tcyr` — 43 assertions across 16 groups,
  all PASS (v0.5.1; was 28 at v0.5.0).** v0.5.0 coverage plus
  v0.5.1 additions: tuple extraction with nested ranges, JSON
  escape decoding in messages (\\n → LF), brace-in-string
  corner case (string-aware splitter), empty array yields
  zero tuples, replace semantics for tuple list.
- `fuzz/jsonrpc.fcyr` — random byte feeder; 5000 buffers PASS
  (v0.2.0)
- `tests/cyim-lsp.bcyr` — benchmark stub (no-op)
- `tests/cyim-lsp.fcyr` — fuzz stub (legacy)
- **Real-server handshake (manual, not CI):** spawned
  `/home/macro/.cyrius/bin/cyrius-lsp` from a one-off harness;
  observed `[cyrius-lsp] initialized` then `[cyrius-lsp]
  shutdown` cleanly. v0.4.0+ adds a guarded CI integration test.

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — `syscalls`, `alloc`, `fmt`, `io`, `string`, `str`,
  `vec`, `assert`, `json`, `process`

The `json` + `process` modules are pulled in for the v0.2.0+ work
(JSON-RPC payload encoding/decoding, subprocess spawn) but aren't
exercised by the v0.1.0 stubs.

## Consumers

| Consumer | Status |
|---|---|
| cyim 1.4.0 | **planned** — picks up cyim-lsp v0.5.0 (diagnostics) |
| cyim 1.3.x | not yet (closeout pass first at 1.3.7) |

## Next

**v0.5.0 was the cyim 1.4.0 pickup target.** v0.5.1 is the
recommended cyim 1.4.x pickup — adds inline per-line diag
highlighting on top of v0.5.0's status-segment counts.

After cyim 1.4.x ships with v0.5.1, M6 (**v0.6.0 — navigation
via `gd` / `gr`**) is the next session-scoped chunk. Needs
cyim-side normal_key dispatch wiring (the plugin ABI surface
is in place; the `g` prefix-keymap from cyim's NORMAL mode
needs to route through plugin_lookup_normal_key — v1.3.5
shipped the lookup but didn't wire `g`-prefix paths to it).
