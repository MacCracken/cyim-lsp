# cyim-lsp — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**0.3.0** — M2 (subprocess lifecycle) shipped 2026-05-06. Spawn
+ initialize handshake + clean shutdown verified against real
`cyrius-lsp`. M3 (document sync) is the next bite.

**0.2.0** — M1 (JSON-RPC framing) shipped 2026-05-06. Round-trip
tested + fuzzed.

**0.1.0** — scaffolded 2026-05-06 via `cyrius init`.

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
- **`src/lsp_client.cyr` — LSP protocol client (real, v0.3.0)**.
  Public: `lsp_client_start(cmd_path)` (spawn + initialize +
  initialized), `lsp_client_stop` (shutdown + exit + reap),
  `lsp_client_running` (pid > 0 if attached), `lsp_client_proc`,
  `lsp_client_describe` (renders "cyrius-lsp pid=<n>" or "(not
  attached)"). Internal: `_lsp_initialize`,
  `_lsp_shutdown_handshake`, `_lsp_recv_frame` (8 KB cap),
  `_lsp_send_all` (handles short writes).
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
- **`tests/subprocess.tcyr` — 15 assertions across 8 groups,
  all PASS (v0.3.0).** Coverage: spawn handle non-null, pid > 0,
  send/recv round-trip via `/bin/cat` mock, multi-write
  multi-read, close reaps + marks pid -1, idempotent close,
  send/recv on closed -> -1, EOF on exec-failure.
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

M3 (v0.4.0 — document sync) is the next session-scoped chunk per
[`roadmap.md`](roadmap.md). Wire the plugin hooks: `post_save` →
`textDocument/didSave`, `post_change` → `textDocument/didChange`,
plus per-buffer URI / version state, `:lsp-restart` and
`:lsp-status` ex-command behavior.
