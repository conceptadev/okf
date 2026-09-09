---
"okf": patch
---

Coordinate bundle operations through a reserved `.okf.lock` file at the
bundle root. Readers share the lock and writers hold it exclusively, so
`format`, `index`, and MCP writes cannot overwrite a concurrent change from a
stale snapshot. The lock file is excluded from bundle inventories, and its
name is exported as `okfBundleLockFileName`.

Read-only commands remain non-mutating: `validate`, `graph`, `format --check`,
and `index --check` use an existing lock but never create one. If the first
writer creates the lock during an uncoordinated read, the read is repeated
under a shared lock.

`OkfBundleWriter.writeAll` gains an `expectedSources` precondition. Formatting
a nested file uses it to refuse stale writes when the command cannot identify
the enclosing bundle root to lock.
