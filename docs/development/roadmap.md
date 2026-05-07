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

### M1 — JSON-RPC framing (v0.2.0) — ✅ shipped 2026-05-06

- `jsonrpc_build_notification(method, params)` — Content-Length-
  framed cstring; `params` is pre-serialized JSON
- `jsonrpc_build_request(id, method, params)` — same plus `id`
  field for response correlation
- `jsonrpc_parse_frame(buf, len, off_out, len_out)` — tri-state
  return: 1 valid / 0 incomplete / -1 malformed
- `jsonrpc_next_id()` — monotonic id allocator (notifications
  don't consume ids)
- Tests: 21 assertions across 13 groups in
  `tests/jsonrpc.tcyr`; round-trip + 3 rejection paths +
  incomplete-buffer states + zero-length body + notification id
  invariant
- Fuzz: `fuzz/jsonrpc.fcyr` runs 5000 random buffers through
  `jsonrpc_parse_frame`; invariants {return ∈ {1,0,-1};
  body_off + body_len ≤ buf_len on success} hold across all
  iterations

### M2 — Subprocess lifecycle (v0.3.0) — ✅ shipped 2026-05-06

- `src/subprocess.cyr` — bidirectional pipe primitives via
  `sys_pipe` × 2 + `sys_fork` + `sys_dup2` + `sys_execve`. Public
  API: `lsp_proc_spawn / send / recv / close / kill / pid`. 32 B
  handle struct.
- `src/lsp_client.cyr` — `lsp_client_start(cmd_path)` runs spawn
  + `initialize` request + response + `initialized` notification.
  `lsp_client_stop()` runs `shutdown` request + response + `exit`
  notification + `sys_waitpid` reap.
- `_lsp_recv_frame` — accumulating frame reader on top of
  `jsonrpc_parse_frame` + `lsp_proc_recv`. 8 KB cap.
- Verified end-to-end against `/home/macro/.cyrius/bin/cyrius-lsp`:
  initialize / initialized / shutdown / exit all clean.
- Tests: `tests/subprocess.tcyr` (15 assertions via `/bin/cat`
  mock — fork + dup2 + pipe orientation + send/recv + close
  idempotency + EOF on exec-failure).

**Deferred to M3+** (originally listed under M2):
- `:lsp-restart` / `:lsp-status` ex-command behaviour. The
  `plugin_register_ex_command` registrations are wired in
  v0.1.0; the callbacks remain stubs until M3 because the
  human-visible behaviour ties to per-buffer document sync
  (`:lsp-status` should report "open documents: N", not just pid).
- Capability parsing. v0.3.0 discards the initialize response
  body; M3+ stores capabilities for feature negotiation
  (`definitionProvider`, etc.).

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

2026-05-06 — v0.3.0 shipped (M2, subprocess lifecycle). End-to-end
handshake verified against real cyrius-lsp. M3 (document sync,
v0.4.0) is the next session-scoped chunk.
