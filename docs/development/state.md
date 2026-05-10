# cyim-lsp — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**1.4.0** — `lsp_ref_preview(uri, line, max_chars)` shipped 2026-05-09. Source-line previews in the `:lsp-find-refs` quickfix picker. Second real `[lib]` bundle source change in the 1.x line (after 1.2.1's `lsp_uri_decode`). Public helper in `src/lsp_position.cyr` reads the file via `file_read_all` (1 MiB cap; bigger files fall back to no-preview), walks to line N (0-indexed, LSP wire convention), strips leading whitespace and trailing CR, caps at caller-controlled `max_chars`. Reference glue's `_cyim_lsp_label_for_ref` formatter appends the snippet after `filename:line:col` separated by two spaces. Cut as a minor per ADR 0001's freeze envelope (additive symbol). 14 new test assertions; 210 total. Distfile 2305 → 2425 lines (+120 = `lsp_ref_preview` body + header). Closes the "reference previews" carry-over from cyim's 1.5.x deferred polish list — cyim 1.6.5 picks up.

**1.3.0** — Toolchain pin bump cyrius `5.9.16` → `5.10.10` shipped 2026-05-09. Catch-up cut mirroring cyim's 1.6.1 toolchain move. Pure pin change — no `[lib]` source modifications, no example-glue changes, no protocol or behaviour delta. Cut as a minor (1.2.x → 1.3.0) because consumers pinning cyim-lsp need to know the toolchain expectation moved (same convention vyakarana followed at its 2.2.0 cut). cyim's 1.6.1 already moved cyim-lsp's `[package].cyrius` value in-tree; 1.3.0 publishes that as a tag so cyim 1.6.3 can consume via `[deps.cyim-lsp].tag = "1.3.0"`. Distfile regenerated under 5.10.10 — 2305 lines (banner-only delta vs 1.2.1; no symbol changes). All gates green: 7 test suites / 196 assertions / 1 fuzz / 10 src files lint-clean (per-file iteration, fix mirrored from cyim 1.6.2's lint-correctness pass).

**1.2.1** — `lsp_uri_decode(uri)` shipped 2026-05-07. First
real `[lib]` bundle source change since 1.0.3 — closes cyim's
F-CO-4 closeout finding (URL-encoded `file://` URIs failed
cross-file goto-def / refs quickfix). Public helper in
`src/lsp_position.cyr`; reference glue in
`docs/examples/cyim_glue.cyr` calls it from the cross-file
branches. 16 new test assertions; 190 total. Distfile 2228 →
2305 lines (+77).

**1.2.0** — `:lsp-find-refs` / `gr` becomes a navigable quickfix
picker shipped 2026-05-07. `[lib]` bundle source unchanged across
1.0–1.2 series; dist regenerated with 1.2.0 banner.
`docs/examples/cyim_glue.cyr` now consumes cyim 1.5.0's
`plugin_list_display` ABI: rewritten `_cyim_lsp_ex_find_refs`
parses the response into parallel `(uri, line, char)` vecs,
builds `filename:line:col` labels, and displays the picker.
on_select loads the file via `plugin_buf_load_file` and
`buf_move`s to the destination. Empty-result case still surfaces
a status message. Minimum cyim version: **1.5.0**. URL-encoded
URIs + reference previews + open-in-split remain deferred (cyim
1.6+ work).

