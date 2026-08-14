# ADR-0008: Suppressions declare in `profile.yaml`

- Status: accepted
- Date: 2026-08-14
- Issues: [#9](https://github.com/conceptadev/okf/issues/9), #3, #14

## Context

Per-finding-ID suppression is the migration path through the CI gate (adopt the
gate, suppress, burn down), but the original #9 described its configuration
surface in one word — "configuration" — with no location or format. It is a
cross-repository contract read by a pinned binary, like `profile.yaml` itself,
and deserved the same contract treatment.

## Decision

Suppressions declare in the reserved sidecar `profile.yaml`, under
`suppressions:`: a list of finding IDs, each with an optional note. The shape
freezes in #3. One reserved file carries the bundle's governance state — what
governs it and its acknowledged, temporary deviations — checked into the
repository, visible in review, removable. The engine reads it identically on
every surface (CLI and MCP); the CI action needs no configuration input. A
suppression naming an unknown finding ID produces an advisory, so stale
suppressions surface.

## Consequences

- No second reserved file; the loader special-cases one name.
- The gate's "one step, zero configuration" claim survives migration.
- Suppression's exit-code interaction is Verdict semantics (ADR-0001), not
  re-decided per surface.
