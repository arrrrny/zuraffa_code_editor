# Issue: Java highlighting breaks on `#` outside strings and on triple-quoted strings

- **Number**: 104
- **URL**: https://github.com/arrrrny/zuraffa_code_editor/issues/104
- **Upstream**: https://github.com/akvelon/flutter-code-editor/issues/42
- **Labels**: bug, severity:medium
- **Backlog rank**: 7
- **Created**: 2026-10-10

## What is wrong / missing (as filed)

`}#` produces broken highlighting, as do multiline triple-quoted string
literals. Upstream package bug; the fork may need its own Java fallback as it
already has for Python/Java.

## Where it lives (as filed)

`highlight` package's Java mode.

## Reproduction (as filed)

```java
public class MyClass {
}
#
```

```java
public class MyClass {
  private string = """
multiline
""";
}
```

## Upstream #42 in full

The upstream report carries four items. Two are Java and are this issue:

1. Java highlighting breaks if `#` is present anywhere but string literals and
   comments.
2. Java highlighting breaks if a multiline string literal is present anywhere
   with single or double quotes.

The other two are Python (`def fn()` without a trailing `:`) and Scala
(a multiline string literal), neither of which this issue covers.
