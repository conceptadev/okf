# ADR-0006: One graph filter vocabulary; CLI and MCP are two adapters

- Status: accepted
- Date: 2026-08-14
- Issues: [#10](https://github.com/conceptadev/okf/issues/10), #11

## Context

#10 gives `okf graph` composable filters and a versioned JSON schema so graph
consumers have "one stable contract". #11's MCP `query-graph` tool is another
consumer of the graph module, but had no dependency edge to #10 — two query
interfaces could grow over one module, falsifying the one-contract claim at
birth. The existing `OkfGraph` cannot even be constructed filtered: its
constructor is private and its collections are eager and unmodifiable.

## Decision

The graph module owns one filter vocabulary, exported through the library. CLI
flags and the MCP `query-graph` tool are two adapters over that seam; the MCP
tool defines no query shape of its own and returns the same versioned JSON
schema. The graph module gains a public way to construct a filtered graph.
#11 depends on #10.

## Consequences

- The MCP tool's input schema is the filter vocabulary — designed once.
- Two adapters make the seam real; ordering is fixed before the tool's input
  schema freezes.
