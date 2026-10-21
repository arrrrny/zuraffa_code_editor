# Research: Re-editor Migration

## Decision: re_editor over code_forge

- **Decision**: Use `re_editor` 0.10.0 as the rendering foundation.
- **Rationale**: Production-tested (Reqable); line-virtualized rendering; supports
  folding, autocomplete, search, highlighting via `re_highlight`; dependency
  surface matches this package's needs.
- **Alternatives considered**: `code_forge` — richer (LSP, AI, rope) but heavier
  and web/stdio-LSP oriented; deferred unless LSP is needed later.

## Decision: keep CodeField name

- **Decision**: Retain public `CodeField` as a thin wrapper over re_editor's
  `CodeEditor`.
- **Rationale**: Minimizes host (dws_playground) churn; backward compat not a
  concern anyway but naming stability helps.

## Decision: highlight package

- **Decision**: Migrate highlighting to `re_highlight`; keep `highlight` only if
  the analyzer still needs its `Mode`/`Result` types, otherwise remove.
- **Rationale**: re_editor consumes `re_highlight` modes directly.

## Decision: folding

- **Decision**: Port block detection into a `CodeChunkAnalyzer` returning fold
  ranges; preserve visible-closing-line behaviour.
- **Rationale**: re_editor's folding is analyzer-driven; the visible closing
  line is a UX requirement from this package.

## Decision: text/full-source semantics

- **Decision**: Preserve `code.text` returning full source independent of fold
  state.
- **Rationale**: `dws_playground._onControllerChanged` depends on this.