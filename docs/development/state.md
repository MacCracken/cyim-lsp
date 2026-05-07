# cyim-lsp — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**0.2.0** — M1 (JSON-RPC framing) shipped 2026-05-06. Round-trip
tested + fuzzed; subprocess wiring (M2) is the next bite.

**0.1.0** — scaffolded 2026-05-06 via `cyrius init`; customised
for sandhi-pattern plugin distfile.

## Toolchain

- **Cyrius pin**: `5.9.16` (in `cyrius.cyml [package].cyrius`)
- **cyim ABI target**: 1.3.6 / [ADR 0004](https://github.com/MacCracken/cyim/blob/main/docs/adr/0004-plugin-abi-freeze.md)
  (frozen surface — stable across cyim 1.x)

## Source

- `src/jsonrpc.cyr` — **JSON-RPC framing (real, v0.2.0)**.
  Public: `jsonrpc_version`, `jsonrpc_next_id`,
  `jsonrpc_build_notification`, `jsonrpc_build_request`,
  `jsonrpc_parse_frame`. Internal: `_jr_append`, `_jr_itoa`,
  `_jr_frame`. Hand-rolled envelope construction; pre-serialized
  params; tri-state parser return.
- `src/lsp_client.cyr` — LSP protocol handlers (stub:
  `lsp_client_running()`, `lsp_client_describe()`)
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
- **`tests/jsonrpc.tcyr` — 21 assertions across 13 groups, all
  PASS.** Coverage: monotonic id allocator, build → parse
  round-trip with body-bytes verification, request id-field
  inclusion, three rejection paths, incomplete-buffer states,
  zero-length body, notification doesn't consume id.
- **`fuzz/jsonrpc.fcyr` — random byte feeder. 5000 buffers
  (length 0–256) through `jsonrpc_parse_frame`. PASS at v0.2.0.
  `cyrius fuzz` finds it in `fuzz/` (cyrius's default location).**
- `tests/cyim-lsp.bcyr` — benchmark stub (no-op)
- `tests/cyim-lsp.fcyr` — fuzz stub (legacy scaffold; cyrius
  fuzz only finds harnesses in `fuzz/`, so the stub is effectively
  dead — kept for the moment to match the cyrius init shape)

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

M2 (v0.3.0 — subprocess lifecycle) is the next session-scoped
chunk per [`roadmap.md`](roadmap.md). Spawn cyrius-lsp via
`process.cyr`'s `spawn()`, set up bidirectional stdin/stdout
pipes, run the LSP `initialize` handshake.
