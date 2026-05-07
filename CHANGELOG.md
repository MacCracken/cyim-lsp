# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [1.0.1] — TBD

Audit-finding repairs from the v1.0.0 pre-freeze security pass
([`docs/audit/2026-05-06-audit.md`](docs/audit/2026-05-06-audit.md)).
All three findings are LOW / defense-in-depth — not exploitable
under the v1.0.0 consumer set, but contract-tightening landings
worth shipping promptly so any future consumer can rely on the
parser invariants.

### Security

- **F-1 — Content-Length integer overflow.** `jsonrpc_parse_frame`
  in `src/jsonrpc.cyr` now caps the parsed Content-Length at
  16 MB (matching `_lsp_recv_frame`'s buffer cap) and returns
  `-1` (malformed) if a server's header digits would exceed
  it. Closes the contract gap where a malicious server could
  send `Content-Length: 99999999999999999999\r\n\r\n…` and
  overflow `n` to a negative value.
- **F-2 — Diagnostic integer overflow.** `_lsp_diag_parse_int`
  in `src/lsp_diags.cyr` caps line / severity values at 100M
  (LSP coords are non-negative; 100M dwarfs any real file).
  Same overflow shape as F-1.
- **F-3 — String parser second-pass bound.** Mirror first
  pass's `if (rp >= blen) { return 0; }` guard at the top of
  `_lsp_diag_parse_string`'s second loop. Defense-in-depth:
  with stable input bytes the second pass walks the same
  validated path as the first, but the bound is now explicit.

### Tests

- New `tests/jsonrpc.tcyr` cases for F-1 (oversized
  Content-Length → -1).
- New `tests/lsp_diags.tcyr` cases for F-2 (line / severity
  with 20-digit values → capped) and F-3 (truncated body
  between passes → 0).

## [1.0.0] — 2026-05-06

**Public API freeze.** cyim-lsp 1.0.0 freezes the public surface
per [ADR 0001](docs/adr/0001-api-freeze.md). cyim 1.4.0 picks up
this version's frozen contract; backwards-incompatible changes
wait for cyim-lsp 2.x.

The v0.x sequence took us from `cyrius init` scaffold (v0.1.0)
through end-to-end LSP behaviour:

- v0.2.0 — JSON-RPC framing (M1)
- v0.3.0 — subprocess lifecycle, initialize handshake (M2)
- v0.4.0 — document sync, didOpen / didChange / didSave (M3)
- v0.5.0 — diagnostic counts via status_segment (M4)
- v0.5.1 — inline diag highlighting via diagnostic_provider (M5)
- v1.0.0 — **navigation (M6) + closeout (M7) + freeze**

This entry consolidates v0.6.0 (navigation), v0.7.0 (closeout
verification), and the v1.0.0 freeze itself. All three were cut
in the same session; folding them into one release entry keeps
the ledger honest about what actually shipped to consumers.

### Frozen surface

ADR 0001 enumerates the v1.0.0 surface — entry point, hook
callbacks, ex-commands, struct layouts, severity values. Stable
across cyim-lsp 1.x. Additions allowed; breaking changes need
2.x.

### Added

- **`docs/adr/0001-api-freeze.md`** (310 lines) — formalises
  the public surface: every public function with signature,
  every struct layout, every ex-command name. Compatibility
  envelope (stable across 1.x; additions allowed; breaking
  changes need 2.x). Three alternatives considered + rejected
  (defer freeze, partial subset, no freeze).
- **`src/lsp_position.cyr`** (160 lines) — buffer position
  helpers + Location parser. `_lsp_pos_offset_to_lc` /
  `_lc_to_offset` round-trip cyim's byte offsets ↔ LSP's
  line+character. `_lsp_pos_extract_uri` /
  `_extract_first_line` / `_extract_first_character` bytescan
  the response body for the first Location's URI + range.start
  fields. Supports Location and Location[] response shapes
  (peeks first array element).
- **Synchronous request/response helper** (`_lsp_request_sync`
  in `src/lsp_client.cyr`). Sends a JSON-RPC request, polls
  the drain loop until a response with the matching id arrives
  or `max_iters` polling cycles elapse. Notifications
  (publishDiagnostics) keep flowing through
  `lsp_diags_handle_frame` during the wait.
- **Navigation handlers** (`lsp_nav_goto_def`,
  `lsp_nav_find_refs` in `src/lsp_documents.cyr`):
  - `goto_def` sends `textDocument/definition`, parses the
    Location response, jumps cursor for same-file results,
    prints status for cross-file results (cross-file jump
    deferred — needs cyim's `buf_load_file`-from-plugin-
    context ABI).
  - `find_refs` sends `textDocument/references`, counts
    results via bytescan, prints "lsp: N references" in
    status. Quickfix list integration deferred — needs cyim's
    list-display ABI.
- **Real `:lsp-restart` and `:lsp-status`** in
  `src/plugin_init.cyr` (v0.1.0 stubs replaced).
  `:lsp-restart` cleanly shuts down + respawns the server;
  `:lsp-status` prints `lsp: cyrius-lsp pid=N` or
  `lsp: (not attached)`.
- **New ex-commands**: `:lsp-goto-def`, `:lsp-find-refs`. Both
  registered in `cyim_lsp_init` alongside `:lsp-restart` /
  `:lsp-status`.
- **`tests/lsp_position.tcyr`** (140 lines, 38 assertions
  across 10 groups) — offset↔lc round-trip across multi-line
  buffers, lc-to-offset clamping, Location extract from single
  + array response shapes + null result.
- **First-party scaffold conformance.** cyim-lsp now matches
  cyim's full project shape: `CONTRIBUTING.md`, `SECURITY.md`,
  `CODE_OF_CONDUCT.md` at root; `docs/audit/` directory.
  Closes the gap between `cyrius init` scaffold output and the
  first-party documentation standard.
- **Version-anchoring.** `scripts/version-bump.sh` +
  auto-generated `src/version_str.cyr` mirror cyim's pattern.
  The standalone CLI banner reads from a generated var instead
  of a hardcoded literal, so `VERSION` is the single source of
  truth — no drift possible.
- **Security audit.**
  [`docs/audit/2026-05-06-audit.md`](docs/audit/2026-05-06-audit.md)
  — first-pass internal review + 2025-era LSP/JSON-parser CVE
  corpus survey. Result: 0 CRITICAL / 0 HIGH / 0 MEDIUM; 3 LOW
  (all defense-in-depth, all triaged for v1.0.1 — Content-
  Length overflow cap, diag-int overflow cap, second-pass
  string bound).

### Changed

- **`cyrius.cyml [lib].modules`** reorder: `lsp_diags.cyr`
  moved before `lsp_client.cyr` so `_lsp_response_handler` can
  reference `_lsp_diags_find` / `_lsp_diag_parse_int`. Added
  `lsp_position.cyr` between `lsp_state` and `lsp_documents`.
- **`src/main.cyr`** — added `include "src/lsp_diags.cyr"` so
  the standalone build chain matches the new dist concat order.
- VERSION 0.5.1 → 1.0.0. M6 navigation source landed in this
  cut; M7 closeout verification + the v1.0.0 freeze layered
  over it as documentation-only steps.

### Closeout verification (M7)

All checks per the cyim project's closeout convention passed:

1. **Full test + fuzz from clean** (`rm -rf build && cyrius
   deps && cyrius build`): 7 test suites all PASS (164
   assertions), `cyrius fuzz` 1 harness PASS, `cyrius lint` 0
   warnings.
2. **Dead-code audit**: 30 source-side functions DCE-stripped
   from the standalone build — ALL intentional public plugin
   ABI consumed only at fold-in into cyim. The floor below is
   the surface v1.0.0 freezes.
3. **Refactor pass**: nothing warranted consolidation. Eight
   library files (jsonrpc / subprocess / lsp_diags / lsp_client
   / lsp_state / lsp_position / lsp_documents / plugin_init),
   each tight and single-purpose.
4. **Code review** of `0.1.0..HEAD` (~2500 net inserted lines
   across 8 source files): no missed guards, off-by-ones,
   silently-ignored errors. The brace-depth walker bug at
   v0.5.1 was caught + fixed in-cycle.
5. **Cleanup sweep**: no stale comments, no orphaned files,
   no unused includes.
6. **Security re-scan**: no `sys_system` / `popen` / `setuid`
   / `setgid`. The two `exec*` hits are `_lsp_proc_exec` (our
   own subprocess fork+exec helper). All `sys_read` /
   `sys_write` sites in `subprocess.cyr` propagate return
   values to callers (correct pattern, not "unchecked"). The
   full audit at `docs/audit/2026-05-06-audit.md` extends this
   re-scan with the 2025 CVE corpus.
7. **Doc sync**: CHANGELOG / state.md / roadmap.md all current.
8. **Version verify**: VERSION 1.0.0, CHANGELOG header,
   intended git tag `1.0.0` all match.
9. **Full clean build**: passed.

### Dead-code floor (v1.0.0)

The standalone build (`cyrius build src/main.cyr`) DCE-strips
30 functions — all intentional public plugin ABI consumed only
when the distfile gets folded into cyim's compilation unit:

**Framing (`jsonrpc.cyr`)**: `_jr_append`, `_jr_itoa`,
`_jr_frame`, `jsonrpc_next_id`,
`jsonrpc_build_notification`, `jsonrpc_build_request`,
`jsonrpc_parse_frame`.

**Subprocess (`subprocess.cyr`)**: `_lsp_proc_exec`,
`lsp_proc_spawn`, `lsp_proc_send`, `lsp_proc_recv`,
`lsp_proc_close`, `lsp_proc_kill`, `lsp_proc_set_nonblock`,
`lsp_proc_recv_nb`.

**Diagnostics (`lsp_diags.cyr`)**: `lsp_diags_count`,
`lsp_diag_tuple_line`, `lsp_diag_tuple_severity`,
`lsp_diag_tuple_msg`, `lsp_diags_entry_count`,
`lsp_diags_entry_tuple`, `_lsp_diags_itoa_into`,
`_lsp_diags_emit_cat`, `lsp_diags_format_status`.

**Client (`lsp_client.cyr`)**: `lsp_client_proc`,
`_lsp_recv_frame`, `_lsp_send_all`, `_lsp_initialize`,
`_lsp_drain_frames`, `_lsp_request_sync`.

Future minors may add to this list (additions allowed);
breaking changes wait for v2.0.

### cyim 1.4.0 pickup

The cyim-side change is a 3-line cut:

```toml
# cyim/cyrius.cyml
[plugins.cyim-lsp]
git    = "https://github.com/MacCracken/cyim-lsp.git"
tag    = "1.0.0"
modules = ["dist/cyim-lsp.cyr"]
```

```cyrius
# cyim/src/main.cyr
include "lib/cyim-lsp.cyr"            # added
...
fn main() {
    alloc_init();
    args_init();
    plugin_init();
    trailing_ws_init();
    cyim_lsp_init();                  # added
    ...
}
```

Plus VERSION 1.3.7 → 1.4.0, CHANGELOG, state, roadmap.

### Out-of-scope at v1.0.0 (deferred to cyim-lsp 1.x)

- Cross-file definition jumps (needs cyim's
  `buf_load_file`-from-plugin ABI)
- `gd` / `gr` keymaps (needs cyim's plugin-prefix-keymap ABI)
- Reference quickfix list (needs cyim's list-display ABI)
- `\uXXXX` UTF-8 decoding in diag messages (`?` placeholder
  today)
- Multi-server orchestration (one cyrius-lsp per cyim process)
- Capability negotiation beyond the initialize handshake
  (server caps captured but not used to gate features)

All listed in ADR 0001's "Subject to expansion" envelope —
1.x patches add them without breaking the freeze.

### Tests

- `cyrius test` 7 suites, **164 assertions all PASS**:
  cyim-lsp.tcyr 2, jsonrpc.tcyr 21, subprocess.tcyr 15,
  lsp_documents.tcyr 39, lsp_diags.tcyr 43,
  lsp_position.tcyr 38 (new this cut), src/test.cyr 6.
- `cyrius fuzz` 1 PASS · `cyrius lint` 0 warnings.

### Binary / dist

- `dist/cyim-lsp.cyr` 2045 → 2547 lines (+502). Position
  helpers + sync request/response + navigation handlers + real
  restart/status/goto/refs ex-commands account for the delta.
  v0.7.0 closeout + v1.0.0 freeze + v1.0.0 conformance work
  are documentation-only and don't change the distfile.

## [0.5.1] — 2026-05-06

M5 — inline diag highlighting. v0.5.0's no-op
`_cyim_lsp_diagnostic_provider` is now a real consumer of
publishDiagnostics: extracts per-diag tuples
`{line, severity, message}` from the LSP body and pushes them
into cyim's render-side out_vec via cyim ADR 0004's
`diag_new()`. cyim's render layer paints them as inline
markers / gutter glyphs.

This completes the publishDiagnostics-to-render round-trip
that started at v0.5.0:

```
server: publishDiagnostics
  → _lsp_drain_frames                       (v0.5.0)
  → lsp_diags_handle_frame                  (v0.5.0: counts)
  → _lsp_diags_walk_array                   (v0.5.1: tuples)
  → entry +40 vec<{line, severity, message}>
  → _cyim_lsp_diagnostic_provider           (v0.5.1: pushes)
  → cyim's diag_new + out_vec               (cyim ADR 0004)
  → render-side inline paint
```

cyim 1.4.x picks up v0.5.1 for the second cyim-lsp pickup
(after the v0.5.0 status_segment cut shipped at cyim 1.4.0).

### Added

- **Brace-depth + string-aware array walker**
  (`_lsp_diags_walk_array` in `src/lsp_diags.cyr`). Iterates
  the `"diagnostics":[...]` array, calling
  `_lsp_diags_extract_one(body, blen, obj_start, obj_end, entry)`
  for each top-level diag object. Tracks JSON-string state so
  embedded `{` / `}` characters in messages don't fool the
  splitter; tracks escape state so `\"` doesn't end a string
  prematurely.
- **Per-diag extractor** (`_lsp_diags_extract_one`). Within a
  diag object's byte range, locates `"start":{` then `"line":N`
  for the line number (LSP 0-indexed → cyim 1-indexed via +1),
  `"severity":N` for severity (1-4), and `"message":"..."` for
  the human-readable message.
- **JSON string parser** (`_lsp_diag_parse_string`) — two-pass
  decoder that handles the standard escapes `\\ \" \/ \b \f
  \n \r \t` and emits `?` placeholders for `\uXXXX` (full
  UTF-8 escape decoding deferred to v0.5.x; modern LSP servers
  rarely emit `\u` for the BMP characters that fit in cyim's
  display).
- **Per-diag tuple storage** on lsp_diags entry +40
  (`vec<tuple_ptr>` of 24 B `{line, severity, msg_ptr}`
  records). Replaced atomically on each publishDiagnostics
  per LSP §3.7.4.
- **Public ABI** in `src/lsp_diags.cyr`:
  `lsp_diags_entry_count(entry)`, `lsp_diags_entry_tuple(entry, idx)`,
  `lsp_diag_tuple_line/severity/msg(t)`. Frozen for v0.5.x.
- **`tests/lsp_diags.tcyr`** extended: 5 new groups (15 new
  assertions; 43 total, was 28). Coverage: tuple extraction
  with nested ranges, JSON escape decoding in messages,
  brace-in-string corner case, empty array, replace
  semantics for tuple list.

### Changed

- **`src/plugin_init.cyr:_cyim_lsp_diagnostic_provider`** —
  was no-op; now walks the active buffer's URI's tuple list
  and pushes each diag into out_vec via `diag_new(line,
  cyim_severity, msg)`. LSP severity (1=error..4=hint)
  translated to cyim's `DIAG_*` constants (cyim ADR 0004:
  3=error..0=hint — higher is more severe in cyim's
  convention).
- `_lsp_diags_reset` clears entry +40 alongside the four
  severity counts (each publishDiagnostics replaces both).

### Tests

- `cyrius test` — 6 suites: cyim-lsp.tcyr 2, jsonrpc.tcyr 21,
  subprocess.tcyr 15, lsp_documents.tcyr 39, **lsp_diags.tcyr
  43** (+15 from v0.5.0's 28), src/test.cyr 5. Total 125
  assertions, all PASS.
- `cyrius fuzz` 1 PASS · `cyrius lint` 0 warnings.

### Notes

- **JSON parser refactor still deferred.** v0.5.1's bytescan +
  string-aware walker is robust enough for cyrius-lsp's actual
  output. If a future server emits non-canonical formatting
  (whitespace inside `"diagnostics":` array, etc.) refactor to
  json stdlib's `json_parse`. v0.5.1 doesn't preempt it.
- **`\u` escape rendering**. LSP messages with `\u00XX` codes
  render as `?` in v0.5.1. cyrius-lsp doesn't emit these for
  ASCII-range characters (which is everything cyim displays
  cleanly), so this is a real-world non-issue. Full
  UTF-8-aware `\u` decode lands when a server actually emits
  one.
- **Drain placement unchanged.** Still in
  `_cyim_lsp_status_segment` (one read sweep per render
  frame). Could move to `diagnostic_provider` in v0.5.x to
  remove the one-frame lag between publishDiagnostics arriving
  and inline paint refreshing; cost is reading earlier in the
  frame which may delay first paint. Current placement is fine
  for v0.5.1.
- **dist/cyim-lsp.cyr** grew 1737 → 2045 lines (+308). The
  walker, string parser, tuple storage, and the wired
  diagnostic_provider account for the delta.

## [0.5.0] — 2026-05-06

M4 — diagnostics. **cyim 1.4.0 pickup target.** First version
where cyim-lsp delivers user-visible value: open a `.cyr` file
in cyim, edit it with a syntax error, and the status line shows
"E:N W:M I:K H:L" reflecting cyrius-lsp's `publishDiagnostics`.

The diag-count rendering is delivered via the `status_segment`
hook (cyim ADR 0004 surface). Inline per-line highlighting via
the `diagnostic_provider` hook lands at v0.5.1 — needs per-line
extraction from the publishDiagnostics body, which is structurally
larger than v0.5.0's count-only bytescan.

### Added

- **`src/lsp_diags.cyr`** (220 lines) — per-URI diagnostic state.
  - `lsp_diags_handle_frame(body, body_len)` — recognises
    `textDocument/publishDiagnostics` notifications, extracts
    URI, counts severities by bytescan (`"severity":1` etc.).
    Replaces prior state for the same URI per LSP §3.7.4.
  - `lsp_diags_lookup(uri)` / `lsp_diags_count(entry, severity)`
    — O(N) URI lookup; severity counts read from a 48 B
    per-URI entry.
  - `lsp_diags_format_status(entry, out_buf, cap)` — renders
    "E:N W:M I:K H:L" omitting zero categories. Returns 0
    bytes when all four are zero (status line stays clean).
  - Bytescan helpers (`_lsp_diags_find`,
    `_lsp_diags_count_pattern`, `_lsp_diags_extract_uri`) —
    no json stdlib dependency for the hot path; LSP message
    structure is well-defined enough that bytescan is fast +
    correct against cyrius-lsp output.
- **`lsp_proc_set_nonblock(proc)`** in `src/subprocess.cyr` —
  fcntl-based `O_NONBLOCK` set on the read fd. Called at end of
  `_lsp_initialize` so subsequent reads can return without
  blocking.
- **`lsp_proc_recv_nb(proc, buf, max)`** in `src/subprocess.cyr` —
  non-blocking recv variant. Returns -2 on EAGAIN (no data
  ready), 0 on EOF, > 0 bytes read.
- **`_lsp_drain_frames(handler_fp)`** in `src/lsp_client.cyr` —
  reads bytes non-blocking, accumulates into a 16 KB scratch
  buffer, parses every complete LSP frame, dispatches each to
  `handler_fp(body_ptr, body_len)`. Stops when EAGAIN. Handles
  multi-frame batches in one call (server may send didOpen
  response + publishDiagnostics back-to-back).
- **`tests/lsp_diags.tcyr`** (180 lines, 28 assertions across
  11 groups). Coverage: bytescan severity counts (3-of-4 cases,
  empty buffer), URI extract success + failure, frame dispatch
  for publishDiagnostics + ignore for other methods, state
  REPLACES on subsequent publishDiagnostics for same URI,
  multi-URI independence, status_segment formatting (3 single-
  category cases + zero-count case + full E+W+I+H case).

### Changed

- **`src/lsp_client.cyr:_lsp_initialize`** — calls
  `lsp_proc_set_nonblock(_lsp_proc)` at the end so subsequent
  drain calls don't block. Handshake itself stays blocking
  (we need the response).
- **`src/plugin_init.cyr:_cyim_lsp_status_segment`** — was a
  no-op stub; now drains pending frames, looks up the active
  buffer's URI in lsp_diags' map, formats counts via
  `lsp_diags_format_status`. Returns the rendered cstring or
  0 (omit segment).
- **`cyrius.cyml [lib].modules`** order extended:
  `... lsp_state.cyr → lsp_documents.cyr → lsp_diags.cyr →
  plugin_init.cyr`. lsp_diags references lsp_client's frame
  drain helper but not the document-sync side (those touch
  cyim's plugin ABI), so it slots between lsp_documents and
  plugin_init.

### Tests

- `cyrius test` — 6 suites (was 5): cyim-lsp.tcyr 2,
  jsonrpc.tcyr 21, subprocess.tcyr 15, lsp_documents.tcyr 39,
  **lsp_diags.tcyr 28** (new), src/test.cyr 5. Total 110
  assertions, all PASS.
- `cyrius fuzz` 1 harness PASS.
- `cyrius lint` 0 warnings.

### Notes

- **Inline diag highlighting deferred to v0.5.1.** v0.5.0's
  `_cyim_lsp_diagnostic_provider` callback stays no-op; only
  status_segment shows diag info. Rendering per-line markers
  needs per-diag extraction (line / message / severity) from
  the publishDiagnostics body, which the v0.5.0 bytescan only
  counts.
- **Drain happens at status_segment time.** v0.5.0 drains in
  `_cyim_lsp_status_segment` since that's the one hook that's
  reliably called every render frame. v0.5.1 will move this
  to `diagnostic_provider` (which fires earlier in the same
  frame) once that hook does real work.
- **Bytescan is fragile against whitespace variations and
  string escapes within URIs.** cyrius-lsp's actual output
  uses the canonical message shape, so this works in practice.
  If a future server formats publishDiagnostics differently,
  refactor to use json stdlib's `json_parse` for the message
  body.
- **Frame buffer 16 KB.** Larger publishDiagnostics (huge
  files with many errors) may exceed this; v0.5.x can grow
  if real-world output bites.
- **dist/cyim-lsp.cyr** grew 1278 → 1737 lines (+459).

### cyim 1.4.0 readiness

cyim 1.4.0 picks up cyim-lsp v0.5.0 with these surface
guarantees:

1. `cyim_lsp_init()` registers six callbacks on cyim's plugin
   ABI (frozen at cyim ADR 0004); five do real work, one
   (diagnostic_provider) is no-op until v0.5.1.
2. Opening / editing / saving a `.cyr` file in cyim auto-spawns
   cyrius-lsp (via `/usr/bin/env cyrius-lsp` PATH lookup),
   sends didOpen + didChange / didSave, and surfaces server-
   pushed diagnostic counts in cyim's status row.
3. Plugin degrades cleanly if cyrius-lsp isn't on PATH —
   lazy-start fails silently and all subsequent hooks no-op.

cyim 1.4.0's pickup is a 2-line cyim-side change:
`[plugins.cyim-lsp]` block in `cyrius.cyml` + `include
"lib/cyim-lsp.cyr"` in `src/main.cyr` + `cyim_lsp_init()` call
in `main()` after `plugin_init()`.

## [0.4.0] — 2026-05-06

M3 — document sync. cyim-lsp now actually does its job: the
plugin hooks registered by `cyim_lsp_init()` route changes /
saves into the right LSP notifications. From the consumer's
perspective (cyim 1.4.0), editing a `.cyr` file in cyim and
saving will reach the cyrius-lsp server as
`textDocument/didOpen` → `textDocument/didChange` →
`textDocument/didSave` — the three notifications cyrius-lsp
needs to send `publishDiagnostics` back.

`post_change_hook` and `post_save_hook` are no-op stubs no
more.

### Added

- **`src/lsp_state.cyr`** (95 lines) — per-buffer document
  state: `{buf_ptr, version, opened, uri}` entries in a vec.
  Public: `lsp_state_init`, `lsp_state_lookup`,
  `lsp_state_create`, `lsp_state_bump_version`,
  `lsp_state_mark_opened`, `lsp_state_is_opened`,
  `lsp_state_version`, `lsp_state_uri`, `lsp_state_buf`,
  `lsp_state_count`. Linear vec scan for lookup (typical use
  is 1-10 buffers; hashmap pays off later).
- **`src/lsp_documents.cyr`** (300 lines) — high-level handlers:
  - `lsp_doc_did_change(s)` — filters non-`.cyr` files,
    lazy-starts cyrius-lsp on first call, sends `didOpen` if
    new buffer or `didChange` with bumped version + full-text
    payload.
  - `lsp_doc_did_save(s, path)` — same filter chain; sends
    `didOpen` if buffer was untouched-then-saved, then
    `didSave`.
  - JSON-string escape (`_lsp_jesc_byte`,
    `_lsp_buf_to_json_string`): the 7 short escapes (`\\`,
    `\"`, `\b`, `\f`, `\n`, `\r`, `\t`) plus `\u00XX` for
    other control bytes.
  - `_lsp_path_to_uri` — `/foo/bar.cyr` → `file:///foo/bar.cyr`.
    Assumes absolute paths (cyim normalises before storing).
  - `_lsp_path_is_cyr` — extension filter.
  - Three message-body builders for didOpen / didChange /
    didSave with hand-rolled JSON envelopes (no json stdlib
    dependency for outgoing messages — same approach as
    jsonrpc.cyr's v0.2.0 envelope).
- **`lsp_client_start_default()`** in `src/lsp_client.cyr` —
  spawns cyrius-lsp via `/usr/bin/env cyrius-lsp` for PATH
  lookup (sys_execve doesn't search PATH itself). lazy-start
  in `_lsp_doc_lazy_start` calls this.
- **`tests/lsp_documents.tcyr`** (130 lines, 39 assertions
  across 10 groups). Coverage: every short escape + `\u`
  escapes + printable passthrough + URI prepend + 7 .cyr
  filter cases + 4 itoa cases + exact-JSON shape verification
  for the three message-body builders + lsp_state vec
  lookup/create/bump-version. Stubs cyim plugin ABI symbols
  (`editor_buf`, `editor_file_path`, `buf_len`, `buf_get`)
  so the standalone build resolves; never invokes the
  handler functions that would call them.

### Changed

- **`cyrius.cyml [lib].modules`** order extended:
  `jsonrpc.cyr → subprocess.cyr → lsp_client.cyr →
  lsp_state.cyr → lsp_documents.cyr → plugin_init.cyr`. The
  two new files come after lsp_client (which they reference
  for `_lsp_send_all`, `lsp_client_running`,
  `lsp_client_start_default`) and before plugin_init (which
  references the doc handlers from `_cyim_lsp_post_save` and
  `_cyim_lsp_post_change`).
- **`src/plugin_init.cyr`** — `_cyim_lsp_post_save` now calls
  `lsp_doc_did_save(s, path)`; `_cyim_lsp_post_change` calls
  `lsp_doc_did_change(s)`. v0.1.0 stubs retired.
- **`src/lsp_client.cyr`** — `lsp_client_start(cmd_path)`
  factored into `_lsp_client_start_with(cmd, arg1, arg2)`;
  `lsp_client_start_default` added as the PATH-lookup entry
  used by lazy-start.

### Tests

- `cyrius test` — 5 suites (was 4): cyim-lsp.tcyr 2,
  jsonrpc.tcyr 21, subprocess.tcyr 15, **lsp_documents.tcyr 39**
  (new), src/test.cyr 3. Total 80 assertions, all PASS.
- `cyrius fuzz` 1 harness PASS unchanged.
- `cyrius lint` 0 warnings.

### Notes

- **Filter is `.cyr`-only.** Other extensions get silently
  skipped — the server never sees a notification for them.
  Multi-language is post-v1.0 per the cyim-lsp roadmap "Out
  of scope".
- **Full-text payload, not incremental.** `didChange` ships
  the entire buffer text on every keystroke that mutates.
  Incremental text-document-sync (`TextDocumentContentChangeEvent`
  with range) is a v0.4.x optimisation when perf surfaces it.
- **Auto-start on first `.cyr` interaction.** cyim doesn't
  need `:lsp-start` — opening a `.cyr` and editing it fires
  the spawn. If `cyrius-lsp` isn't on PATH, the spawn fails
  silently and subsequent hooks no-op (degrades cleanly).
- **Buffer-close detection deferred.** cyim's plugin ABI
  doesn't currently expose a buffer-removal hook, so
  `textDocument/didClose` never fires today. Documents stay
  "opened" from the server's perspective until cyim exits.
  ADR for the buffer-close hook lands in cyim alongside a
  concrete need (probably v1.4.x once cyim-lsp surfaces the
  resource-leak in real use).
- **dist/cyim-lsp.cyr** grew 759 → 1278 lines (+519). The
  two new files account for most of the delta; the
  hand-rolled JSON envelope builders are deliberately verbose
  (no json stdlib dependency for outgoing messages).

## [0.3.0] — 2026-05-06

M2 — subprocess lifecycle. Spawn cyrius-lsp (or any LSP server),
run the `initialize` handshake, send `initialized`, and tear down
cleanly via `shutdown` + `exit`. Verified end-to-end against the
real `cyrius-lsp` binary from the cyrius toolchain.

This is the first cyim-lsp version that actually talks to a
server. v0.2.0 shipped the framing primitives in isolation;
v0.3.0 wires them across the pipe boundary.

### Added

- **`src/subprocess.cyr`** (140 lines) — bidirectional-pipe
  primitives. `lsp_proc_spawn(cmd, arg1, arg2)` sets up two pipe
  pairs, forks, dup2's the child's halves to stdin/stdout, and
  execs. Returns a 32 B heap handle: `{pid, read_fd, write_fd,
  reserved}`. Companion API: `lsp_proc_send`, `lsp_proc_recv`,
  `lsp_proc_close` (idempotent — second close is a no-op),
  `lsp_proc_kill` (SIGTERM for v0.5.0+ `:lsp-restart`).
- **Real `lsp_client_start(cmd_path)` / `lsp_client_stop()`** in
  `src/lsp_client.cyr` (replaces v0.1.0 stubs). Start spawns the
  server, runs `initialize` request → response → `initialized`
  notification. Stop runs `shutdown` request → response → `exit`
  notification → `sys_waitpid`.
- **`_lsp_recv_frame`** (internal) — accumulating frame reader.
  Calls `lsp_proc_recv` in a loop, feeds each batch to
  `jsonrpc_parse_frame`, returns the buffer when a complete frame
  is parsed. 8 KB cap (handles initialize / shutdown responses;
  v0.4.0+ may grow for publishDiagnostics on large files).
- **`_lsp_send_all`** (internal) — handles short writes by
  looping until all bytes sent.
- **`lsp_client_describe()`** now renders `cyrius-lsp pid=<n>` or
  `(not attached)` based on actual state. Inline itoa mirrors
  cyim's trailing_ws status_segment pattern.
- **`tests/subprocess.tcyr`** (90 lines, 15 assertions across 8
  groups). Uses `/bin/cat` as a portable LSP-shaped mock — stdin
  → stdout pass-through. Tests: spawn returns valid handle, pid
  > 0, send/recv round-trip, multi-write multi-read, close reaps
  + marks pid -1, idempotent close, send/recv on closed proc
  returns -1, exec failure on bad cmd produces EOF on recv.

### Changed

- **`cyrius.cyml`** `[lib].modules` order: `jsonrpc.cyr →
  subprocess.cyr → lsp_client.cyr → plugin_init.cyr`. subprocess
  inserted between jsonrpc and lsp_client (lsp_client consumes
  subprocess primitives plus jsonrpc framing helpers).
- **`src/main.cyr`** standalone driver: smoke output now reads
  "cyim-lsp 0.3.0 (subprocess + framing)" and reports the
  current `lsp_client_describe()` output (which is `(not
  attached)` until something starts the client).

### Tests

- `cyrius test` — 4 suites (was 3): `tests/cyim-lsp.tcyr` 2,
  `tests/jsonrpc.tcyr` 21, **`tests/subprocess.tcyr` 15** (new),
  `src/test.cyr` 3. Total 41 assertions, all PASS.
- `cyrius fuzz` — 1 harness (jsonrpc parse_frame) PASS unchanged.
- `cyrius lint` — 0 warnings.
- **Real-server handshake verified locally** (not in CI suite):
  spawned `/home/macro/.cyrius/bin/cyrius-lsp`, completed
  initialize → initialized → shutdown → exit. Server logged
  `[cyrius-lsp] initialized` and `[cyrius-lsp] shutdown`
  cleanly. Not run in CI yet because cyrius-lsp isn't always
  on PATH there; v0.4.0+ adds a CI integration test that
  guards `cyrius-lsp` availability.

### Notes

- **Plugin behaviour is still no-op at v0.3.0.** The hooks
  registered by `cyim_lsp_init()` in `src/plugin_init.cyr` are
  the same v0.1.0 stubs — they don't yet call
  `lsp_client_start`. M3 / v0.4.0 wires the hooks: post_save →
  textDocument/didSave, post_change → textDocument/didChange,
  ex_command `:lsp-restart` → stop+start, etc.
- **Single-server design**. cyim-lsp v0.x supports one LSP
  subprocess per cyim process. Multi-server orchestration is
  post-v1.0 per the roadmap "Out of scope".
- **Frame size cap is 8 KB.** initialize / shutdown responses
  are well under this; publishDiagnostics on large files may
  exceed. Wrap-and-grow lands when the v0.5.0 diagnostic-pump
  surfaces it.
- **dist/cyim-lsp.cyr** grew 372 → 742 lines (v0.2.0 → v0.3.0).
  subprocess.cyr (~140) + lsp_client.cyr extensions (~230) account
  for the delta.

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
