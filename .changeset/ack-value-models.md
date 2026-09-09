---
"okf": minor
---

Generate equality, hashing, `copyWith`, diagnostic strings, and JSON adapters
for index entries, log entries, and legacy citation values with Ack. Use the
generated copies when normalizing writable index and log entries, and verify
all generated model parts in CI.

Keep const constructors, tolerant parsing, Markdown output, and optional
v0.1 citation compatibility. Concept IDs, diagnostics, and documents retain
their existing validated constructors and custom formatting.
