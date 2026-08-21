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
- Export bundle graphs as JSON, DOT, or Mermaid.
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
being concurrently replaced by an adversarial process. Multi-file writes are
performed independently and do not preserve platform-specific ACLs or extended
attributes.

## Scope

The package models Attested Computation contracts but does not execute
computations or attesters. Google Cloud enrichment, Gemini orchestration,
web crawling, and the reference HTML viewer are outside this package.

## License

Apache License 2.0.

[spec]: https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/3fcbb9f828c2f23d109c855ee403c3a4c81f3a96/okf/SPEC.md
[example]: https://github.com/conceptadev/okf/blob/main/example/okf.dart
