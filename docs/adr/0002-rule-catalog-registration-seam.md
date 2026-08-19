# ADR-0002: OKF Spec rule execution is closed

- Status: accepted, superseding the earlier open-catalog decision
- Date: 2026-08-14
- Issues: [#3](https://github.com/conceptadev/okf/issues/3), #4

## Context

OKF Spec validation must produce the same report for a bundle regardless of
caller configuration. An executable public catalog would allow callers to
replace, omit, parameterize, or suppress Spec rules and violate that invariant.

## Decision

Executable OKF Spec rules are internal and immutable. The public validator
accepts only a bundle. If tools need enumeration, the package may expose
read-only descriptors containing identity, prose, default severity, and a Spec
reference, never a run function. Downstream rules execute in downstream
packages after inspecting a prepared candidate.

## Consequences

- #4 owns the closed validator and fixed Spec finding set.
- No public registration, suppression, parameter, or replacement seam exists.
- Downstream checks compose at the immutable prepared-candidate boundary.
