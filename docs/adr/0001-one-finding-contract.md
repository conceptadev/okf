# ADR-0001: One Finding contract owns finding identity, the Report, and the Verdict

- Status: accepted, amended by [ADR-0006](0006-verdict-judges-loaded-content.md)
- Date: 2026-08-14
- Issues: [#3](https://github.com/conceptadev/okf/issues/3), consumed by every later slice

## Context

The spec assembled the finding concept piecewise: one sub-issue owned the
`okf/` ID grammar, another owned severities and exit codes, another added
suppression and a registry, and cross-surface parity was stated as "same
finding IDs". No module owned what a finding *is*. The existing code already
carries three parallel finding types (`OkfDiagnostic`, `OkfBundleLoadIssue`,
and the CLI's private `_CliDiagnostic`), and the composition of `--strict` and
suppression was stated nowhere.

## Decision

One module — frozen in the #3 contract — owns finding identity:

- The ID grammar for every namespace: `<namespace>/<code>`. This package mints
  only `okf/<code>`; downstream catalogs mint their own namespaces through the
  registration seam (ADR-0002). No module outside a registering catalog mints
  IDs.
- Severity, location, message.
- The **Report**: findings plus suppressed state, one text and one JSON
  projection. Load issues merge into the Report; parallel finding types go away.
- The **Verdict**: `(findings, suppressions, strict) → exit code`. Every
  adapter — CLI, MCP, CI — consumes the Verdict; none computes exit codes
  locally.

Cross-surface parity is pinned at the Report seam: CLI and MCP `validate`
return the *same Report*, not merely the same IDs.

## Consequences

- Locality: a change to the finding shape touches one module, not five issues'
  pinned tests.
- The exit-code matrix is stated and tested once, at the Verdict seam.
- The MCP `validate` tool gains a strict parameter so an agent reproduces the
  CI gate's judgment before pushing.
- `OkfBundleLoadIssue` and `_CliDiagnostic` are absorbed during the contract
  work.
