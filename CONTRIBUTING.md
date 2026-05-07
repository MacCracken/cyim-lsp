# Contributing to cyim-lsp

Thanks for your interest. cyim-lsp is part of the
[AGNOS library](https://github.com/MacCracken/agnosticos); the
overall contribution norms live there. This file collects the
cyim-lsp-specific bits.

cyim-lsp ships as a plugin distfile consumed by
[cyim](https://github.com/MacCracken/cyim) under cyim's plugin
ABI ([cyim ADR 0003](https://github.com/MacCracken/cyim/blob/main/docs/adr/0003-plugin-system.md),
[ADR 0004](https://github.com/MacCracken/cyim/blob/main/docs/adr/0004-plugin-abi-freeze.md)).
Public surface is API-frozen at v1.0.0
([ADR 0001](docs/adr/0001-api-freeze.md)).

## Before you open a PR

1. **Read [`CLAUDE.md`](CLAUDE.md).** Durable rulebook for this
   project — process, hard constraints, Cyrius idioms,
   documentation conventions.
2. **Run the full local check** that CI runs:
   ```sh
   cyrius deps                                    # resolve stdlib deps
   cyrius build src/main.cyr build/cyim-lsp       # standalone smoke driver
   CYRIUS_DCE=1 cyrius build ...                  # DCE parity
   cyrius test                                    # all .tcyr suites
   cyrius fuzz                                    # fuzz harnesses
   cyrius lint src/*.cyr                          # advisory only
   cyrius distlib                                 # regenerate dist/cyim-lsp.cyr
   ```
   Everything must be green. After distfile-affecting changes, the
   regenerated `dist/cyim-lsp.cyr` must be committed — CI verifies
   it matches a fresh `cyrius distlib` run.
3. **Update the CHANGELOG.** New behavior gets a bullet under
   `[Unreleased]`. Any change to a public symbol enumerated in
   [ADR 0001](docs/adr/0001-api-freeze.md) is a breaking change
   and needs a major bump + migration notes.
4. **One change per PR.** A bug fix doesn't need surrounding
   refactors; a refactor PR shouldn't change behavior.

## What cyim-lsp refuses

These are load-bearing refusals — please don't propose them as
features without a prior conversation:

- **No embedded scripting language.** Inherits cyim's refusal —
  configuration is data (CYML), not code.
- **No arbitrary LSP method exposure.** Only the methods listed
  in ADR 0001's public surface are dispatched. New methods need
  a minor bump and an ADR amendment.
- **No untrusted-server execution paths.** LSP server binary
  paths come from cyim's config (trusted); cyim-lsp never accepts
  a server path off the wire.
- **No JSON parser stdlib dependency.** Hot-path JSON walking is
  done with brace-depth + string-aware byte scans. A real parser
  is more attack surface than this project earns.

## Versioning & API freeze

The plugin ABI surface (the `cyim_lsp_*` functions, callback
signatures, registration order) is frozen at v1.0.0. See
[ADR 0001](docs/adr/0001-api-freeze.md) for the full enumerated
surface and the breaking-change policy.

Internal helpers prefixed `_lsp_*` are explicitly NOT public —
they may change between minors. Don't depend on them from cyim
or from out-of-tree consumers.

## Filing an issue

Open against the cyim-lsp repo. Useful info:

- cyim-lsp version (`./build/cyim-lsp` prints banner, or
  `cat dist/cyim-lsp.cyr | head -3`)
- cyim version that's consuming it
- Cyrius toolchain version (`cyrius --version`)
- LSP server in use (`cyrius-lsp`, `gopls`, etc.) + version
- Repro: ideally a `cyim --headless` keystroke transcript or a
  minimal `.cyr` file that reproduces the diag/nav issue

For security issues, see [`SECURITY.md`](SECURITY.md).

## License

By contributing you agree your work ships under cyim-lsp's
[GPL-3.0-only](LICENSE) license.
