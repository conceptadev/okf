# okf

`okf` is a format-first Dart toolkit for
[Open Knowledge Format (OKF) v0.2][spec]. It reads, writes, validates,
indexes, and graphs bundles made from Markdown documents with YAML
frontmatter.

This package implements the format described by the specification at
revision `3fcbb9f828c2f23d109c855ee403c3a4c81f3a96`. It is an independent
implementation and is not affiliated with or endorsed by Google.

## Features

- Parse OKF documents without discarding producer-defined frontmatter.
- Read v0.2 provenance, trust, lifecycle, and Attested Computation metadata.
- Consume v0.1 `timestamp` and `# Citations` fallbacks.
- Validate the deliberately small OKF conformance surface.
- Load bundles safely without following symbolic links.
- Resolve relative and bundle-relative links while retaining broken links.
- Generate deterministic directory indexes.
- Apply validated change sets that write concept, index, and log atomically.
- Parse and emit `index.md` and `log.md` entries through one shared model.
- Export bundle graphs as JSON, DOT, or Mermaid.
- Serve a Model Context Protocol read/write surface for coding agents.
- Use the APIs without `dart:io`, or import `okf_io.dart` for filesystem
  operations.

## Install

Add the library:

```console
dart pub add okf
```

Or activate the command-line tool:

```console
dart pub global activate okf
```

## Command line

```console
okf validate path/to/bundle
okf validate path/to/bundle --strict
okf format path/to/bundle --check
okf index path/to/bundle --check
okf graph path/to/bundle --output mermaid
okf mcp path/to/bundle
```

Graph filters are repeatable, compose across fields, and apply to JSON, DOT,
and Mermaid output:

```console
okf graph path/to/bundle \
  --type Metric \
  --path-prefix analytics/ \
  --resolution unresolved
```

Values for the same flag are alternatives; different flags are combined. Type
and path filters select an induced concept subgraph, and resolution filters
then select its edges. Path prefixes match bundle-relative document paths such
as `analytics/revenue.md`. Without filters, the complete graph is emitted.

JSON graph output follows the versioned
[`graph-v1.schema.json`](schemas/graph-v1.schema.json) contract. Its root
`schema_version` is `"1"`; consumers should reject versions they do not
support. The library exports `OkfGraphQuery`, its machine-readable
`OkfGraphQuery.jsonSchema`, and `okfGraphJsonSchemaVersion` so other adapters
can use the same query and output contracts.

Commands use exit code `0` for success, `1` for a conformance or check
failure, and `2` for invalid invocation or I/O failure. Advisory findings
fail validation only under `--strict`. Validation can be emitted as JSON for
automation:

```console
okf validate path/to/bundle --output json
```

## Continuous integration

Gate a repository on OKF Spec conformance with one step and no configuration:

```yaml
steps:
  - uses: conceptadev/okf@v0.2.0
```

The action downloads the released `okf` binary for the ref in `uses` and runs
`okf validate` once. Before execution, it verifies the binary against the
immutable release's signed asset attestation. The job fails on the exit code of
that single invocation, so CI reaches the same verdict as the command line.
Inputs:

- `bundle`: the bundle to validate. Defaults to the repository root.
- `strict`: set to `true` to fail on advisories as well as errors.
- `engine-version`: override the release tag inferred from the action ref.

Releases attach an `okf-linux-x64` and an `okf-macos-arm64` binary, so the
action runs on Linux and macOS runners.

## MCP server

`okf mcp <bundle>` serves a Model Context Protocol surface over stdio, so a
coding agent can navigate, check, and edit a bundle without raw file reads.
While the server runs, standard output carries JSON-RPC alone and every
diagnostic goes to standard error. Each call re-reads the bundle, so an agent
that edits files between calls never sees a stale answer.

| Tool | Arguments | Returns |
| --- | --- | --- |
| `list-concepts` | none | Every concept with its type, title, status, and trust tier. |
| `lookup-concept` | `id` | One concept, including its canonical Markdown. |
| `query-graph` | `OkfGraphQuery.jsonSchema` | The versioned graph JSON that `okf graph --output json` emits. |
| `validate` | `strict` | The Report `okf validate --output json` emits, plus the Verdict's `exit_code`. |
| `create-concept` | `id`, `type`, `title`, `description`, `tags`, `body` | The bundle-relative paths the write committed. |
| `update-concept` | `id`, `type`, `title`, `description`, `tags`, `body` | The bundle-relative paths the write committed. |
| `link-concepts` | `source`, `target`, `relationship` | The bundle-relative paths the write committed. |
| `deprecate-concept` | `id`, `note` | The bundle-relative paths the write committed. |

`validate` returns the same Report as the command line for the same bundle
and inputs — the same finding IDs, locations, and severities — and `strict`
is the `--warnings-as-errors` flag, so an agent can
reproduce the CI gate's judgment before pushing. Arguments are validated
against each tool's schema; rejected arguments come back as a tool error.

### Writes

Every write verb goes through `OkfBundleChangeApplier`, so one call prepares
the changed concept documents and log or index entries, commits them under the
shared bundle lock, and rolls them back together if an ordinary filesystem
write fails. `id`, `source`, and `target` are bundle-relative concept IDs
without the `.md` suffix; `type` is required when creating.

`type`, `title`, `description`, `tags`, and `body` are the fields
`create-concept` and `update-concept` manage. An update overlays only the
arguments it is given and retains every other field — `resource`,
`verification`, `sources`, and anything else the document carries keep their
values and their order.

