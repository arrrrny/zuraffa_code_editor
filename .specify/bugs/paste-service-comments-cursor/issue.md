# Issue: Cursor moves incorrectly when pasting code with service comments

- **Slug**: paste-service-comments-cursor
- **Fetched**: 2026-10-09 (re-assessed 2026-10-10)
- **Issue**: 43
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/43
- **Synced from**: `akvelon/flutter-code-editor#88`
- **Severity**: medium
- **Labels**: bug

## Body (upstream verbatim)

> ### Steps to Reproduce:
>
> 1. Use Java.
> 2. Use the source code:
>
> ```java
> // [START section2]
> void method() {
> }
> ```
>
> 3. Paste this code in the end:
>
> ```java
> class MyClass {
> 	void readOnlyMethod() {// [START section3]
> 	}// [END section3]
> 	// [START section4]
> 	void method() {
> 	}// [END section4]
> }
> ```
>
> **Expected:** Cursor is in the end of the text.
> **Actual:** Cursor is in somewhere near the insertion point.

Upstream maintainer note (same issue):

> With Flutter 3.3.5 upgrade, the cursor no longer freezes when pasting text
> with service comments but still is placed incorrectly in some cases.
>
> Moving to backlog due to lesser severity.

## Reproduction on this fork

Verified on master `8fc9fc6`, Flutter 3.47.5, via `CodeController.value`
(what the framework delivers on paste):

```dart
final controller = CodeController(
  text: '// [START section2]\nvoid method() {\n}\n',
  language: java,
  namedSectionParser: const BracketsStartEndNamedSectionParser(),
);
// The framework rebuilds the *visible* text and puts the caret at the end
// of the inserted run.
final visible = controller.text;                       // 19 chars
controller.value = TextEditingValue(
  text: '$visible$pasted',                           // 164 chars, caret at 164
  selection: TextSelection.collapsed(offset: 164),
);
// Visible text collapses to 92 chars (3 service comments became hidden
// ranges) — the caret should be 92.
// Master: 60.
```

So the bug is **reproducible and reproducible in the exact reported form**.
