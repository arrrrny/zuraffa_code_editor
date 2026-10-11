# Bug Issue: Gutter numbers and code text are not vertically aligned

- **Slug**: gutter-icon-row-height-107
- **Created**: 2026-10-11
- **Source**: https://github.com/arrrrny/zuraffa_code_editor/issues/107
  (upstream akvelon/flutter-code-editor#312, #215)
- **Title**: Gutter numbers and code text are not vertically aligned
- **Labels**: bug, severity:medium
- **Backlog rank**: 10

## Report (verbatim)

Fork issue #107 body, verbatim:

> ## What is wrong / missing
>
> Visible one-pixel drift between the gutter and the code column. PR #61 fixed
> the Material 3 case; these reports persist.
>
> ## Where it lives
>
> `lib/src/gutter/gutter.dart`

Upstream #312 body, verbatim (abridged to the report):

> Currently, the gutter numbers and the code editor are not aligned. ... If
> gutterPadding is added which I did before in a forked library - it aligns
> perfectly but otherwise is 4 units misaligned.

Upstream #215 body, verbatim:

> I think, the gutter is off by one pixel. ... Here's my configuration:
> `textStyle: TextStyle(fontFamily: 'Cascadia Mono', fontSize: 16)`,
> `gutterStyle: GutterStyle(textStyle: TextStyle(color: Colors.white24,
> fontSize: 16, height: 1.5))`

Upstream comment on #312 (john-rager), verbatim:

> Not sure if the fix #320 has been applied yet, but v0.3.5 still has this bug.
> The workaround suggested by several (specifying the height property in both
> the gutter and code textStyle's) **does not work**. It definitely appears to
> be a padding issue.

Upstream comment on #215 (TekExplorer), verbatim:

> It is consistently out of sync for me. And since we're not allowed to alter the
> gutter text size ourselves, i cant get around this weird sizing/padding issue
> which i'm assuming has something to do with the weird table you're using for
> the gutter

## Prior art in this fork

Two layers of this were already settled and are **out of scope** for this bug:

1. The `height` copy in `CodeField._buildGutter()` (upstream #262 / fork #28),
   pinned by `test/src/gutter/gutter_alignment_test.dart` and
   `gutter_alignment_material3_test.dart`. Both are green on master today.
2. `GutterStyle.padding` (fork #6 / upstream #312's layer 2), pinned by
   `test/src/gutter/gutter_padding_test.dart`. Green on master today.

Both pin the *pitch* invariant (row pitch equals the rendered code line
height). Neither pins the row *height* against a cell that can be taller than
the line box.
