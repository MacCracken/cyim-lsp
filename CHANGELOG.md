# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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
