/// The languages a bundled mode can embed, by the name the mode names it.
///
/// `highlight` resolves an embedded sub-language **by name**, looking it up in
/// the language registry — it never follows a reference to the [`Mode`] object
/// itself. A mode whose embedded language is not registered under that name is
/// handed to `_processSubLanguage` (highlight-0.7.0
/// `lib/src/highlight.dart:352-355`), which gives up and returns the embedded
/// text as a single plain node. That is silent: nothing throws, the embedded
/// fragment just never highlights.
///
/// `CodeController` registers the language it is handed under a synthetic key,
/// so none of these names exist in the registry and every embedded fragment in
/// every language falls back to plaintext. Registering the referenced names
/// fixes all of them at once — markdown's `<b>html</b>`, dart's doc comments,
/// dockerfile's `RUN` bodies, erb/haml's Ruby, htmlbars' attributes.
///
/// This is the set of names the bundled modes actually reference, not the whole
/// bundled registry (which is ~190 modes and would be carried by every consumer
/// of this package). A reference this map does not cover still falls back to
/// plaintext exactly as before; register it with `highlight.registerLanguage`
/// to light it up.
///
/// Registering is unconditional — `Highlight` exposes no way to read the
/// registry back — so a mode a consumer registered under one of these names is
/// replaced the next time a language embedding that name is set.
///
/// Rebuild after a `highlight` upgrade:
///
/// ```sh
/// cd ~/.pub-cache/hosted/pub.dev/highlight-*/lib/languages
/// python3 - <<'PY'
/// import re, glob
/// names = set()
/// for f in glob.glob('*.dart'):
///     if f == 'all.dart':
///         continue
///     for m in re.finditer(r'subLanguage:\s*\[(.*?)\]', open(f).read(), re.S):
///         names.update(re.findall(r'"([a-zA-Z0-9_+-]+)"', m.group(1)))
/// for n in sorted(names):
///     v = re.search(r'(?:const|final)\s+(\w+)\s*=\s*Mode\(', open(n + '.dart').read()).group(1)
///     print(f"import 'package:highlight/languages/{n}.dart';")
///     print(f"  '{n}': {v},")
/// PY
/// ```
library;

import 'package:highlight/highlight.dart' show Mode;
import 'package:highlight/languages/actionscript.dart';
import 'package:highlight/languages/bash.dart';
import 'package:highlight/languages/clojure.dart';
import 'package:highlight/languages/css.dart';
import 'package:highlight/languages/handlebars.dart';
import 'package:highlight/languages/java.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/json.dart';
import 'package:highlight/languages/julia.dart';
import 'package:highlight/languages/lua.dart';
import 'package:highlight/languages/markdown.dart';
import 'package:highlight/languages/mojolicious.dart';
import 'package:highlight/languages/perl.dart';
import 'package:highlight/languages/pgsql.dart';
import 'package:highlight/languages/php.dart';
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/r.dart';
import 'package:highlight/languages/ruby.dart';
import 'package:highlight/languages/scheme.dart';
import 'package:highlight/languages/scss.dart';
import 'package:highlight/languages/sql.dart';
import 'package:highlight/languages/stylus.dart';
import 'package:highlight/languages/tcl.dart';
import 'package:highlight/languages/typescript.dart';
import 'package:highlight/languages/vbscript.dart';
import 'package:highlight/languages/xml.dart';
import 'package:highlight/languages/xquery.dart';
import 'package:highlight/languages/yaml.dart';

final Map<String, Mode> subLanguages = {
  'actionscript': actionscript,
  'bash': bash,
  'clojure': clojure,
  'css': css,
  'handlebars': handlebars,
  'java': java,
  'javascript': javascript,
  'json': json,
  'julia': julia,
  'lua': lua,
  'markdown': markdown,
  'mojolicious': mojolicious,
  'perl': perl,
  'pgsql': pgsql,
  'php': php,
  'python': python,
  'r': r,
  'ruby': ruby,
  'scheme': scheme,
  'scss': scss,
  'sql': sql,
  'stylus': stylus,
  'tcl': tcl,
  'typescript': typescript,
  'vbscript': vbscript,
  'xml': xml,
  'xquery': xquery,
  'yaml': yaml,
};
