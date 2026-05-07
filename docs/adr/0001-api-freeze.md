# 0001 — Public API freeze at v1.0.0

**Status**: Accepted
**Date**: 2026-05-06

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
