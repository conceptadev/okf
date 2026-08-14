# ADR-0007: The manifest `judgment` section is parse-and-preserve

- Status: accepted
- Date: 2026-08-14
- Issues: [#3](https://github.com/conceptadev/okf/issues/3)

## Context

The manifest's `judgment:` section declares the rules tools must not attempt —
a declared machine/human boundary the spec wants (user story 5). But no slice
in #3–#14 consumes it with engine behaviour. Freezing execution semantics for
an interface with zero adapters either ships dead surface carried forever or
forces a semantics fight when a future consumer finds the frozen shape wrong.

## Decision

The `judgment` section stays in the manifest as declared data. The #3 contract
freezes parse-and-preserve only: the engine stores and lists the entries and
assigns no execution semantics. Semantics are decided when a slice consumes
them, in a superseding record.

## Consequences

- User story 5 is satisfied (the boundary is declared, not implicit).
- The frozen contract carries no speculative execution surface.
- A future consumer (e.g. a reviewer checklist tool) triggers the semantics
  decision with a real adapter in hand.