**1.1.0** — Reference glue activates cyim 1.4.2 ABIs shipped
2026-05-07. `[lib]` bundle source unchanged; dist regenerated
with new banner. `docs/examples/cyim_glue.cyr` now consumes
`plugin_register_normal_prefix_key` (binds `gd` / `gr`) and
`plugin_buf_load_file` (cross-file goto-def). cyim 1.4.3+ picks
this up; cyim 1.4.2 is the minimum host version. URL-encoded
paths in URIs and the find-refs quickfix list remain deferred
(quickfix awaits cyim 1.5.0's `plugin_list_display`).

**1.0.3** — Subprocess env passthrough shipped 2026-05-07.
`_lsp_proc_exec` now populates `envp` from `/proc/self/environ`
so children inherit cyim's full environment. Fixes the broken
`/usr/bin/env cyrius-lsp` lookup that v1.0.0–v1.0.2's empty
envp caused. Surfaced by cyim 1.4.1's `tests/smcyr/lsp_fold.smcyr`
end-to-end smoke. Audit doc § 5 framing corrected (envp scope
isn't a command-injection defense — argv hygiene is, unchanged).
174 assertions still PASS, fuzz/lint clean. Distfile +65 lines
(2163 → 2228) for the new helper.

**1.0.2** — Bundle shape correction shipped 2026-05-07. The v1.0.0
freeze listed `cyim_lsp_init()` and the six hook callbacks as
frozen `[lib]` exports; they were never viable bundle exports
(unresolved cyim-side symbol refs). v1.0.2 moves them out to
consumer-side glue (`docs/examples/cyim_glue.cyr`),
parameterizes `lsp_position.cyr` and `lsp_documents.cyr` to take
flat `(content_ptr, content_len)` instead of cyim buffer
handles, and renames the public position/path helpers without
the underscore prefix. See ADR 0001's v1.0.2 amendment.

**1.0.1** — Audit-finding repairs (F-1/F-2/F-3 defense-in-depth).

**1.0.0** — Public API freeze (broken; see 1.0.2 above).

**0.7.0** — M7 (closeout audit). 30-function dead-code floor
recorded; security re-scan clean.

**0.6.0** — M6 (navigation) shipped 2026-05-06. Ex-commands
`:lsp-goto-def` and `:lsp-find-refs`. Synchronous request/
response helper. Position conversions.

**0.5.1** — M5 (inline diag highlighting) shipped 2026-05-06.

**0.5.0** — M4 (diagnostics counts).

**0.4.0** — M3 (document sync).

**0.3.0** — M2 (subprocess lifecycle).

**0.2.0** — M1 (JSON-RPC framing).

**0.1.0** — scaffolded.

## Toolchain

- **Cyrius pin**: `5.9.16` (in `cyrius.cyml [package].cyrius`)
- **cyim ABI target** (consumer-side glue): cyim 1.3.6 / [ADR 0004](https://github.com/MacCracken/cyim/blob/main/docs/adr/0004-plugin-abi-freeze.md)
  (frozen surface — stable across cyim 1.x). The bundle itself
  has no cyim version coupling; only `docs/examples/cyim_glue.cyr`
  references the cyim plugin ABI.

## Source

**[lib] bundle modules** (in dependency order):

- `src/jsonrpc.cyr` — JSON-RPC framing. Public:
  `jsonrpc_version`, `jsonrpc_next_id`,
  `jsonrpc_build_notification`, `jsonrpc_build_request`,
  `jsonrpc_parse_frame`.
- `src/subprocess.cyr` — bidirectional-pipe primitives. Public:
  `lsp_proc_spawn`, `lsp_proc_send`, `lsp_proc_recv`,
  `lsp_proc_close` (idempotent), `lsp_proc_kill`, `lsp_proc_pid`,
  `lsp_proc_set_nonblock`, `lsp_proc_recv_nb`. 32 B handle struct;
  two pipe pairs for bidirectional traffic.
- `src/lsp_diags.cyr` — publishDiagnostics walker. Public:
  `lsp_diags_handle_frame`, `lsp_diags_lookup`, `lsp_diags_count`,
  `lsp_diags_format_status`, `lsp_diags_entry_count`,
  `lsp_diags_entry_tuple`, `lsp_diag_tuple_line/severity/msg`.
  Defines `_lsp_diags_find` / `_lsp_diags_count_pattern` /
  `_lsp_diag_parse_int` / `_lsp_diag_parse_string` (used by
  lsp_position too).
- `src/lsp_client.cyr` — LSP protocol client. Public:
  `lsp_client_start(cmd_path)`, `lsp_client_start_default()`,
  `lsp_client_stop`, `lsp_client_running`, `lsp_client_proc`,
  `lsp_client_describe`. Internal: `_lsp_initialize`,
  `_lsp_shutdown_handshake`, `_lsp_recv_frame` (16 KB cap),
  `_lsp_send_all`, `_lsp_drain_frames`, `_lsp_request_sync`.
- `src/lsp_state.cyr` — per-buffer state vec of 32 B entries
  `{buf_ptr (opaque key), version, opened, uri}`. Linear lookup.
  Public: `lsp_state_init/lookup/create/bump_version/mark_opened/
  is_opened/version/uri/buf/count`.
- `src/lsp_position.cyr` — line↔char/offset on flat (ptr, len).
  Public: `lsp_pos_offset_to_lc`, `lsp_pos_lc_to_offset`,
  `lsp_pos_extract_uri`, `lsp_pos_extract_first_line`,
  `lsp_pos_extract_first_character`. v1.0.2: parameterized to
  take `(content, content_len)` instead of opaque `b`; renamed
  to drop underscore prefix.
- `src/lsp_documents.cyr` — didOpen/didChange/didSave/nav senders.
  Public: `lsp_content_to_json_string`, `lsp_path_to_uri`,
  `lsp_path_is_cyr`, `lsp_doc_lazy_start`, `lsp_doc_send_did_open`,
  `lsp_doc_send_did_change`, `lsp_doc_send_did_save`,
  `lsp_nav_request_sync`, `lsp_streq`. Internal: builders
  (`_lsp_doc_build_*`, `_lsp_nav_build_params`), helpers
  (`_lsp_jesc_byte`, `_lsp_doc_itoa`, `_lsp_append`). v1.0.2:
  no consumer-side refs; previous editor-facing handlers
  (`lsp_doc_did_change(s)`, etc.) moved to consumer glue.

**[build] entry**:

- `src/main.cyr` — standalone driver (NOT in `[lib].modules`;
  for ad-hoc smoke / framing tests without cyim).
- `src/test.cyr` — `cyrius test` smoke (3 assertions).
- `src/version_str.cyr` — auto-generated from `VERSION` by
  `scripts/version-bump.sh`.

**Consumer-side reference glue (NOT in [lib], NOT shipped to
consumers as code — copied verbatim into the consumer's tree):**

- `docs/examples/cyim_glue.cyr` — cyim's reference glue. Hooks,
  ex-commands, buffer materialization, response handling.
- `docs/examples/README.md` — explains the consumer-side
  fold-in pattern.

## Build artifacts

- `build/cyim-lsp` — standalone driver binary
- `dist/cyim-lsp.cyr` — bundled distfile, **2163 lines** (v1.0.2),
  produced by `cyrius distlib`. Verified to contain zero
  references to cyim-side symbols (`editor_*`, `buf_get`,
  `buf_len`, `plugin_register_*`, `DIAG_*`, `ACT_NONE`,
  `diag_new`). cyim consumes via `include "lib/cyim-lsp.cyr"`
  after `cyrius deps` resolves the plugin entry.

## Tests

- `src/test.cyr` (`[build].test`) — 3 assertions (smoke) PASS
- `tests/cyim-lsp.tcyr` — 2 assertions (scaffold smoke) PASS
- `tests/jsonrpc.tcyr` — 24 assertions (framing + F-1) PASS
- `tests/subprocess.tcyr` — 15 assertions (/bin/cat round-trip) PASS
- `tests/lsp_diags.tcyr` — 47 assertions (counts + tuples + F-2) PASS
- `tests/lsp_position.tcyr` — 38 assertions (positions + Location parser) PASS
- `tests/lsp_documents.tcyr` — 48 assertions (escape, builders, content_to_json,
  state, lsp_streq) PASS — was 39 at v1.0.1; v1.0.2 added
  `lsp_content_to_json_string`, `_lsp_nav_build_params`,
  `lsp_streq` coverage.
- `cyrius test` — **174 assertions all PASS** (was 171 at v1.0.1).
- `fuzz/jsonrpc.fcyr` — random byte feeder; 5000 buffers PASS.
- `cyrius lint src/*.cyr` — 0 warnings across all 9 src files.
- **Real-server handshake (manual, not CI):** spawned
  `/home/macro/.cyrius/bin/cyrius-lsp` from a one-off harness;
  observed `[cyrius-lsp] initialized` then `[cyrius-lsp]
  shutdown` cleanly.

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — `syscalls`, `alloc`, `fmt`, `io`, `string`, `str`,
  `vec`, `assert`, `json`, `process`

## Consumers

| Consumer | Status |
|---|---|
| cyim 1.5.3+ | **planned pickup** — the cyim-lsp 1.2.1 release adds `lsp_uri_decode` to the bundle. cyim 1.5.3 picks it up + closes F-CO-4 (URL-decode for `file://` URIs). |
| cyim 1.5.1 / 1.5.2 | shipped against cyim-lsp 1.2.0; gd/gr/refs-quickfix all work but URL-encoded paths fail. Upgrade path: bump `[deps.cyim-lsp].tag` to 1.2.1 + sync `src/plugins/lsp_glue.cyr` cross-file branches to use `lsp_uri_decode`. |
| cyim 1.4.3 / 1.5.0 | shipped against cyim-lsp 1.1.0 reference glue (gd/gr keymap + cross-file goto-def; refs surface only count in status bar). |
| cyim 1.4.0–1.4.2 | shipped against cyim-lsp 1.0.2/1.0.3 reference glue (gd/gr stubs; cross-file deferred). |
| cyim 1.3.x | not applicable (no plugin pickup). |

## Next

cyim 1.4.0 fold-in is the next work — copy
`docs/examples/cyim_glue.cyr` into cyim's tree, wire
`cyim_lsp_init()` into cyim's `main()` after `plugin_init()`,
add `[plugins.cyim-lsp]` to cyim's `cyrius.cyml` pulling
v1.0.2's tag.

Beyond cyim 1.4.0 fold-in: cross-file definition jumps
(needs cyim's `plugin-buf-load-file` ABI extension); reference
quickfix list (needs cyim's `plugin-list-display` ABI); `gd` /
`gr` keymap dispatch (needs cyim's `plugin-prefix-keymap`).
None of these affect the bundle — all are consumer-glue
extensions once cyim's ABI grows.
