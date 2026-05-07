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

### M3 — Document sync (v0.4.0) — ✅ shipped 2026-05-06

- `src/lsp_state.cyr` — per-buffer state vec
  `{buf_ptr, version, opened, uri}`; linear lookup; bump-version
  on each didChange.
- `src/lsp_documents.cyr` — JSON-string escape, URI builder,
  `.cyr` filter, three message-body builders, lazy-start,
  didOpen-on-first-touch dispatcher.
- `_cyim_lsp_post_save` and `_cyim_lsp_post_change` (in
  plugin_init.cyr) wired to `lsp_doc_did_save` /
  `lsp_doc_did_change`.
- `lsp_client_start_default()` — PATH lookup via `/usr/bin/env
  cyrius-lsp`; lazy-start uses this so cyim doesn't need an
  explicit `:lsp-start` ex-command.
- Tests: `tests/lsp_documents.tcyr` — 39 assertions covering
  JSON escape, URI build, filter, itoa, message body shapes,
  per-buffer state. Hook handlers themselves stay
  integration-tested at cyim 1.4.0 pickup.

**Deferred to v0.4.x or later** (originally listed under M3):
- **Buffer-close detection** (`textDocument/didClose`). cyim's
  plugin ABI doesn't expose a buffer-removal hook; documents
  stay "open" from the server's perspective until cyim exits.
  Lands when an ADR for the close hook is justified — probably
  v1.4.x once real use surfaces the resource-leak.
- **Incremental text deltas**. v0.4.0 ships full-text payloads
  on every didChange. Incremental sync (`TextDocumentContentChangeEvent`
  with range) is a perf optimisation; lands when buffers get
  large enough to bite.

### M5 — Inline diag highlighting (v0.5.1) — ✅ shipped 2026-05-06

- Brace-depth + string-aware walker over `"diagnostics":[...]`
  array (`_lsp_diags_walk_array`). Tracks JSON-string state
  so embedded `{` / `}` in messages don't fool the splitter.
- Per-diag extractor pulls `range.start.line`, `severity`,
  `message` (with two-pass JSON string decoder for the
  standard `\\ \" \/ \b \f \n \r \t` escapes; `\uXXXX` →
  `?` for v0.5.1).
- Per-diag tuples stored on lsp_diags entry +40 as
  `vec<tuple_ptr>` of 24 B `{line, severity, msg_ptr}`.
- `_cyim_lsp_diagnostic_provider` walks the tuple list,
  translates LSP severity (1=error..4=hint) → cyim's `DIAG_*`
  (3=error..0=hint), pushes via `diag_new(line, sev, msg)` to
  cyim's render-side out_vec.
- 15 new test assertions (43 total in lsp_diags.tcyr; was 28).

**Deferred to v0.5.x**:
- **`\uXXXX` UTF-8 decoding.** Currently emits `?`
  placeholders. cyrius-lsp doesn't emit these for ASCII so
  it's a real-world non-issue.
- **Drain placement.** Still in status_segment (one read sweep
  per frame, one-frame lag for diag_provider). Move to
  diagnostic_provider in v0.5.x if the lag bites.

### M4 — Diagnostics (v0.5.0) — ✅ shipped 2026-05-06 — **cyim 1.4.0 pickup target**

- `lsp_proc_set_nonblock` + `lsp_proc_recv_nb` in subprocess.cyr
  (fcntl-based O_NONBLOCK).
- `_lsp_drain_frames(handler_fp)` in lsp_client.cyr — reads
  bytes non-blocking, parses + dispatches every complete frame
  in one call, stops on EAGAIN.
- `src/lsp_diags.cyr` — per-URI 48 B entries with severity
  counts; bytescan-based publishDiagnostics parser
  (`_lsp_diags_find`, `_lsp_diags_count_pattern`,
  `_lsp_diags_extract_uri`); replaces prior state per URI on
  each notification.
- `_cyim_lsp_status_segment` in plugin_init.cyr drains pending
  frames + renders "E:N W:M I:K H:L" from active buffer's
  URI counts.
- `tests/lsp_diags.tcyr` — 28 assertions covering bytescan,
  state map, replace semantics, format renderer.

**Deferred to v0.5.1**:
- **Inline diag highlighting via diagnostic_provider hook.**
  Needs per-diag extraction (line + message + severity) from
  publishDiagnostics; v0.5.0 only counts severities. Rendering
  in cyim happens via `diag_new(line, severity, msg)` pushes
  into the out_vec.
