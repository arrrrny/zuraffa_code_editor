# Bug Issue: Multiple CodeFields in a TabBarView crash with a null-check error

- **Slug**: tabbarview-multiple-code-fields-crash
- **Fetched**: 2026-10-09
- **Issue**: 26
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/26
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

Upstream body verbatim:

```

Null check operator used on a null value

When the exception was thrown, this was the stack:
#0      _CodeFieldState.initState.<anonymous closure> (package:flutter_code_editor/src/code_field/code_field.dart:208:56)
#1      SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1286:15)
#2      SchedulerBinding.handleDrawFrame (package:flutter/src/widgets/binding.dart:1225:9)
#3      SchedulerBinding._handleDrawFrame (package:flutter/src/widgets/binding.dart:1074:5)
...
```

Synced from upstream `akvelon/flutter-code-editor#174 — "When I use TabBarView to include multiple CodeFields in children, he gets an error"`.

## Why it matters

`initState` scheduling a post-frame callback that force-unwraps something the
widget no longer owns crashes the app. TabBarView keeps several CodeFields
alive offstage, so the crash appears in ordinary tabbed layouts.

## Acceptance criteria

- [ ] Root cause identified at the `initState` post-frame callback in `code_field.dart`
- [ ] The null-check crash no longer occurs with two or more CodeFields in a TabBarView
- [ ] A regression test pins the lifecycle (build a TabBarView with two CodeFields, switch tabs)

## Comments

None.
