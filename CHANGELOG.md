## 0.3.0

- Narrow MCP `list-concepts` with optional `prefix`, `type`, and `query`
  parameters: `prefix` names a bundle area, `type` keeps one concept type, and
  `query` is a case-insensitive substring over concept IDs and titles. A
  filtered listing that matches nothing reports the type and area vocabulary
  the bundle actually holds, so a caller corrects its filters in one round
  trip.
- Serialize MCP tool results exactly once, as the JSON text block. Results no
  longer carry a duplicate `structuredContent` copy, which doubled every
  result on the wire; a client that read `structuredContent` reads the text
  block instead.
- Drop the `path` field from MCP concept summaries and lookups; it is always
  the concept ID plus the `.md` suffix.
- Match graph `path_prefixes` (CLI `--path-prefix`) per whole path segment
  through the new `OkfConceptId.isWithin`: a value names a concept or a
  directory, so `architecture` matches `architecture` and everything under
  `architecture/`, and no longer the unrelated `architecture-notes`. A value
  that named a full document path, such as `notes/beta.md`, becomes the
  concept ID, `notes/beta`.

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
- Define the index link destination grammar (ADR-0008): destinations are
  percent-encoded — generated links now encode parentheses too — and
  CommonMark angle-bracket destinations (`(<…>)`) parse and normalize to the
  encoded spelling, so reference filenames with spaces and parentheses are
  writable and parseable. Plain destinations carrying raw whitespace,
  parentheses, or angle brackets surface the new advisory
  `okf/non-portable-index-link`, and `OkfIndexDocument` rejects them with
  `ArgumentError` instead of emitting a line CommonMark cannot read.
- Fix graph target resolution crashing the host process on link targets that
  fail percent-decoding: a segment with no `%` (raw non-ASCII such as an em
  dash in a reference filename) now resolves against the bundle as already
  decoded, and a segment with a genuinely malformed escape resolves as an
  `invalid` edge.
- Classify prose `sources[].resource` descriptors that contain slashes
  ("extracted PDF/OOXML text") as `descriptor` graph edges: whitespace or a
  backtick now marks a source resource as prose before the slash test, since
  genuine link paths percent-encode whitespace (ADR-0008).

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
