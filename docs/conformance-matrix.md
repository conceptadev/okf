# OKF 0.2 conformance matrix

This matrix pins consumer behavior to Google OKF revision
`3fcbb9f828c2f23d109c855ee403c3a4c81f3a96`. “Error” means an OKF Spec
conformance failure. “Advisory” is surfaced guidance that never changes
`OkfSpecValidation.isConformant`.

| Spec clause | Required consumer behavior | Finding / outcome | Evidence |
| --- | --- | --- | --- |
| §3.1 | Reserve `index.md` and `log.md` for their defined formats. | Reserved files are parsed separately from concepts. | `test/io_test.dart`, `test/validator_test.dart` |
| §4, §11.1 | Every concept is UTF-8 Markdown with parseable YAML frontmatter. | `okf/invalid-utf8`, `okf/invalid-document`, or `okf/missing-frontmatter` error. | `test/io_test.dart`, `test/validator_test.dart` |
| §4.1, §11.2 | Every concept has a non-empty `type`. | `okf/missing-type` error. | `test/validator_test.dart`, `test/cli_test.dart` |
| §4.1, §11 | Unknown type values are tolerated. | Conformant. | `test/conformance_test.dart` |
| §4.1, §11 | Unknown frontmatter keys are preserved and tolerated. | Conformant and round-tripped. | `test/conformance_test.dart`, `test/document_test.dart` |
| §5.2, §11 | Treat a bare `verified` mapping as one event. | Conformant; one normalized verification. | `test/conformance_test.dart`, `test/metadata_test.dart` |
| §5.3, §11 | Missing optional provenance, trust, lifecycle, and computation families are accepted. | Conformant. | `test/conformance_test.dart` |
| §6.1, §11 | Broken cross-links are accepted. | Conformant; graph retains an unresolved edge. | `test/conformance_test.dart`, `test/graph_test.dart` |
| §8, §11.3 | A present `index.md` follows the index structure. | `okf/invalid-reserved-document` or an `okf/*index*` error. | `test/validator_test.dart` |
| §8, §11 | Missing indexes are accepted. | Conformant. | `test/conformance_test.dart` |
| §8, §11 | Index link destinations are percent-encoded or angle-bracketed; raw whitespace, parentheses, and angle brackets are surfaced guidance. | `okf/non-portable-index-link` advisory; still conformant. | `test/validator_test.dart`, `test/index_log_model_test.dart` |
| §9, §11.3 | A present `log.md` follows the log structure and uses ISO dates. | `okf/invalid-reserved-document` or an `okf/*log*` error. | `test/validator_test.dart`, `test/conformance_test.dart` |
| §10, §11 | Optional Attested Computation shape deviations are soft guidance. | Advisory findings only. | `test/validator_test.dart` |
| §12 | Unknown declared versions are consumed best-effort. | `okf/unsupported-okf-version` advisory; still conformant. | `test/conformance_test.dart`, `test/validator_test.dart` |

The public `OkfSpecValidator` has a const, zero-argument constructor and no
configuration seam. `OkfBundleLoadResult.validate` merges load and fixed Spec
findings into the same `OkfReport`. CLI, MCP, CI, and prepared-write parity are
covered in their adapter slices against this shared result.
