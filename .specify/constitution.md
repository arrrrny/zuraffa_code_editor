# zuraffa_code_editor Constitution

> Minimal constitution for the forked-and-revived flutter-code-editor line.
> Extend as the project grows.

## Principles

1. **Users first.** The fork exists to unstick users of the abandoned upstream.
   Every change must make the package easier to adopt or harder to crash.
2. **Test-Driven Development is non-negotiable.** No implementation without a
   failing test that proves the need. Evidence of red before green is recorded
   per behavior. A green suite without recorded red history is unproven work.
3. **No silent behavior changes.** Public API additions are additive; breaking
   changes need a major version and an issue that says so.
4. **Small, reviewable PRs.** One concern per PR; the assessment/fix artifacts
   under `.specify/` carry the reasoning so review is fast.
