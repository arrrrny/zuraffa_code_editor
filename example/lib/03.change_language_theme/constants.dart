import 'package:highlight/languages/dart.dart';
import 'package:highlight/languages/go.dart';
import 'package:highlight/languages/java.dart';
import 'package:highlight/languages/php.dart';
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/scala.dart';
import 'package:highlight/languages/xml.dart';
import 'package:highlight/languages/yaml.dart';

/// Languages offered by this demo's picker.
///
/// `highlight` defines no `html` mode of its own: HTML — along with `xhtml`,
/// `rss`, `atom`, `xjb`, `xsd`, `xsl`, `plist`, `wsf` and `svg` — is one of the
/// aliases of its `xml` mode, so both entries below deliberately share a single
/// `Mode` instance. See
/// [issue #40](https://github.com/arrrrny/zuraffa_code_editor/issues/40).
final builtinLanguages = {
  'dart': dart,
  'go': go,
  'html': xml,
  'java': java,
  'php': php,
  'python': python,
  'scala': scala,
  'xml': xml,
  'yaml': yaml,
};

const languageList = <String>[
  'dart',
  'go',
  'html',
  'java',
  'php',
  'python',
  'scala',
  'xml',
  'yaml',
];

const themeList = <String>[
  'a11y-dark',
  'an-old-hope',
  'atom-one-dark',
  'monokai-sublime',
  'vs',
  'vs2015',
];
