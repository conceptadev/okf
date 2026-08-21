# ADR-0007: Check-mode exits are adapter decisions

- Status: accepted
- Date: 2026-08-19
- Amends: [ADR-0006](0006-verdict-judges-loaded-content.md)
- Issues: #4

## Context

ADR-0006 fixed the reading of ADR-0001's "no adapter computes exit codes
locally": the Verdict judges loaded content and yields exit 0 or 1; exit 2
(usage) is an adapter decision made before a Report exists. The fixed rule set
sweep (#4) surfaced a third case the record did not name. `okf format
--check` and `okf index --check` exit 1 when files *would change*, and that
outcome is not a finding: no rule can observe formatting drift or index
staleness from an in-memory bundle, and the CLI has documented "check
failure" as exit 1 since 0.1.0.

## Decision

A check-mode "would change" result is an adapter decision in the same sense
as `usage`: the adapter returns `OkfExitCode.findings` itself, after the
Verdict has judged the loaded content clean. The Verdict remains the only
judge of findings; check mode never reinterprets a Report. Should a later
slice make formatting drift or index staleness a Spec rule, check mode
consumes the Verdict for it like any other finding and this carve-out
shrinks accordingly.

## Consequences

- The exit-code matrix stays in `OkfExitCode`; adapters return `usage` and
  check-mode `findings` themselves, and the Verdict's result for everything
  else.
- ADR-0006's Decision stands; this record names the remaining adapter
  decision rather than widening the contract's doc comments.
