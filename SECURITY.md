# Security policy — cyim-lsp

## Reporting a vulnerability

Email **yeoman.maccracken@gmail.com** with subject prefix
`[cyim-lsp security]`. Or open a private security advisory
through GitHub's Security tab.

Please don't open public issues for vulnerabilities until a fix
ships and a CVE (if applicable) is assigned.

A response acknowledging receipt typically lands within a few
days. cyim-lsp is a single-maintainer project; we'll work with
you on disclosure timing.

## Threat model

cyim-lsp is an **LSP-client plugin embedded in cyim**. It runs
under the same trust model as cyim itself ([cyim ADR 0001 trust
model](https://github.com/MacCracken/cyim/blob/main/docs/adr/0001-trust-model.md))
— interactive editor for a single local user, not a privilege
boundary — *plus* one important addition:

- **The LSP server's output is untrusted.** cyim-lsp parses
  JSON-RPC frames coming back from `cyrius-lsp` / `gopls` /
  `rust-analyzer` etc. Even when the server binary itself is
  trusted (it came from cyim's config), the bytes flowing back
  through the pipe are an external attack surface — the server
  may be processing attacker-controlled source files. Every
  byte received is treated accordingly.

In particular:

- The user is trusted. The LSP server **binary path** comes
  from cyim's config and is trusted to the degree the invoking
  user trusts their own config.
- The LSP server's **output** is untrusted: framing headers,
  JSON bodies, diagnostics text, range coordinates. All of it
  is bounds-checked, length-limited, and never `exec`-d.
- cyim-lsp does not `sys_system()` anything. Subprocess spawn
  uses `sys_execve` with explicit argv from trusted config.
- The plugin is not setuid / setgid / setcap-wrapped. Running
  cyim under sudo gives cyim-lsp root's privileges; that's the
  user's choice.

If you find a vulnerability that breaks the threat model — for
example, a malformed JSON-RPC frame from a malicious LSP server
that escapes the buffer-as-data invariant or crashes cyim
through cyim-lsp — that's a real finding and we want to hear
about it.

If you find a behavior that's accepted under the trust model
(e.g., the LSP server can spam status-line messages; the user
can configure a server binary that reads `~/.ssh/`) and would
change the trust model to fix, please open a discussion or PR
rather than a security report — those decisions belong in
[`docs/adr/`](docs/adr/), not in CVE filings.

## What's in scope

- JSON-RPC framing parser correctness (Content-Length header
  handling, body length validation, frame-boundary attacks)
- JSON walker correctness against adversarial bodies
  (unbalanced braces, embedded NULs, deeply nested objects,
  oversized strings, escape-sequence trickery)
- Subprocess lifecycle (pipe cleanup, signal handling, zombie
  reaping, fd leaks)
- Buffer-state correctness against out-of-order LSP responses
  (id correlation, version drift, `didClose` after kill)
- Diagnostic text passed to cyim's status line — control bytes
  must not break terminal rendering (cyim handles ESC sequence
  rejection at its render layer; cyim-lsp shouldn't bypass it)
- Path / URI handling (`_lsp_path_to_uri`,
  `_lsp_pos_extract_uri`) — traversal, encoding, NUL injection
- Any deviation from the threat model above

## What's out of scope (for security reports — file as feature
requests instead)

- "Untrusted server binary path" — refused by trust model; the
  path is config, config is trusted
- "LSP server consumes resources" — the user picked the server;
  resource limits are the user's `ulimit`
- Refused features the project explicitly doesn't ship (see
  [`CONTRIBUTING.md`](CONTRIBUTING.md))
- Performance issues without a security angle

## Past audits

- [2026-05-06 — v1.0.0 pre-API-freeze audit](docs/audit/2026-05-06-audit.md)
  — 0 CRITICAL / 0 HIGH / 0 MEDIUM; 3 LOW (all defense-in-depth,
  triaged for v1.0.x).

## Reference: the JSON-RPC walker is hand-rolled by design

cyim-lsp uses a brace-depth + string-aware byte scanner instead
of a JSON parser stdlib. This is a deliberate attack-surface
reduction: a real JSON parser is thousands of lines of code
processing untrusted bytes. The walker only extracts the
specific fields the LSP protocol needs (`id`, `method`,
`params.uri`, `params.range`, `params.diagnostics[].{message,
severity, range}`) and rejects anything that doesn't fit the
expected shape. See [ADR 0001](docs/adr/0001-api-freeze.md)
§ "JSON walker invariants" for the formal contract.

If you find a sequence of bytes that defeats the walker's
brace-depth or string-state tracking — even if the impact looks
mild — please file it. The walker is the hottest untrusted-input
path in the plugin.
