# cyim-lsp — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**0.5.0** — M4 (diagnostics) shipped 2026-05-06. **cyim 1.4.0
pickup target.** Server-pushed `publishDiagnostics` →
per-URI severity counts → cyim status segment "E:N W:M I:K
H:L". Inline diag highlighting (diagnostic_provider hook) is
v0.5.1.

**0.4.0** — M3 (document sync): didOpen / didChange / didSave.

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
- **`src/lsp_diags.cyr` — per-URI diagnostic state (v0.5.0)**.
  Public: `lsp_diags_handle_frame`, `lsp_diags_lookup`,
  `lsp_diags_count`, `lsp_diags_format_status`. Bytescan-based
  publishDiagnostics parser; 48 B per-URI entry with severity
  counts. No json stdlib dependency in hot path.
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
- **`tests/lsp_diags.tcyr` — 28 assertions across 11 groups,
  all PASS (v0.5.0).** Coverage: bytescan severity counts,
  URI extract success / failure, frame dispatch for
  publishDiagnostics + ignore for other methods, state
  REPLACES on subsequent publishDiagnostics, multi-URI
  independence, status_segment format (omits zero categories,
  full E+W+I+H rendering).
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

**v0.5.0 is the cyim 1.4.0 pickup target.** From cyim's side:
`[plugins.cyim-lsp]` block in `cyrius.cyml` + `include
"lib/cyim-lsp.cyr"` in `src/main.cyr` + `cyim_lsp_init()` call
in `main()` after `plugin_init()`. Two-line change picks up
auto-spawn + status-segment diag counts.

After cyim 1.4.0 ships, cyim-lsp's M5 (v0.5.1 — inline diag
highlighting via `diagnostic_provider` hook) is the next
chunk — needs per-line extraction from the publishDiagnostics
body. Then v0.6.0 (definition / references via `gd` / `gr`).
