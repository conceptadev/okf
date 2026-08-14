# ADR-0004: One module owns the index/log entry format

- Status: accepted
- Date: 2026-08-14
- Issues: [#15](https://github.com/conceptadev/okf/issues/15), #8, #14

## Context

The `index.md`/`log.md` entry format was about to be copied three times: the
index/log rule batch reads it (#8), the MCP writes maintain it (#12/#13), and
the CI gate ran a separate "index check" (#14). No acceptance criterion said
the entries the server writes must satisfy the rules that read them — the
round-trip invariant was nobody's.

## Decision

One model module (#15) parses and emits index and log entries; the existing
`OkfIndexGenerator` is its nucleus. The #8 rules read the model; the
BundleChangeSet emits through it; the CI gate runs validation as a single
invocation with no separate index check. The bundle keeps holding index and log
files as raw text — the model parses on demand; no bundle shape change.

## Consequences

- The write-then-validate round trip holds by construction at the model seam.
- One owner for "is the index correct"; the gate loses a drift source.
- #8 is blocked by #15; existing `okf index` output stays byte-identical.
