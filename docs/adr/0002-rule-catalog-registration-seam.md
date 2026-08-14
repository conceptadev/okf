# ADR-0002: Every rule is a catalog entry; a registry is a generated projection

- Status: accepted
- Date: 2026-08-14
- Issues: [#3](https://github.com/conceptadev/okf/issues/3), #4

## Context

Rules existed only as call sites: the base validator is a monolith with inline
string codes and fixed severities, so nothing can enumerate the rule set. A
finding-ID registry needs prose and owner per rule, which the original rule
interface did not carry — a generator would have had to scrape source.

## Decision

Every rule registers as a catalog entry: stable ID, prose, owner, default
severity, parameter schema, and a run function. The registration seam is
public: downstream packages register namespaced rules through the same entry
shape. Two adapters read the catalog: validator dispatch and the finding-ID
registry generator. A rule cannot register without prose and owner, so a
registry cannot drift — it is a projection, not a parallel source.

## Consequences

- #4 becomes the catalog sweep for base rules, and is blocked by #3.
- "Rule added without registry regeneration fails CI" reduces to a diff check
  on a generated artifact.
- Downstream catalogs get the same enumerability for free.
