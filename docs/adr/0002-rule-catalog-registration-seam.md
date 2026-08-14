# ADR-0002: Every rule is a catalog entry; the registry is a generated projection

- Status: accepted
- Date: 2026-08-14
- Issues: [#3](https://github.com/conceptadev/okf/issues/3), #4, #7, #8, #9

## Context

Rules existed only as call sites: the base validator is a monolith with inline
string codes and fixed severities, so nothing can enumerate the rule set. The
finding-ID registry (#9) needs prose and owner per rule, which the original #3
rule interface did not carry — the generator would have had to scrape source.
The exploratory Python verifier was named as the reference for profile rule
semantics, inverting the interface: an unversioned external script defining the
behaviour of a tested engine catalog.

## Decision

Every rule — base and profile — registers as a catalog entry: stable ID, prose,
owner (`base` or `profile`), default severity, parameter schema, and a run
function. Three adapters read the catalog: validator dispatch, the finding-ID
registry generator, and manifest rule activation (an unknown rule ID in a
manifest is a manifest error). A rule cannot register without prose and owner,
so the registry cannot drift — it is a projection, not a parallel source.

The documented rule parameters are the interface. The Python verifier is input
for deriving fixtures; where it disagrees with the documentation, the
documentation wins and the disagreement becomes a fixture.

## Consequences

- #4 becomes the catalog sweep for base rules, and is blocked by #3.
- "Rule added without registry regeneration fails CI" reduces to a diff check
  on a generated artifact.
- Manifest validation gets an enumerable rule set for free.
