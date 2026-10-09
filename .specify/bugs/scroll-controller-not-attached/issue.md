# Bug Issue: `ScrollController` not attached — exception from `_getPopupLeftOffset`

- **Slug**: scroll-controller-not-attached
- **Fetched**: 2026-10-09
- **Issue**: 10
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/10
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

Upstream body verbatim (abridged — the reporter's app is the standard `02.simple`
example wrapped in a `SingleChildScrollView` on Flutter 3.22.2 / Dart 3.4.3):

```
======== Exception caught by Flutter framework =====================================================
The following assertion was thrown:
ScrollController not attached to any scroll views.
When the exception was thrown, this was the stack:
#2      ScrollController.position (package:flutter/src/widgets/scroll_controller.dart:157:12)
#3      ScrollController.offset (package:flutter/src/widgets/scroll_controller.dart:165:24)
#4      _CodeFieldState._getPopupLeftOffset (package:flutter_code_editor/src/code_field/code_field.dart:524:34)
#5      _CodeFieldState._updatePopupOffset (package:flutter_code_editor/src/code_field/code_field.dart:487:24)
#6      ChangeNotifier.notifyListeners (package:flutter/src/foundation/change_notifier.dart:433:24)
#7      CodeController.analyzeCode (package:flutter_code_editor/src/code_field/code_controller.dart:224:5)
```
(the full upstream text, including the reporter's `main.dart`, is in the issue body.)

Synced from upstream `akvelon/flutter-code-editor#275 — "CodeField error"`.

## Why it matters

Every `analyzeCode()` notification reads `scrollController.offset` for the
suggestion-box position. When the field's `ScrollController` has no attached
position (e.g. the field is inside an outer `SingleChildScrollView` so it never
scrolls internally), each analysis prints an assertion to the console. The app
keeps working, so it is easy to miss — but it floods the log and can fire in
release-style workflows.

## Acceptance criteria

- [ ] Reproducing widget test: a `CodeField` whose scroll controller has no attached
      position, then `analyzeCode()` → no exception today, exception thrown in the test
- [ ] Fix: no `ScrollController.offset` read while `!hasClients` (guard or fallback offset)
- [ ] Existing suggestion/autocomplete tests stay green

## Comments

None.
