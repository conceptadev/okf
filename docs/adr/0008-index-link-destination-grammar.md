# ADR-0008: Index link destinations are percent-encoded

- Status: accepted
- Date: 2026-08-25

## Context

Verbatim reference originals keep their source filenames, and real filenames
carry spaces, parentheses, and non-ASCII (QA surfaced
`C-Fee_NetPayCalculator20200601 (1).xlsx` and em-dash names). The index entry
grammar could not express them: a raw `)` ended the destination early, and a
raw space matched okf's line grammar while no CommonMark parser read the same
line as a link — okf and downstream consumers (okf-profile parses entries via
`package:markdown`) disagreed about the same bytes. Meanwhile
`encodeOkfLinkSegment` left parentheses raw, producing links the index entry
writer itself rejected.

## Decision

The canonical spelling of an index link destination is percent-encoded,
including whitespace, parentheses, and angle brackets. One regular expression
(`okfLinkDestinationUnsafe`, owned by the link-spelling module
`link_path.dart` alongside the encode/decode pair) defines the characters a
plain destination cannot carry; the writer rejects them, the parser flags
them (`OkfIndexIssue.nonPortableLink`, surfaced as the advisory
`okf/non-portable-index-link`), and `encodeOkfLinkSegment` encodes them.
CommonMark's angle-bracket form (`(<…>)`) is accepted on parse for
hand-authored files and normalized to the canonical encoded spelling, so
serialization emits exactly one spelling.

Raw non-ASCII stays legal in destinations: graph resolution treats a segment
that fails percent-decoding without containing `%` as already decoded.

## Consequences

- Every real reference filename has a writable, parseable spelling, and okf
  and `package:markdown`-based consumers read the same target from it.
- Raw-space destinations that 0.1.2 accepted silently now surface an advisory;
  conformance is unchanged.
- The writer no longer accepts destinations it cannot round-trip
  (`ArgumentError` instead of emitting a line CommonMark cannot read).
