# Spec: java-hash-strings-104

Issue: https://github.com/arrrrny/zuraffa_code_editor/issues/104
(upstream akvelon/flutter-code-editor#42).

## Requirement

A Java document keeps its highlighting when it contains a `#` outside a comment
or a string literal, a stray `</`, or a triple-quoted string literal — with or
without its closing `"""`. Documents without those constructs are highlighted
exactly as the shipped `java` mode highlights them.

## Acceptance

- `public class A {\n}\n#\n` classifies `public` as a keyword and `A` as a class
  instead of collapsing to one unclassified node.
- `String s = """\nmultiline\n""";` classifies the whole literal as one
  `string` run.
- An unterminated `"""` highlights everything up to it and the literal as a
  `string`.
- A `#` inside a comment or a string literal still highlights as a comment or a
  string.
- A document without the defects produces the same classified runs as the
  shipped `java` mode.
- Every classified run together still spans the whole source, character for
  character.
- Every language other than java is registered with `highlight` exactly as the
  caller supplied it.

## Non-goals

- A raw newline inside an ordinary `"..."` — a Java syntax error, and unreported.
- `'''` literals, which Java does not have.
- Python and Scala, the other two items of upstream #42.
- Removing the repaired copy once `highlight` fixes these; the tests keep
  pinning the classification either way.
