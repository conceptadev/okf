---
"okf": patch
---

Consolidate internal rule metadata, execution context, and YAML value helpers
while preserving the public package exports. Remove redundant construction
wrappers and use normal constructors where direct initialization suffices.
Align IO, MCP, and rule tests with their source modules and consolidate the
index/log contract suites without changing their assertions.

Classify local graph targets containing raw or percent-encoded C1 control
characters as invalid, matching bundle-path validation, instead of unresolved.
