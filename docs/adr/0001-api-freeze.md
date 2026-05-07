# 0001 — Public API freeze at v1.0.0

**Status**: Accepted (with v1.0.2 amendment — see end)
**Date**: 2026-05-06 (amended 2026-05-07)

> **2026-05-07 amendment**: the v1.0.0 freeze listed
> `cyim_lsp_init()` and the six hook callbacks as frozen bundle
> exports. They were never viable bundle exports — they reference
> consumer-side editor symbols that don't resolve in any
> compilation unit not built atop cyim. The 1.0.2 amendment
> moves them out of the frozen surface entirely (they live in
> `docs/examples/cyim_glue.cyr` as reference glue, copied
> verbatim into the consumer's own tree). The bundle is now
> genuinely self-contained — every symbol resolves against
> the bundle + cyrius stdlib. Position helpers are also
> reparameterized to take flat `(content_ptr, content_len)`
> instead of an opaque `b` handle. **Skip to the
> [v1.0.2 amendment](#v102-amendment-2026-05-07)** for the
> as-shipped frozen surface.

## Context

cyim-lsp is the LSP-client plugin for cyim — the first
non-trivial plugin in the cyim ecosystem and the proving ground
for the Cyrius plugin sandhi pattern (cyim ADR 0003 / 0004).
v0.1.0 → v0.7.0 walked through:

- M0 scaffold (v0.1.0)
- M1 JSON-RPC framing (v0.2.0)
- M2 subprocess lifecycle (v0.3.0)
- M3 document sync — didOpen / didChange / didSave (v0.4.0)
- M4 diagnostics — counts via status_segment (v0.5.0)
- M5 inline diag highlighting via diagnostic_provider (v0.5.1)
- M6 navigation — :lsp-goto-def / :lsp-find-refs (v0.6.0)
- M7 closeout — audit + dead-code floor + security re-scan (v0.7.0)

cyim 1.4.0's milestone is "first non-trivial plugin folded in"
— picking up cyim-lsp via cyim's `[plugins.cyim-lsp]` block in
cyrius.cyml + `include "lib/cyim-lsp.cyr"` + `cyim_lsp_init()`
call. To pin cyim 1.4.0 against a stable contract rather than a
moving v0.x target, cyim-lsp v1.0.0 freezes the public surface.

The same pattern niyama 1.0.0 followed: ship a v1.0.0 with an
explicit ABI freeze, then patches accrete forward without
breaking consumers.

## Decision

The cyim-lsp public ABI surface — function names, parameter
signatures, struct layouts, ex-command names — listed below is
**frozen** at v1.0.0. Within the cyim-lsp 1.x series:

- **No backwards-incompatible changes.** Code (cyim's main.cyr,
  or any future plugin author / consumer) compiling against the
  v1.0.0 ABI continues to compile and run semantically unchanged
  against any later 1.x patch / minor.
- **Additions are allowed.** New ex-commands, new internal
  helpers, new severity levels (appended after `DIAG_*` in cyim
  ADR 0004's enum) may land in 1.x patches.
- **Breaking changes require a major-version bump** (cyim-lsp
  2.x). cyim-lsp 2.0 may rename, retype, or remove any frozen
  symbol; intermediate 1.x releases may not.

## Frozen surface

### Plugin entry point

```cyrius
fn cyim_lsp_init() -> 0
```

Called once from cyim's `main()` after `plugin_init()` (and any
other `<plugin>_init()` calls). Registers all six callbacks
against cyim's plugin ABI via `plugin_register_*` (cyim ADR
0004). Idempotent in the sense that calling twice
double-registers — main is the one source of truth.

### Hooks registered

cyim-lsp registers callbacks for cyim's plugin hook surface
(cyim ADR 0004):

| cyim hook | cyim-lsp callback | Behaviour |
|---|---|---|
| `post_save_hook` | `_cyim_lsp_post_save` | textDocument/didSave |
| `post_change_hook` | `_cyim_lsp_post_change` | textDocument/didChange |
| `status_segment` | `_cyim_lsp_status_segment` | "E:N W:M I:K H:L" diag count |
| `normal_key 'g' / 'd'` | `_cyim_lsp_gd` (stub at v1.0.0) | Reserved; activates when cyim's prefix-keymap ABI lands |
| `normal_key 'g' / 'r'` | `_cyim_lsp_gr` (stub at v1.0.0) | Reserved; activates when cyim's prefix-keymap ABI lands |
| `ex_command lsp-restart` | `_cyim_lsp_ex_restart` | Kill + respawn server |
| `ex_command lsp-status` | `_cyim_lsp_ex_status` | Print pid + describe |
| `ex_command lsp-goto-def` | `_cyim_lsp_ex_goto_def` | textDocument/definition + cursor jump (same-file) |
| `ex_command lsp-find-refs` | `_cyim_lsp_ex_find_refs` | textDocument/references + count in status |
| `diagnostic_provider` | `_cyim_lsp_diagnostic_provider` | Push per-line diags via `diag_new()` |

### Public client API

Symbols that cyim-side code (or future plugin internals) may
call. All in `src/lsp_client.cyr` unless noted.

```cyrius
lsp_client_running()                  -> i64 pid (0 if not attached)
lsp_client_proc()                     -> proc ptr (or 0)
lsp_client_describe()                 -> cstring  ("(not attached)" or "cyrius-lsp pid=N")
lsp_client_start(cmd_path)            -> 0 / -1
lsp_client_start_default()            -> 0 / -1   (uses /usr/bin/env cyrius-lsp)
lsp_client_stop()                     -> 0
```

### JSON-RPC framing API (lsp_client / jsonrpc.cyr)

```cyrius
jsonrpc_version()                                          -> "2.0"
jsonrpc_next_id()                                          -> i64
jsonrpc_build_notification(method, params)                 -> framed cstring
jsonrpc_build_request(id, method, params)                  -> framed cstring
jsonrpc_parse_frame(buf, len, off_out, len_out)            -> 1 / 0 / -1
```

### Subprocess primitives (subprocess.cyr)

```cyrius
lsp_proc_spawn(cmd, arg1, arg2)                            -> proc handle or 0
lsp_proc_pid(proc)                                         -> pid or -1
lsp_proc_send(proc, buf, len)                              -> bytes / -1
lsp_proc_recv(proc, buf, max)                              -> bytes / 0 (EOF) / -1
lsp_proc_recv_nb(proc, buf, max)                           -> bytes / 0 / -1 / -2 (EAGAIN)
lsp_proc_close(proc)                                       -> 0 / -1
lsp_proc_kill(proc)                                        -> sys_kill rc
lsp_proc_set_nonblock(proc)                                -> 0 / -1
```

Proc handle layout (32 B; frozen):

```text
+0   pid           (i64; -1 = closed)
+8   read_fd       (parent reads child stdout)
+16  write_fd      (parent writes to child stdin)
+24  reserved
```

### Diagnostic state (lsp_diags.cyr)

```cyrius
lsp_diags_init()                                            -> 0
lsp_diags_handle_frame(body, body_len)                      -> 1 (handled) / 0
lsp_diags_lookup(uri)                                       -> entry ptr / 0
lsp_diags_count(entry, severity)                            -> i64
lsp_diags_entry_count(entry)                                -> i64
lsp_diags_entry_tuple(entry, idx)                           -> tuple ptr / 0
lsp_diag_tuple_line(t)                                      -> i64
lsp_diag_tuple_severity(t)                                  -> i64 (LSP 1..4)
lsp_diag_tuple_msg(t)                                       -> cstring
lsp_diags_format_status(entry, out_buf, cap)                -> bytes written
```

Per-URI entry layout (48 B; frozen):

```text
+0   uri_ptr        (NUL-term cstring)
+8   count_error    (severity 1)
+16  count_warning  (severity 2)
+24  count_info     (severity 3)
+32  count_hint     (severity 4)
+40  diag_vec       (vec<tuple_ptr> or 0)
```

Per-diag tuple layout (24 B; frozen):

```text
+0   line           (1-indexed)
+8   severity       (LSP 1..4)
+16  msg_ptr        (NUL-term cstring)
```

### Document state (lsp_state.cyr)

```cyrius
lsp_state_init()                                            -> 0
lsp_state_lookup(b)                                         -> entry / 0
lsp_state_create(b, uri)                                    -> entry / 0
lsp_state_bump_version(entry)                               -> new version
lsp_state_mark_opened(entry)                                -> 0
lsp_state_is_opened(entry)                                  -> 0/1
lsp_state_version(entry)                                    -> i64
lsp_state_uri(entry)                                        -> cstring
lsp_state_buf(entry)                                        -> buf ptr
lsp_state_count()                                           -> i64
```

### Document handlers (lsp_documents.cyr)

```cyrius
lsp_doc_did_change(s)                                       -> 0
lsp_doc_did_save(s, path)                                   -> 0
lsp_nav_goto_def(s)                                         -> 0 / -1
lsp_nav_find_refs(s)                                        -> 0 / -1
```

### Position helpers (lsp_position.cyr)

```cyrius
_lsp_pos_offset_to_lc(b, off, line_out, char_out)           -> 0
_lsp_pos_lc_to_offset(b, line, character)                   -> i64
_lsp_pos_extract_uri(body, blen)                            -> cstring / 0
_lsp_pos_extract_first_line(body, blen)                     -> i64 / -1
_lsp_pos_extract_first_character(body, blen)                -> i64 / -1
```

(Underscore prefix is consumer-facing in cyim-lsp's convention
since these helpers cross module boundaries; v2.x can rename to
drop the underscore but v1.x keeps the name stable.)

## Compatibility envelope

**Stable across cyim-lsp 1.x:**

- Every symbol listed above (function names + signatures)
- Every struct layout listed above
- Ex-command names (`:lsp-restart`, `:lsp-status`,
  `:lsp-goto-def`, `:lsp-find-refs`)
- Hook callback shapes (cyim ADR 0004 frozen)
- LSP severity numeric values (1=error..4=hint)

**Subject to expansion (additions only):**

- New ex-commands (must be `:lsp-*` prefixed)
- New helper functions in any module
- New severity levels appended after LSP hint (would require LSP
  spec evolution)
- Cross-file definition jumps (deferred at v1.0.0; landing as
  cyim 1.4.x ABI lands)
- Reference quickfix list (deferred at v1.0.0; landing as cyim's
  list-display ABI lands)

**Reserved for cyim-lsp 2.x:**

- Renaming or removing any frozen symbol
- Reordering struct fields
- Multi-server orchestration (currently one cyrius-lsp per cyim
  process)

## Consequences

### Positive

- **cyim 1.4.0 picks up a frozen contract.** No risk of
  cyim-lsp 1.x breaking cyim's pickup.
- **Future plugin authors targeting the same shape** (other LSP
  servers, diagnostic providers, etc.) can build against
  cyim-lsp 1.x's surface without ABI surprises.
- **Closes the v0.x flux.** v0.5.1 had to renumber milestones
  (M5 → M5b/M6) when "inline diag highlighting" inserted
  between v0.5.0 and v0.6.0. v1.x sequences cleanly.

### Negative

- **2.x is forever distant.** Any v1.0.0 ABI mistake we missed
  surfaces only via parallel APIs / workaround helpers until
  the 2.0 cut.
- **Hook expansion still requires cyim-side ABI work.** `gd`/
  `gr` keymaps, cross-file jumps, reference list — all gated
  on cyim adding plugin-prefix-keymap, plugin-buf-load-file,
  and plugin-list-display ABI surfaces.

### Neutral

- **The freeze is documented, not mechanically enforced.** No
  CI gate validates that the symbol set hasn't drifted.
  cyim-lsp's tests cover behaviour but not symbol-set
  stability. A future ADR could add an api-surface snapshot
  similar to cyrius's own.

## Alternatives considered

### A. Defer the freeze to v1.5.0+ (after several real consumers)

Argument: cyim 1.4.0 is the only consumer at v1.0.0 ship time.
Wait until ≥2 consumers have battle-tested the surface before
freezing.

**Rejected because:** cyim 1.4.0 is a meaningful first
consumer — the milestone the cyim project has been building
toward through 1.3.x. Pinning cyim 1.4.0 against a v0.x flux
forces synchronised bumps. The v0.7.0 closeout pass
(audit + dead-code review + security re-scan) gives high
confidence the v1.0.0 surface is right.

### B. Freeze a smaller subset (only the cyim-side ABI cyim 1.4.0 calls)

Argument: cyim 1.4.0 only calls `cyim_lsp_init()` and the
registered hooks; everything else (subprocess primitives,
JSON-RPC builders) is internal-to-the-plugin. Freeze just the
cyim-facing surface.

**Rejected because:** future cyim-lsp consumers (e.g., a
test harness, a debugger frontend that re-uses subprocess.cyr's
spawn helpers, a third-party plugin that consumes our diag
state) deserve a frozen surface too. Partial freezes invite
"the line keeps moving" confusion. Either freeze the whole
public surface or none of it.

### C. Don't freeze; rely on convention

Argument: cyim-lsp lives in a single repo. Coordinated changes
across cyim 1.4.x and cyim-lsp 1.x are cheap.

**Rejected because:** even with coordinated changes, plugin-
author confidence matters. "Will my v1.0.0 plugin still
compile against cyim-lsp 1.2?" deserves a documented answer,
not "probably; ask MacCracken." The ADR is the documented
answer.

## v1.0.2 amendment (2026-05-07)

### What was wrong with v1.0.0

The original frozen surface listed `cyim_lsp_init()` and six
hook callbacks (`_cyim_lsp_post_save`, `_cyim_lsp_post_change`,
`_cyim_lsp_status_segment`, `_cyim_lsp_diagnostic_provider`,
`_cyim_lsp_gd`, `_cyim_lsp_gr`, plus the four `_cyim_lsp_ex_*`
ex-command callbacks) as part of `[lib].modules` —
`src/plugin_init.cyr` was bundled into `dist/cyim-lsp.cyr`.

Those symbols reference cyim-side ABI (`plugin_register_*`,
`editor_*`, `buf_*`, `diag_new`, `DIAG_*`, `ACT_NONE`) that
**only resolves inside cyim's own translation unit**. The same
problem extended to `lsp_documents.cyr` (which called
`editor_buf`, `editor_file_path`, `editor_cursor`,
`editor_set_status`, `editor_set_cursor`, `buf_get`, `buf_len`)
and `lsp_position.cyr` (which called `buf_get`, `buf_len`).

Three of seven [lib] modules contained unresolved cyim-side
references, which broke any cyim test target that built without
the full plugin chain in scope. cyim-lsp's *own* tests papered
over this with stub function definitions (`fn buf_get(b, i)
{ return 0; }` etc.) — but cyim's narrow tests like
`tests/buffer.tcyr` could not stub all of cyim's plugin surface,
so the v1.0.0 fold-in was structurally impossible.

The v1.0.0 freeze was never validated against its only declared
consumer (cyim 1.4.0). The first attempt to fold cyim-lsp 1.0.0
into cyim's compilation unit failed — and rather than fix
forward, the work was reverted.

### What v1.0.2 changes

The bundle is now **genuinely self-contained**: every symbol in
`dist/cyim-lsp.cyr` resolves against the bundle's own modules +
cyrius stdlib, with **zero references** to consumer-side editor
symbols. Verified via `grep` against the regenerated distfile
(zero matches for `editor_*`, `buf_get`, `buf_len`,
`plugin_register_*`, `DIAG_*`, `ACT_NONE`, `diag_new`).

**Removed from frozen surface** (these were never viable
bundle exports — moved to consumer-side glue):

| Symbol | Was at | Now at |
|---|---|---|
| `cyim_lsp_init()` | `src/plugin_init.cyr` | `docs/examples/cyim_glue.cyr` |
| `_cyim_lsp_post_save` | `src/plugin_init.cyr` | `docs/examples/cyim_glue.cyr` |
| `_cyim_lsp_post_change` | `src/plugin_init.cyr` | `docs/examples/cyim_glue.cyr` |
| `_cyim_lsp_status_segment` | `src/plugin_init.cyr` | `docs/examples/cyim_glue.cyr` |
| `_cyim_lsp_diagnostic_provider` | `src/plugin_init.cyr` | `docs/examples/cyim_glue.cyr` |
| `_cyim_lsp_gd` / `_cyim_lsp_gr` | `src/plugin_init.cyr` | `docs/examples/cyim_glue.cyr` |
| `_cyim_lsp_ex_*` (4) | `src/plugin_init.cyr` | `docs/examples/cyim_glue.cyr` |
| `lsp_doc_did_change(s)` | `src/lsp_documents.cyr` | `docs/examples/cyim_glue.cyr` |
| `lsp_doc_did_save(s, path)` | `src/lsp_documents.cyr` | `docs/examples/cyim_glue.cyr` |
| `lsp_nav_goto_def(s)` | `src/lsp_documents.cyr` | `docs/examples/cyim_glue.cyr` |
| `lsp_nav_find_refs(s)` | `src/lsp_documents.cyr` | `docs/examples/cyim_glue.cyr` |
| `_lsp_nav_request(s, ...)` | `src/lsp_documents.cyr` | `docs/examples/cyim_glue.cyr` |

**Renamed (underscore-prefix dropped — promoted to public API
since they cross module boundaries and have no internal-only
semantics):**

| v1.0.0–v1.0.1 | v1.0.2+ |
|---|---|
| `_lsp_pos_offset_to_lc(b, off, line_out, char_out)` | `lsp_pos_offset_to_lc(content, content_len, off, line_out, char_out)` |
| `_lsp_pos_lc_to_offset(b, line, character)` | `lsp_pos_lc_to_offset(content, content_len, line, character)` |
| `_lsp_pos_extract_uri(body, blen)` | `lsp_pos_extract_uri(body, blen)` |
| `_lsp_pos_extract_first_line(body, blen)` | `lsp_pos_extract_first_line(body, blen)` |
| `_lsp_pos_extract_first_character(body, blen)` | `lsp_pos_extract_first_character(body, blen)` |
| `_lsp_path_to_uri(path)` | `lsp_path_to_uri(path)` |
| `_lsp_path_is_cyr(path)` | `lsp_path_is_cyr(path)` |
| `_lsp_buf_to_json_string(b)` | `lsp_content_to_json_string(content, content_len)` |
| `_lsp_doc_lazy_start()` | `lsp_doc_lazy_start()` |

**New (added to frozen surface in v1.0.2 — pure-protocol
senders that take pre-extracted state):**

```cyrius
lsp_doc_send_did_open(entry, content, content_len)   -> 0/-1
lsp_doc_send_did_change(entry, content, content_len) -> 0/-1
lsp_doc_send_did_save(uri)                           -> 0/-1
lsp_nav_request_sync(uri, line, character, method, body_len_out) -> body_ptr/0
lsp_streq(a, b)                                      -> 0/1
```

### Why this is a 1.0.2 (not 2.0.0)

A frozen symbol that **cannot ever resolve** in a downstream
translation unit was never a real export. Removing
`cyim_lsp_init()` from `[lib]` is fixing the original misship,
not breaking a valid contract.

The pure-protocol surface (jsonrpc, subprocess, lsp_client,
lsp_state, lsp_diags, plus all `_lsp_*` helpers in
lsp_position and lsp_documents that don't reference cyim
symbols) WAS self-contained from day one. That subset is
preserved — the underscore-prefix rename and the parameter swap
on the position helpers are mechanically equivalent (single
call site fixup in consumer glue), and the additions are
strictly additive.

The "freeze covers what was actually self-contained from day
one" framing makes 1.0.2 honest. Calling this 2.0.0 would be
honoring a freeze that was a lie.

### Process consequence

Before any future API freeze, the closeout pass must include
**a fold-in dry-run against a real consumer** — not just
internal test compilation. The v0.7.0 closeout pass (audit +
dead-code + security re-scan) didn't catch this because the
bundle's own tests use stubs to satisfy compilation. A real
consumer can't stub.

The new closeout requirement: build cyim with
`include "lib/cyim-lsp.cyr"` and run cyim's own narrow test
targets. If they don't compile, the bundle isn't ready to
freeze.