`link-concepts` records `relationship` on the `source` concept as a reference
to `target`, which `okf graph` exposes as a concept edge. The target may be
planned rather than present: that write succeeds and the graph retains an
unresolved edge. `deprecate-concept` sets the concept's lifecycle status to
`deprecated` and records `note` with the log entry. Both are idempotent: a
link the source already declares, or a concept that is already deprecated,
changes no file.

A write is judged before it reaches disk, against the same rules
`okf validate` runs. Two outcomes are distinguished:

- A Spec-invalid candidate is **refused**: the call fails with structured
  content carrying the Report — the same finding IDs the command line prints
  for that state — and not one file is changed. Only Spec errors refuse a
  write; an advisory-only candidate remains conformant and can commit.
- Input that describes no bundle state is a plain **tool error**, with a
  message and no Report: a malformed argument, an ID that is not
  bundle-relative or that would occupy a reserved `index.md` or `log.md` path,
  creating a concept that already exists, or naming a missing source concept
  to update, link, or deprecate.

Register the server with an MCP client by pointing it at the executable:

```json
{
  "mcpServers": {
    "okf": {"command": "okf", "args": ["mcp", "path/to/bundle"]}
  }
}
```

## Library

Use `okf.dart` when working with in-memory documents:

```dart
import 'package:okf/okf.dart';

final document = OkfDocument.parse('''
---
type: Metric
title: Revenue
verified: {by: "human:reviewer", at: "2026-07-27T12:00:00Z"}
---

# Revenue
''');

print(document.metadata.trustTier.wireValue); // human-reviewed
```

Filesystem operations live in the separate `okf_io.dart` library:

```dart
import 'package:okf/okf_io.dart';

final result = await const OkfBundleLoader().inspect('path/to/bundle');
final validation = result.validate();
final report = validation.report;
final verdict = OkfVerdict.of(report);
final graph = OkfGraph.fromBundle(result.bundle);

print(
  '${report.findings.length} findings, '
  '${graph.edges.length} relationships, exit ${verdict.exitCode}',
);
```

Bundle mutations go through one prepared write path. Preparation builds the
complete candidate and runs the closed OKF Spec validator without touching
disk. Callers may inspect the immutable candidate before committing the exact
prepared bytes across concept, index, and log files together:

```dart
import 'package:okf/okf_io.dart';

const writer = OkfBundleChangeApplier();
final result = await writer.prepare(
  'path/to/bundle',
  OkfBundleChangeSet(<OkfBundleChange>[
    OkfCreateConceptChange(
      id: OkfConceptId('metrics/churn'),
      document: OkfDocument(
        frontmatter: const <String, Object?>{
          'type': 'Metric',
          'title': 'Churn',
        },
        body: '# Churn\n',
      ),
    ),
  ]),
);

switch (result) {
  case OkfPreparationReady(:final prepared):
    // Downstream policy may inspect prepared.candidate.toBundle() here.
    final committed = await writer.commit(prepared);
    print('Wrote ${committed.changedPaths.length} file(s).');
  case OkfPreparationRefused(:final validation):
    print(validation.report.toText());
}
```

See [`example/okf.dart`][example] for a complete command-line example.

### Findings and rules

Every finding carries a stable `okf/<code>` ID (for example
`okf/missing-type`). The package exposes read-only rule descriptors with
prose, severity, and pinned-Spec references; executable rules remain fixed
inside `OkfSpecValidator`. Text output renders one line per finding
(`path[:line[:column]]: severity okf/code: message`); JSON output is the
Report projection — a `findings` array whose entries carry `id`,
`severity`, `message`, and `location`.

For the same bundle, OKF Spec validation always produces the same result; it
accepts no rule catalog, suppression, strictness, or downstream parameters.
Downstream packages run their own checks separately and combine acceptance at
their own boundary.

```dart
final validation = const OkfSpecValidator().validate(bundle);
if (validation.isConformant) {
  // Run downstream checks against the same candidate separately.
}
```

## Compatibility principles

OKF intentionally requires very little. This package therefore separates
hard conformance errors from advisory findings:

- Unknown concept types and extension keys are preserved.
- Missing optional trust or provenance fields never invalidate a concept.
- A bare `verified` mapping is treated as a one-element list.
- Broken links remain visible as unresolved graph edges.
- Unknown bundle versions are consumed on a best-effort basis.
- Unicode concept IDs are accepted when safe; an advisory finding marks
  IDs that may be less portable across producers.

Formatting is semantic rather than byte-preserving. It retains unknown data
and Markdown content, but YAML comments, anchors, scalar quoting, and
whitespace style are not retained.

Filesystem link checks assume a quiescent bundle rather than a directory tree
being concurrently replaced by an adversarial process. Prepared multi-file
writes are rollback-backed, not crash-atomic: destination files are replaced
independently, so a process or power failure can interrupt the transaction.
Writes do not preserve platform-specific ACLs or extended attributes.

## Scope

The package models Attested Computation contracts but does not execute
computations or attesters. Google Cloud enrichment, Gemini orchestration,
web crawling, and the reference HTML viewer are outside this package.

## License

Apache License 2.0.

[spec]: https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/3fcbb9f828c2f23d109c855ee403c3a4c81f3a96/okf/SPEC.md
[example]: https://github.com/conceptadev/okf/blob/main/example/okf.dart
