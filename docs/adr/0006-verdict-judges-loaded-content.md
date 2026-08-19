# ADR-0006: The Verdict judges loaded content; usage exits are adapter decisions

- Status: accepted
- Date: 2026-08-14
- Amends: [ADR-0001](0001-one-finding-contract.md)
- Issues: [#3](https://github.com/conceptadev/okf/issues/3), #4

## Context

ADR-0001 states the Verdict as `(findings, strict) → exit code`
and the spec's exit-code matrix as 0 clean, 1 fail, 2 usage. Freezing the
contract in #3 surfaced two questions the record left open: a function of
findings cannot yield exit 2, because an unparseable invocation or an
unreadable bundle source produces no findings to judge; and "absorbed during
the contract work" did not say which slice deletes the parallel finding
types.

## Decision

The Verdict judges loaded content only: it yields exit 0 or 1. Exit 2
(usage) is an adapter decision made before a Report exists — an unparseable
invocation or an unreadable bundle source. Malformed content inside a
loadable bundle merges into the Report as findings and exits 1, matching the
CLI's existing behavior. The full matrix still lives in the finding module
as `OkfExitCode`; adapters return `usage` themselves and the Verdict's
result for everything else.

Absorption ownership: the closed-validator sweep (#4) owns migrating validator
diagnostics into fixed internal rules, merging `OkfBundleLoadIssue` into the
Report, deleting the CLI's private diagnostic, and switching adapters to
consume the Verdict. #3 ships the contract types only.

## Consequences

- The exit-code test at the Verdict seam pins 0 and 1; `usage` is pinned as
  a value of the enum, not as a Verdict outcome.
- ADR-0001's Decision and Consequences stand unchanged; this record only
  fixes their reading.
