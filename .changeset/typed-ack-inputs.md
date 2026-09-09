---
"okf": minor
---

Use Ack schemas for graph-query parsing and generated, typed MCP arguments.
Each input schema owns runtime constraints and the advertised JSON Schema.
Partial updates retain omitted fields, and OKF Spec findings and tolerant
metadata behavior remain unchanged.

Keep concept IDs encoded as strings and report invalid IDs and graph-query
fields with their specific paths and validation reasons.

Raise the minimum supported Dart SDK from 3.4 to 3.9 for Ack 1.2.