- **Drain placement.** v0.5.0 drains in status_segment hook
  (fires every render frame); v0.5.1 may move to
  diagnostic_provider (fires earlier in the same frame).
- **JSON parser refactor.** v0.5.0 bytescans for speed +
  zero-stdlib-dep in hot path; if a future server formats
  publishDiagnostics in a way that breaks bytescan, refactor
  to use cyrius's `json_parse`.

### M5 (renumbered → M5b) — Inline diag highlighting (v0.5.1) — ✅ shipped 2026-05-06

(Renumbered: original M5 was navigation; v0.5.1 inserted "inline
diag highlighting" between v0.5.0 and v0.6.0 as a tighter
follow-up. The original M5 navigation lands at v0.6.0 below.)

### M6 (renumbered → M6) — Navigation (v0.6.0) — ✅ shipped 2026-05-06

- `_lsp_request_sync` in lsp_client.cyr — synchronous request/
  response with id-correlation; polls drain loop while keeping
  publishDiagnostics handlers wired during the wait.
- `lsp_nav_goto_def(s)` — sends textDocument/definition; jumps
  cursor for same-file results; prints status for cross-file.
- `lsp_nav_find_refs(s)` — sends textDocument/references; prints
  "lsp: N references" count in status.
- `src/lsp_position.cyr` — offset↔line/character conversions
  + Location response parser (bytescan).
- Wired ex-commands: `:lsp-goto-def`, `:lsp-find-refs`. Also
  real `:lsp-restart` (kill+respawn+initialize) and
  `:lsp-status` (pid + describe).
- 38 new test assertions in tests/lsp_position.tcyr.

**Deviations from original M5 plan**:
- **Ex-commands instead of `gd` / `gr`**. cyim's plugin-prefix-
  keymap ABI isn't wired; cyim 1.4.x adds it, then cyim-lsp
  v0.6.x can register the keymaps in addition to ex-commands.
- **Cross-file jumps deferred**. Same-file only at v0.6.0; needs
  cyim's `buf_load_file`-from-plugin-context ABI.
- **References as count, not list**. Quickfix list deferred to
  v0.6.x once cyim has list-display ABI.

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

### M7 — Closeout (v0.7.0) — ✅ shipped 2026-05-06

- Full clean test+fuzz from `rm -rf build`; all 164 assertions
  PASS, fuzz PASS, lint clean.
- Dead-code floor recorded (30 source-side functions, all
  intentional public ABI for cyim-side fold-in).
- Security re-scan: no `sys_system` / `popen` / `setuid`;
  `_lsp_proc_exec` is our own subprocess helper (expected);
  unchecked syscalls return values to caller (correct pattern).
- Refactor pass: nothing warranted consolidation.
- Doc sync confirmed.

### v1.0.0 — Public API freeze — ✅ shipped 2026-05-06

- ADR 0001 formalises the surface: entry point, hook callbacks,
  ex-commands (`:lsp-restart`, `:lsp-status`, `:lsp-goto-def`,
  `:lsp-find-refs`), client API (`lsp_client_*`), framing
  (`jsonrpc_*`), subprocess (`lsp_proc_*`), diag state
  (`lsp_diags_*`), document state (`lsp_state_*`), document
  handlers (`lsp_doc_*`, `lsp_nav_*`), position helpers
  (`_lsp_pos_*`).
- Compatibility envelope: stable across 1.x, additions
  allowed, breaking changes need 2.x.
- cyim 1.4.0 ready: 3-line cyim-side change picks up the
  frozen contract via `[plugins.cyim-lsp]` git tag `1.0.0`.

**Folding into cyrius stdlib** (sandhi-pattern fold) deferred
until a second long-horizon consumer materializes per niyama's
ADR 0011 fold-trigger precedent. cyim-lsp 1.x patches still
land here; post-fold extensions land in the vendored copy.

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

2026-05-06 — **v1.0.0 shipped**. Public API frozen per ADR 0001;
cyim 1.4.0 ready to pick up the frozen contract. cyim-lsp 1.x
patches accrete forward (cross-file jumps, gd/gr keymaps,
reference quickfix) without breaking the freeze. v2.0 reserved
for any breaking changes.
