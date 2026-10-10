# Zuraffa Code Editor

[![Pub Version](https://img.shields.io/pub/v/zuraffa_code_editor)](https://pub.dev/packages/zuraffa_code_editor)

A maintained fork of
[`flutter_code_editor`](https://pub.dev/packages/flutter_code_editor) 0.3.5 for
the [Zuraffa](https://pub.dev/packages/zuraffa) ecosystem.

> **Why a fork?** Upstream hid a folded block through the end of its last line,
> so folding `parsers: [ ... ]` left a dangling `parsers: [` with no matching
> `],`. This fork keeps the closing line visible: `parsers: [  ],`. See the
> [changelog](CHANGELOG.md) for the full diff from upstream.

The API is unchanged, so migrating is a drop-in import swap:

```dart
// Before
import 'package:flutter_code_editor/flutter_code_editor.dart';
// After
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
```

Zuraffa Code Editor is a multi-platform code editor supporting:

- Syntax highlighting for over 100 languages,
- Code blocks folding,
- Autocompletion,
- Read-only code blocks,
- Hiding specific code blocks,
- Themes,
- And many other features.

![Basic example](https://raw.githubusercontent.com/arrrrny/zuraffa_code_editor/master/example/images/main.gif)


## Basic Usage

```dart
import 'package:flutter/material.dart';
import 'package:zuraffa_code_editor/zuraffa_code_editor.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:highlight/languages/java.dart';

void main() {
  runApp(const CodeEditor());
}

final controller = CodeController(
  text: '...', // Initial code
  language: java,
);

class CodeEditor extends StatelessWidget {
  const CodeEditor();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: CodeTheme(
          data: CodeThemeData(styles: monokaiSublimeTheme),
          child: SingleChildScrollView(
            child: CodeField(
              controller: controller,
            ),
          ),
        ),
      ),
    );
  }
}
```

See the full runnable example [here](https://github.com/arrrrny/zuraffa_code_editor/blob/master/example/lib/02.code_field.dart).


## Languages

### Syntax Highlighting

Flutter Code Editor supports
[over a hundred languages](https://github.com/git-touch/highlight.dart/tree/master/highlight/lib/languages),
relying on the [highlight](https://pub.dev/packages/highlight) package for parsing code.

To select a language, use a
[corresponding variable](https://github.com/git-touch/highlight.dart/tree/master/highlight/lib/languages):

```dart
import 'package:highlight/languages/python.dart'; // Each language is defined in its file.

final controller = CodeController(
  text: '...', // Initial code
  language: python,
);
```

Language can be dynamically changed on a controller:

```dart
controller.setLanguage(go, DefaultLocalAnalyzer());
```

#### Markup: HTML is highlighted by the `xml` mode

`highlight` defines no `html` mode of its own. HTML — together with `xhtml`,
`rss`, `atom`, `xjb`, `xsd`, `xsl`, `plist`, `wsf` and `svg` — is listed among
the aliases of its `xml` mode, and that mode is what parses it: doctype,
element names, attributes, attribute values, comments and entity references all
come out classified. So to edit HTML, import and use `xml`:

```dart
import 'package:highlight/languages/xml.dart'; // Highlights HTML too.

final controller = CodeController(
  text: '<!DOCTYPE html>...',
  language: xml,
);
```

Inside `<script>` and `<style>` bodies the text is left as markup rather than
re-parsed as JavaScript or CSS, because `highlight`'s `xml` mode declares no
embedded sub-language for them.


### Code Blocks Folding 

Flutter Code Editor can detect and fold code blocks. Code blocks folding is supported for the following languages:
- Dart
- Go
- Java
- Python
- Scala

![Foldable blocks example](https://raw.githubusercontent.com/arrrrny/zuraffa_code_editor/master/example/images/foldable_blocks_example.gif)

Code blocks folding may support other languages in experimental mode.


## Code Analysis

The editor supports pluggable analyzers to highlight errors and show error messages:

![DartPadAnalyzer](https://raw.githubusercontent.com/arrrrny/zuraffa_code_editor/master/example/images/dartpad-analyzer.png)


We ship the following analyzers:

- `DefaultLocalAnalyzer` highlights unmatched pair characters for supported languages.
  It works on the client locally,
  and is selected by default on `CodeController` if no other analyzer is specified.
- `DartPadAnalyzer` for Dart language, calls upon the [DartPad](https://dartpad.dev) backend for analysis.

For other languages, you can write custom analyzers that access your backend.
See the code for `DartPadAnalyzer` for the implementation example.

To set the analyzer, call any of the following:

```dart
codeController = CodeController(language: dart, analyzer: DartPadAnalyzer());
codeController.analyzer = DartPadAnalyzer();
codeController.setLanguage(dart, analyzer: DartPadAnalyzer());
```

**Note:** Code analysis is an experimental feature.
We may introduce breaking changes to `Analyzer` subclasses without following the semver contract.
If you only use the analyzers we ship, then this will not affect you.


## Themes

### Pre-defined Themes

Flutter Code Editor supports themes from the [highlight](https://pub.dev/packages/flutter_highlight) package —
see the full list of the pre-defined themes
[here](https://github.com/git-touch/highlight.dart/tree/master/flutter_highlight/lib/themes).

Use `CodeTheme` widget to set the theme for underlying editors:

```dart
return MaterialApp(
  home: Scaffold(
    body: CodeTheme(
      data: CodeThemeData(styles: monokaiSublimeTheme), // <= Pre-defined in flutter_highlight.
      child: SingleChildScrollView(
        child: CodeField(
          controller: controller,
        ),
      ),
    ),
  ),
);
```

### Custom Themes

To use a custom theme, create a map of styles under the pre-defined class names —
see [this example](https://github.com/git-touch/highlight.dart/blob/master/flutter_highlight/lib/themes/monokai-sublime.dart).


## Hiding Line Numbers, Errors, and Folding Handles

A lot of styling can be tuned with a `GutterStyle` object passed to a `CodeField` widget.
See
[this example](https://github.com/arrrrny/zuraffa_code_editor/tree/master/example/lib/03.change_language_theme)
that dynamically changes the properties listed here.

```dart
CodeField(
  gutterStyle: GutterStyle(
    showErrors: false,
    showFoldingHandles: false,
    showLineNumbers: false,
  ),
  // ...
),
```

If you want to hide the entire gutter, use `GutterStyle.none` constant instead:

```dart
CodeField(
  gutterStyle: GutterStyle.none,
  // ...
),
```

## Accessing the Text

`CodeController` extends the Flutter's built-in `TextEditingController` and is immediately
usable as one. However, code folding and other features have impact on built-in properties:

- `text` returns and sets the visible text. If any code is folded, it will not be returned.
- `value` returns and sets the `TextEditingValue` with the visible text and selection.
  If any code is folded, it will not be returned.
- `fullText` returns and sets the entire text, including any folded blocks and hidden
  service comments (see below).


## Named Sections

To manipulate parts of the source code, Flutter Code Editor supports *named sections*.
They are defined in the code by adding tags that Flutter Code Editor recognizes.

To define a named section in your source code, add comments to tag the start and the end of the section:
1. Add comment `[START section_name]` to tag the beginning of the section.
2. Add comment `[END section_name]` to tag the end of the section.

Here is an example to define a named section `section1`:

```dart
final text = '''
class MyClass {
    public static void main(String[] args) {// [START section1]
        int num = 5;
        System.out.println("Factorial of " + num + " is " + factorial(5));
    }// [END section1]
}
''';
```

To process named sections in the Flutter Code Editor,
pass the named section parser to the controller:

```dart
final controller = CodeController(
  text: text,
  language: java,
  namedSectionParser: const BracketsStartEndNamedSectionParser(), // NEW
);
```

The example above creates a section named `section1`.
The built-in `BracketsStartEndNamedSectionParser` class is designed to parse sections
from the code comments using the above syntax.
It also hides any single-line comment that has a section tag with the above syntax,
although such comments are still present in the editor's hidden state
and will be revealed when copying the text.

To customize section parsing using any other syntax, subclass `AbstractNamedSectionParser`.


## Read-Only Code Blocks

Flutter Code Editor allows you to define read-only code blocks.
This may be useful for learning use cases when users are guided to modify certain code blocks
while other code is meant to be protected from changes. 

To make a named section read-only, pass a set of named sections to the `controller.readOnlySectionNames`:

```dart
controller.readOnlySectionNames = {'section1'};
```

This locks the given sections from modifications in the Flutter Code Editor.
Any non-existent section names in this set are ignored.
To make the code editable again, pass an updated set to `controller.readOnlySectionNames`.

When using this feature, `text` and `value` properties cannot be used to change the text
programmatically because they have the same effect as the user input.
This means that locking affects them as well.

To change a partially locked controller, set the `fullText` property.

![Readonly blocks example](https://raw.githubusercontent.com/arrrrny/zuraffa_code_editor/master/example/images/readonly-sections-example.gif)


## Advanced Code Blocks Folding

### Folding the First Comment/License

Many code snippets contain a license as their first comment, which can distract readers.
To fold the first comment, use:

```dart
controller.foldCommentAtLineZero();
```

This method has no effect if there is no comment starting at the first line.

### Folding Imports

In many languages, the editor recognizes sequential import lines
and an optional package line as one foldable block.
To fold such blocks:

```dart
controller.foldImports();
```

### Named Sections

The editor supports folding all blocks except for specific named sections.
This helps the user focus on those sections while
all source code is still there and can be expanded and copied by the user.

To fold all blocks except those overlapping with the given named sections:

```dart
controller.foldOutsideSections(['section1']);
```

### Folding Specific Blocks

To fold and unfold blocks at a given line number:

```dart
controller.foldAt(1);
controller.unfoldAt(1);
```

If there is no block at a given line, this has no effect.

**Note:** For the controller, line numbers start at `0` although
the widget displays them starting at `1`.

### Accessing Folded Blocks

To get the currently folded blocks, read `controller.code.foldedBlocks`.


## Hiding Text

The editor allows you to completely hide all code except for a specific named section.
This is useful to achieve even more focus than with folding.

To hide all the code except the given named section:

```dart
controller.visibleSectionNames = {'section1'};
```

![visibleSectionNames](https://raw.githubusercontent.com/arrrrny/zuraffa_code_editor/master/example/images/visible-section-names.png)

When hiding text, the full text is still preserved
and available via `fullText` property in the Flutter Code Editor.

Hiding text preserves line numbering, which is not possible by just showing a cropped snippet.
Preserving hidden text is also useful if you later need to send
the full code for further processing but still want to hide
non-informative parts.

Hiding text also makes the entire editor read-only
to prevent users from modifying the code, adding imports, etc.
which may conflict with the hidden parts.

Only one visible section at a time is currently supported. The behavior of passing more than
one section is undefined.


## Autocompletion

The editor suggests words as they are typed. Suggested words are:

- All keywords of the current language.
- All words already in the text.
- Words set with `controller.autocompleter.setCustomWords(['word1', 'word2'])`

All those words are merged into an unstructured dictionary.
The editor does not perform any syntax analysis, so it cannot tell if a given class really has
the method the user is typing. This feature is meant to simplify typing, but should not be relied on
when exploring classes and methods.

![Suggestions example](https://raw.githubusercontent.com/arrrrny/zuraffa_code_editor/master/example/images/suggestions_example.gif)

To disable autocompletion:

```dart
controller.popupController.enabled = false;
```


## Shortcuts

- Indent (Tab)
- Outdent (Shift-Tab)

![indent outdent example](https://raw.githubusercontent.com/arrrrny/zuraffa_code_editor/master/example/images/tab-shift-tab_example.gif)

- Comment out (Control-/)
- Uncomment (Control-/)

![comment out uncomment example](https://raw.githubusercontent.com/arrrrny/zuraffa_code_editor/master/example/images/comment_out_example.gif)


## Migration Guides

- [Migrating from code_text_field to 0.1](https://github.com/arrrrny/zuraffa_code_editor/blob/master/doc/migrating/0.1.md)
- [Migrating from 0.1 to 0.2](https://github.com/arrrrny/zuraffa_code_editor/blob/master/doc/migrating/0.2.md)


## Contact Us

* [Report an issue](https://github.com/arrrrny/zuraffa_code_editor/issues).


## Attribution

Zuraffa Code Editor is a fork of
[`akvelon/flutter-code-editor`](https://github.com/akvelon/flutter-code-editor),
used under its CC0 public domain dedication. This fork's own changes are
dedicated to the public domain under the same terms.
