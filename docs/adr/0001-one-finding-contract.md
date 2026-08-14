# ADR-0001: One Finding contract owns finding identity, the Report, and the Verdict

- Status: accepted
- Date: 2026-08-14
- Issues: [#3](https://github.com/conceptadev/okf/issues/3), consumed by #4–#14

## Context

The profile-layer spec assembled the finding concept piecewise: #4 owned the
`okf/` ID grammar, #5 owned severities and exit codes, #6 minted IDs from ack
constraint keys, #9 added suppression and a registry, #11 pinned cross-surface
parity as "same finding IDs". No module owned what a finding *is*. The existing
code already carries three parallel finding types (`OkfDiagnostic`,
`OkfBundleLoadIssue`, and the CLI's private `_CliDiagnostic`), and the
composition of `--strict`, suppression, and the unknown-profile-release degrade
advisory was stated nowhere.

## Decision

One module — frozen in the #3 contract — owns finding identity:

- The ID grammar for every namespace: `okf/<code>`, `profile/<code>`,
  `profile/frontmatter-<keyword>`. No other module mints IDs.
- Severity, location, message.
- The **Report**: findings plus suppressed state, one text and one JSON
  projection. Load issues merge into the Report; parallel finding types go away.
- The **Verdict**: `(findings, suppressions, strict) → exit code`, including the
  degrade advisory's behaviour under `--strict`. Every adapter — CLI, MCP, CI —
  consumes the Verdict; none computes exit codes locally.

Cross-surface parity is pinned at the Report seam: CLI and MCP `validate`
return the *same Report*, not merely the same IDs.

## Consequences

- Locality: a change to the finding shape touches one module, not five issues'
  pinned tests.
- The exit-code matrix is stated and tested once, at the Verdict seam.
- The MCP `validate` tool gains strict/profile-override parameters so an agent
  reproduces the CI gate's judgment before pushing.
- `OkfBundleLoadIssue` and `_CliDiagnostic` are absorbed during the profile
  work.
