# cyim-lsp examples

Reference glue files for consumers folding cyim-lsp into their
own translation unit.

## Why glue is consumer-side

The cyim-lsp `[lib]` bundle (`dist/cyim-lsp.cyr`, produced by
`cyrius distlib`) is **self-contained**: every symbol resolves
against the bundle's own modules + cyrius stdlib, with no
references to consumer-side editor symbols. This is the
sandhi-pattern done correctly — the bundle drops cleanly into
any consumer's TU without polluting downstream test builds.

Consumers provide a glue file that:

1. Reads editor state via the host's plugin ABI
2. Materializes buffer content into a flat `(content_ptr, content_len)`
3. Calls into cyim-lsp's pure-protocol API (`lsp_doc_send_*`,
   `lsp_nav_request_sync`, `lsp_pos_*`, `lsp_diags_*`)
4. Parses responses and writes back via the host's editor-state
   setters

This file replaces the v1.0.0–v1.0.1 design where
`src/plugin_init.cyr` lived inside `[lib].modules` and contained
unresolved references to cyim-side symbols. That design broke
narrow consumer test builds and was corrected in
[`docs/adr/0001-api-freeze.md`](../adr/0001-api-freeze.md)'s
1.0.2 amendment.

## Files

- [`cyim_glue.cyr`](cyim_glue.cyr) — reference glue for cyim.
  Copy into cyim's `src/plugins/lsp_glue.cyr` (or equivalent)
  and include from cyim's `src/main.cyr` after
  `include "lib/cyim-lsp.cyr"`.

## Other consumers

A hypothetical second consumer (an editor for the AGNOS shell,
say) would write its own glue file referencing its own host ABI.
The bundle stays the same; only the glue changes.
