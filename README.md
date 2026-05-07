# cyim-lsp

LSP client plugin for [cyim](https://github.com/MacCracken/cyim).
Spawns [`cyrius-lsp`](https://github.com/MacCracken/cyrius/blob/main/programs/cyrius-lsp.cyr)
as a subprocess, frames JSON-RPC over pipes, and routes diagnostics
/ didSave / didChange / definition / references through cyim's
plugin ABI.

Written in [Cyrius](https://github.com/MacCracken/cyrius).

## Status

**v0.1.0 — scaffold release.** Project structure, plugin ABI
consumer wiring (`cyim_lsp_init()`), and JSON-RPC stub helpers.
The plugin registers no-op callbacks for all six cyim hook types
so cyim 1.4.0 can land a working `[plugins.cyim-lsp]` entry; the
real LSP behaviour (subprocess spawn, JSON-RPC roundtrip, protocol
handlers) lands at v0.2.0+.

Pinned against cyim's plugin ABI as frozen in
[cyim ADR 0004](https://github.com/MacCracken/cyim/blob/main/docs/adr/0004-plugin-abi-freeze.md).

## How cyim consumes this plugin

cyim's `cyrius.cyml` adds:

```toml
[plugins.cyim-lsp]
git = "https://github.com/MacCracken/cyim-lsp.git"
tag = "0.1.0"
modules = ["dist/cyim-lsp.cyr"]
```

cyim's `src/main.cyr` adds:

```cyrius
include "lib/cyim-lsp.cyr"
```

and calls `cyim_lsp_init()` from `main()` after `plugin_init()`.

The bundled `dist/cyim-lsp.cyr` is concatenated by `cyrius distlib`
from the `[lib].modules` listed in `cyrius.cyml` (jsonrpc.cyr +
lsp_client.cyr + plugin_init.cyr in dependency order).

## Build / test (standalone)

```sh
cyrius deps                                  # resolve stdlib deps
cyrius build src/main.cyr build/cyim-lsp     # compile standalone driver
build/cyim-lsp                               # smoke output
cyrius test                                  # run [build].test + tests/*.tcyr
cyrius distlib                               # produce dist/cyim-lsp.cyr
```

The standalone driver exists for ad-hoc smoke + JSON-RPC framing
tests without needing cyim. The actual plugin shipping happens
via the distlib bundle.

## Hook surface (frozen at cyim 1.3.6)

| LSP feature | cyim hook | cyim-lsp callback |
|---|---|---|
| `textDocument/didSave` | `post_save_hook` | `_cyim_lsp_post_save` |
| `textDocument/didChange` | `post_change_hook` | `_cyim_lsp_post_change` |
| diagnostic count summary | `status_segment` | `_cyim_lsp_status_segment` |
| `publishDiagnostics` | `diagnostic_provider` | `_cyim_lsp_diagnostic_provider` |
| `:lsp-restart` / `:lsp-status` | `ex_command` | `_cyim_lsp_ex_restart` / `_cyim_lsp_ex_status` |
| `gd` (definition) / `gr` (references) | `normal_key` | `_cyim_lsp_gd` / `_cyim_lsp_gr` |

All callbacks are no-op stubs at v0.1.0. v0.2.0 fills them in.

## License

GPL-3.0-only
