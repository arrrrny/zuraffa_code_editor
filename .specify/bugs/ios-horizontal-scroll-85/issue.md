# Bug Issue: Horizontal scrolling does not work on iOS

- **Slug**: ios-horizontal-scroll-85
- **Created**: 2026-10-11
- **Source**: https://github.com/arrrrny/zuraffa_code_editor/issues/85
  (upstream akvelon/flutter-code-editor#280)
- **Title**: Horizontal scrolling does not work on iOS
- **Labels**: bug, severity:high
- **Backlog rank**: 5

## Report (verbatim)

Upstream body, verbatim:

```
CodeField does not scroll horizontally on iOS. Check your example 02, you can
scroll vertically but not horizontally. Works fine on Android though. How can i
make it scrollable for ios?
```

Fork issue #85 body, verbatim:

> ## What was asked
>
> Horizontal scrolling does not work on iOS (example 02 scrolls vertically but
> not horizontally); it works on Android.
>
> ## Why it matters
>
> A user who cannot scroll horizontally cannot reach code past the right edge at
> all on iOS. This is a functional dead end, not a polish issue.
>
> ## Acceptance criteria
>
> - [ ] Horizontal scrolling reaches content past the right edge on iOS
> - [ ] The fix is not platform-gated in a way that breaks Android/web/desktop
> - [ ] A test pins the scroll offsets/geometry that make the difference
> - [ ] Example 02 scrolls horizontally on iOS

Upstream issue has 0 comments and is still open — there is no community
diagnosis to borrow.

## Reproduction (as filed)

Example 02 (`example/lib/02.code_field/main.dart`) — `MaterialApp` → `Scaffold`
→ `SingleChildScrollView` → `CodeField(controller: CodeController(text:
javaFactorialSnippet, language: java))`.

The longest line of `javaFactorialSnippet` is
`System.out.println("Factorial of " + num + " is " + factorial(5));` — 70
characters, so the code area's content is wider than a phone viewport and there
is a real horizontal scroll extent to reach.

Reported: vertical scrolling works, horizontal does not.
