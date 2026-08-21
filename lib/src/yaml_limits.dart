/// Structural limits shared by every traversal of OKF YAML data.
///
/// Parsing, snapshotting, and emitting all walk the same values, so they hold
/// one budget rather than three. Keeping the limits together is deliberate: if
/// the snapshot budget fell below the parser's, frontmatter that
/// `OkfDocument.parse` accepts could no longer be described in a change set.
library;

/// The deepest nesting a YAML value may reach.
const int maximumYamlDepth = 200;

/// The most collection entries a single YAML value may contain in total.
const int maximumYamlNodes = 100000;
