# cyim-lsp — Claude Code Instructions

> **Core rule**: this file is **preferences, process, and procedures** —
> durable rules that change rarely. Volatile state (current version,
> module line counts, supported backends, test counts, dep-gap status,
> consumers) lives in [`docs/development/state.md`](docs/development/state.md).
> Do not inline state here.

## Project Identity

**cyim-lsp** — LSP client plugin for cyim. Spawns `cyrius-lsp` as
a subprocess, frames JSON-RPC over pipes, and exposes a
self-contained pure-protocol bundle that cyim folds in via the
sandhi pattern. Consumer-side hook registration lives in cyim's
own glue file (reference: `docs/examples/cyim_glue.cyr`).

- **Type**: Plugin distfile (sandhi pattern). Standalone build is
  for ad-hoc smoke; production shipping is via `cyrius distlib` →
  `dist/cyim-lsp.cyr` → cyim's `include "lib/cyim-lsp.cyr"`.
- **License**: GPL-3.0-only
- **Language**: Cyrius (toolchain pinned in `cyrius.cyml [package].cyrius`)
- **Version**: `VERSION` at the project root is the source of truth
- **Consumes**: cyrius stdlib (`json`, `process`, etc. — see
  `cyrius.cyml [deps].stdlib`). The bundle has **zero references**
  to consumer-side editor symbols. Specific cyim ABI version that
  consumer-side glue targets lives in `docs/development/state.md`.
- **Spawns**: cyrius-lsp from the cyrius toolchain
  (`programs/cyrius-lsp.cyr`); JSON-RPC 2.0 over stdin/stdout
  pipes
- **Standards**: [First-Party Standards](https://github.com/MacCracken/agnosticos/blob/main/docs/development/applications/first-party-standards.md) · [First-Party Documentation](https://github.com/MacCracken/agnosticos/blob/main/docs/development/applications/first-party-documentation.md)

## Goal

cyim-lsp owns the **LSP-client surface** in the cyim ecosystem —
the bridge between cyim's modal editor and any LSP server (today:
cyrius-lsp). Plugins like this one are how cyim accretes
editor-adjacent functionality without expanding its core: per
cyim's [ADR 0003](https://github.com/MacCracken/cyim/blob/main/docs/adr/0003-cyrius-plugin-system.md),
plugins extend the dispatch table, never the modal grammar.

cyim-lsp is the **first non-trivial plugin** in the cyim
ecosystem, the proving ground for the sandhi-pattern composition
that future plugins (formatter wrappers, snippet engines, etc.)
will follow.

## Current State

> Volatile state lives in [`docs/development/state.md`](docs/development/state.md) —
> current version, surface area, in-flight work, consumers, dep gaps.
> Refreshed every release.

This file (`CLAUDE.md`) is durable rules.

## Scaffolding

Project was scaffolded with `cyrius init cyim-lsp` (2026-05-06).
**Do not manually create project structure** — use the tools.

## Plugin shape (sandhi pattern)

The `[lib].modules` bundle is **self-contained** — every symbol
resolves against the listed modules + cyrius stdlib, with zero
references to consumer-side editor symbols. This is the
sandhi-pattern done correctly per
[ADR 0001's v1.0.2 amendment](docs/adr/0001-api-freeze.md):
the bundle drops cleanly into any consumer's TU without
polluting downstream test builds.

```
src/jsonrpc.cyr        # Content-Length framing, message build/parse
src/subprocess.cyr     # pipe / fork / exec / dup2 primitives
src/lsp_diags.cyr      # publishDiagnostics walker, per-URI tuples
src/lsp_client.cyr     # LSP protocol (initialize, send, recv, drain)
src/lsp_state.cyr      # per-buffer state vec (uses opaque buf key)
src/lsp_position.cyr   # offset↔line/character on flat (ptr, len)
src/lsp_documents.cyr  # didOpen / didChange / didSave / nav senders
src/main.cyr           # standalone driver; NOT in [lib]
```

`cyrius distlib` concatenates `[lib].modules` from `cyrius.cyml`
into `dist/cyim-lsp.cyr` in dependency order. cyim's
`include "lib/cyim-lsp.cyr"` brings the bundle into cyim's
compilation unit at fold-in time. Consumer-side glue (cyim's
hook registration, buffer materialization, response handling)
lives in cyim's tree — see [`docs/examples/cyim_glue.cyr`](docs/examples/cyim_glue.cyr)
for the reference shape.

## Quick Start

```sh
cyrius deps                                  # resolve stdlib deps
cyrius build src/main.cyr build/cyim-lsp     # standalone driver
cyrius test                                  # smoke tests
cyrius distlib                               # produce dist/cyim-lsp.cyr
```

## Key Principles

- **The bundle is self-contained.** Every symbol in
  `[lib].modules` resolves against the bundle + cyrius stdlib,
  with zero references to consumer-side editor symbols. If a
  feature requires an editor-state read or write, that code
  belongs in consumer-side glue (`docs/examples/cyim_glue.cyr`),
  not the bundle. This is the load-bearing constraint that lets
  the bundle drop into any consumer's TU.
- **The cyim plugin ABI is consumed by glue, not by the bundle.**
  Consumer-side glue calls `plugin_register_*` / `editor_*` /
  `buf_*` per cyim's ADR 0003 / 0004. Specific cyim version
  targeted lives in `docs/development/state.md`.
- **Plugins extend the dispatch table, never the modal grammar.**
  Per cyim ADR 0003 — built-ins always win on conflict for
  keyed hooks (normal_key, ex_command); plugin lookup is reached
  only after the built-in misses.
- **Correctness over cleverness** — if it's wrong, the bugs own you
- Test after every change, not after the feature is "done"
- ONE change at a time — never bundle unrelated changes
- Build with `cyrius build`, not raw `cat file | cc5` — the
  manifest auto-resolves deps and prepends includes
- Source files only need project includes — stdlib / external
  deps auto-resolve from `cyrius.cyml`
- Every buffer declaration is a contract: `var buf[N]` = N
  **bytes**, not N entries
- `&&` / `||` short-circuit; mixed expressions require explicit
  parens

## Rules (Hard Constraints)

- **Do not commit or push** — the user handles all git operations
- **Never use `gh` CLI** — use `curl` to the GitHub API if needed
- Do not skip tests before claiming changes work
- Do not use `sys_system()` with unsanitized input — command injection
- Do not trust external data (file / network / args) without validation
- Do not modify `lib/` files (vendored stdlib / dep symlinks)
- Do not hardcode toolchain versions in CI YAML — `cyrius = "X.Y.Z"` in `cyrius.cyml` is the source of truth

## Documentation

- [`docs/adr/`](docs/adr/) — Architecture Decision Records (*why X over Y?*)
- [`docs/architecture/`](docs/architecture/) — Non-obvious constraints (*what's true about the code?*)
- [`docs/guides/`](docs/guides/) — Task-oriented how-tos
- [`docs/examples/`](docs/examples/) — Runnable examples
- [`docs/development/state.md`](docs/development/state.md) — Live state snapshot
- [`docs/development/roadmap.md`](docs/development/roadmap.md) — Milestones through v1.0

## Process

1. **Work phase** — features, roadmap items, bug fixes
2. **Build check** — `cyrius build`
3. **Test + benchmark additions** for new code
4. **Internal review** — performance, memory, correctness, edge cases
5. **Documentation** — update CHANGELOG, `docs/development/state.md`, any ADR the change earned
6. **Version sync** — `VERSION`, `cyrius.cyml`, CHANGELOG header

