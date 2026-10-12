# Issue: Words shift chaotically with the HTML renderer

- **Number**: 110
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/110
- **Upstream**: https://github.com/akvelon/flutter-code-editor/issues/68
- **Labels**: bug, severity:medium
- **Backlog rank**: 13
- **Created**: 2026-10-10

## What is wrong / missing (as filed)

Renderer-layer text layout faults. Blocked upstream; may need a fallback or
custom HTML highlighting.

## Where it lives (as filed)

`HTML renderer, highlight HTML mode`.

## Reproduction (as filed, upstream #68)

1. Disable `TabModifier` in the package's `code_controller.dart`.
2. Run the app with the HTML renderer: `flutter run --web-renderer html`.
3. Press Tab in the code editor and see words shift chaotically.

Not reproducible on Linux desktop (the VM text engine).
