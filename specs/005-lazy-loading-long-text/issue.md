# Spec Issue: Lazy loading / chunked rendering for long text

- **Slug**: lazy-loading-long-text
- **Number**: 005
- **Fetched**: 2026-10-09
- **Issue**: 22
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/22
- **State**: open
- **Author**: arrrrny
- **Labels**: spec

## Body

Upstream body verbatim:

```
Hi, I am developing a Flutter desktop application. The typing speed is reduced if we go for huge text. is there any way to add lazy loading or something else?
```

Synced from upstream `akvelon/flutter-code-editor#264 — "Performance issue for long text"`.

## Why it matters

Typing latency grows with document size; the app hangs on huge text. Upstream
maintainers judged a full lazy-loading rewrite out of reach (Flutter's
`TextField` is the bottleneck), and community attempts (chunked TextFields,
re_editor + mmap2) were abandoned upstream. For the fork, the realistic slice
is bounded: measure, then attack the cheap wins in our own code paths
(highlighting, folding, gutter sync) before touching the TextField strategy.

## Acceptance criteria

- [ ] A benchmark test captures typing/edit latency growth vs document size (the number before any change)
- [ ] The hot spots are identified from that benchmark
- [ ] At least one measurement-backed optimization lands with tests

## Comments

- TheMultii: "You would have to mostly rewrite the entire text editor in flutter to get a working lazy loading... The problem I mentioned is that it is only laggy on the web, not on different platforms. As far as I am concerned, it has performance issues on every single platform. I guess we will have to wait until the issues are resolved." (links flutter/flutter#128575, flutter/flutter#90063)
- Srimathi622: app hangs with huge text; asked about DeltaTextInputClient.
