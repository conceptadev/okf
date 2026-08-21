## 0.2.0

- Add the engine contract types: findings, the immutable OKF Spec report and
  conformance judgment, adapter verdicts, change descriptions, and index/log
  entries.
- Pin the finding ID grammar to lowercase kebab-case `<namespace>/<code>`
  and hold `OkfReport` findings in one canonical order on every surface:
  path, line, column, ID, severity, message.
- Move `OkfIndexEntry` into the index/log model and add value equality to
  index and log entries.
- Add `OkfIndexDocument` and `OkfLogDocument`, which parse and emit the
  `index.md` and `log.md` entry format. The index generator and the reserved
  file rules consume them instead of carrying their own copy of the format.
- Namespace every Spec finding as `okf/<code>` and expose read-only rule
  descriptors while keeping execution fixed inside `OkfSpecValidator`.
  Validation text and JSON now project the shared Report, bundle load failures
  are findings, and CLI exit status is judged by the Verdict. `okf validate
  --strict` fails on advisories; `--warnings-as-errors` remains as an alias.
- Add prepared bundle changes as the single safe write path for create,
  update, link, and deprecate operations. Preparation validates a complete
  immutable candidate with the closed Spec validator; commit detects stale
  source state and writes the exact prepared files transactionally.
- Add composable graph filters for concept type, path prefix, and edge
  resolution.
- Version and document the graph JSON schema.
- Add `okf mcp`, a Model Context Protocol server over stdio with the
  `list-concepts`, `lookup-concept`, `query-graph`, and `validate` tools. Its
  `validate` tool returns the same Report and Verdict as the command line, and
  `query-graph` takes the graph filter vocabulary as its input schema.
- Add the `create-concept` and `update-concept` MCP write tools, thin adapters
  over `OkfBundleChangeApplier`: one call writes the concept and maintains the
  `index.md` and `log.md` entries atomically. A Spec-invalid candidate is
  refused with the Report the command line prints for the same state and
  leaves no file changed, while input that describes no bundle state is a
  plain tool error. Updates manage `type`, `title`, `description`,
  `tags`, and `body`, and retain every other frontmatter field.
- Add the `link-concepts` and `deprecate-concept` MCP write tools, completing
  the fixed tool surface. A link records the relationship on the source
  concept; an absent target is accepted and remains an unresolved graph edge.
  A deprecation sets `status: deprecated`. Both update the concept and
  `log.md` in the same operation and share the write path's refusal and
  tool-error tiers.
- Breaking: `okf validate --output json` replaces the `valid`, `error_count`,
  `warning_count`, and `diagnostics` fields with the Report projection — a
  `findings` array whose entries carry `id`, `severity`, `message`, and
  `location`.
- Breaking: remove `OkfDiagnostic` and `OkfValidationReport` (with `isValid`,
  `errorCount`, and `warningCount`) in favor of `OkfFinding`, `OkfReport`, and
  the closed `OkfSpecValidator`.
- Enforce one non-normalizing POSIX grammar across bundle inventories, concept
  IDs, and file-system adapters.
- Snapshot bundle change descriptions faithfully, keeping frontmatter value
  types, key order, and the body verbatim, and reject YAML values no change
  kind can represent with `ArgumentError`.
- Validate relationship names, and escape control characters in one-line
  finding text while retaining raw locations and messages in JSON.
- Add the CI gate: releases attach `dart compile exe` binaries for Linux and
  macOS, and a composite GitHub Action pins an engine version, downloads the
  matching attested binary from an immutable release, and runs OKF Spec
  validation as a single invocation whose exit code decides the job.

## 0.1.2

- Move package ownership to the verified `concepta.dev` publisher.
- Update repository and issue links for the `conceptadev` organization.

## 0.1.1

- Remove development-only and copied third-party test artifacts.
- Replace copied fixtures with independently authored compatibility tests.

## 0.1.0

- Initial implementation of the Open Knowledge Format v0.2.
- Parse, write, validate, index, and graph OKF bundles.
- Add the `okf` command-line interface.
