# cyim-lsp — Roadmap

> Milestone plan through v1.0. State lives in [`state.md`](state.md);
> this file is the sequencing — what ships, in what order, against
> what dependency gates.

cyim-lsp is the LSP-client plugin for [cyim](https://github.com/MacCracken/cyim);
it consumes cyim's plugin ABI (frozen at cyim 1.3.6 / [ADR 0004](https://github.com/MacCracken/cyim/blob/main/docs/adr/0004-plugin-abi-freeze.md))
and spawns [`cyrius-lsp`](https://github.com/MacCracken/cyrius/blob/main/programs/cyrius-lsp.cyr)
as a subprocess, framing JSON-RPC 2.0 over pipes.

The milestone numbering below pairs cyim-lsp versions with the
cyim release that picks them up. cyim's v1.4.0 lands when
cyim-lsp ships **enough working LSP behaviour to be useful** —
target: v0.5.0 (publishDiagnostics surfaced through cyim's
diagnostic_provider hook).

## v1.0 criteria

- [ ] All six cyim plugin hooks have real implementations (no stubs)
- [ ] JSON-RPC framing handles all message shapes the LSP spec
      requires for the supported feature set (initialize, didOpen,
      didSave, didChange, didClose, publishDiagnostics, definition,
      references)
- [ ] Subprocess lifecycle managed: spawn, healthy `initialize`
      handshake, cleanup on cyim exit, restart on crash via
      `:lsp-restart`
- [ ] Per-buffer diagnostic state correctly reflects server pushes
      (publishDiagnostics) — clears on close, replaces on
      republish, survives buffer switches
- [ ] Test coverage: every public function has a `.tcyr` case;
      JSON-RPC framing covered by a fuzz harness
- [ ] At least one downstream consumer green (cyim 1.4.x using
      cyim-lsp without manual intervention)
- [ ] CHANGELOG complete from v0.1.0 onward
- [ ] Security audit pass (`docs/audit/YYYY-MM-DD-audit.md`) —
      LSP server input validation, subprocess argv hygiene,
      JSON-RPC parser bounds checking

## Milestones

### M0 — Scaffold (v0.1.0) — ✅ shipped 2026-05-06

- `cyrius init` scaffold + project structure
- `cyrius.cyml` `[lib]` section configured for the sandhi
  pattern (jsonrpc → lsp_client → plugin_init concatenation)
- `cyim_lsp_init()` registers no-op stubs for all six cyim
  hook types (post_save, post_change, status_segment,
  diagnostic_provider, ex_command for `:lsp-restart` /
  `:lsp-status`)
- Standalone driver builds; `cyrius distlib` produces
  `dist/cyim-lsp.cyr` ready for fold-in
- Pinned against cyim ADR 0004's frozen plugin ABI

### M1 — JSON-RPC framing (v0.2.0)

**Acceptance:** round-trip an LSP message in unit tests without a
real subprocess.

- `jsonrpc_build(method, params)` — Content-Length-framed
  request/notification cstring
- `jsonrpc_parse_frame(buf, len)` — strip Content-Length header,
  return body offset + length
- Message-id correlation: request → expected response id
- Tests: round-trip notifications + requests + responses;
  malformed-header rejection; partial-frame buffering
- Fuzz harness: random byte sequences fed to
  `jsonrpc_parse_frame`; invariants — no panics, no OOB reads

### M2 — Subprocess lifecycle (v0.3.0)

**Acceptance:** spawn cyrius-lsp from a test, observe the
`initialize` handshake complete, then clean shutdown.

- Spawn cyrius-lsp via `process.cyr`'s `spawn()` with stdin/stdout
  pipes (NOT inherited; bidirectional dup2 setup)
- `initialize` request → response handshake; capture server
  capabilities
- `initialized` notification (LSP protocol requirement)
- Graceful shutdown: `shutdown` request → `exit` notification →
  process reap
- `:lsp-restart` ex-command kills + respawns cleanly
- `:lsp-status` ex-command prints pid + capability summary
- State stored on the `_lsp_pid` global (extended into a struct
  with capability fields); `lsp_client_running()` returns the pid

### M3 — Document sync (v0.4.0)

**Acceptance:** open cyim against a .cyr file, edit + save, and
observe didOpen / didChange / didSave reach the server.

- post_change_hook: send `textDocument/didChange` with
  per-buffer version increment + full-text payload (incremental
  text-deltas deferred to later)
- post_save_hook: send `textDocument/didSave`
- New buffer detection (first edit / first save): emit
  `textDocument/didOpen` before the change/save notification
- Buffer-close detection (TBD — needs cyim hook for buffer
  removal): emit `textDocument/didClose`
- Per-buffer state: URI, version, language id

### M4 — Diagnostics (v0.5.0) — **cyim 1.4.0 pickup target**

**Acceptance:** edit a .cyr file with a syntax error, see
diagnostics in cyim's status segment + (eventually) inline.

- Receive `textDocument/publishDiagnostics` notifications from
  the server
- Per-URI diag map: line, severity, message
- diagnostic_provider hook: walk the map for the active buffer,
  push entries into the out_vec via cyim's `diag_new()`
- status_segment hook: render `E:N W:M I:K` from the per-buffer
  diag count (omitted when all zero)
- Tests: drive a scripted publishDiagnostics through the
  framing layer, verify cyim-side diag map state

### M5 — Navigation (v0.6.0)

**Acceptance:** `gd` jumps to definition, `gr` populates a
references list.

- `textDocument/definition` request + response handler
- `textDocument/references` request + response handler
- normal_key registration for `g d` / `g r` (requires cyim's
  plugin-prefix-keymap ABI — coordinate with cyim if needed; an
  earlier milestone may add the prefix support to cyim)
- Cursor jump for definition (single result); quickfix-style
  list for references

### M6 — Closeout (v0.7.0)

**Acceptance:** v1.0.0 criteria met across the board.

- Refactor pass — consolidate duplicated message-build code
  across handlers
- Dead-code audit
- Performance pass — message-throughput bench (synthetic
  publishDiagnostics flood)
- Security audit (`docs/audit/YYYY-MM-DD-audit.md`):
  subprocess argv hygiene, JSON-RPC parser bounds, server
  input validation (assume hostile server messages — never
  trust line numbers / byte ranges blindly)
- Documentation: full guide pass; architecture docs for any
  non-obvious invariants surfaced during M1–M5

### v1.0.0 — Public API freeze

- Tag v1.0.0 once all M6 closeout items pass
- Folding into cyrius stdlib (sandhi-pattern fold) deferred
  until a second long-horizon consumer materializes per
  niyama's ADR 0011 fold-trigger precedent

## Out of scope (for v1.0)

- **Completion** (`textDocument/completion`) — needs cyim's
  popup-menu UI, which doesn't exist. Lands when cyim grows
  popup support.
- **Hover** (`textDocument/hover`) — same blocker.
- **Formatting** (`textDocument/formatting`) — could ship as a
  separate plugin (`cyim-fmt`) wrapping any formatter, not
  necessarily LSP.
- **Code actions / rename / signature help** — post-v1.0.
- **Multi-server orchestration** — v1.0 supports one LSP server
  per cyim process (cyrius-lsp). Multi-language editors that
  want one server per language are post-v1.0.
- **Workspace operations** (`workspace/didChangeConfiguration`,
  `workspace/symbol`, etc.) — post-v1.0 once cyim has multi-buffer
  workspace concepts.

## Coordination with cyim

| cyim version | cyim-lsp version picked up | What lands |
|---|---|---|
| 1.3.7 | (none — closeout pass) | Final cyim-side closeout; no plugin pickup |
| 1.4.0 | v0.5.0 (diagnostics) | First useful cyim-lsp consumer; `[plugins.cyim-lsp]` entry in cyim's cyrius.cyml |
| 1.4.x | v0.6.0+ | Navigation (gd/gr), restart/status ex-commands, etc. |
| 1.5.0 | v1.0.0 | API-frozen plugin |

## Last updated

2026-05-06 — v0.1.0 scaffold shipped. M1 (JSON-RPC framing) is
the next session-scoped chunk.
