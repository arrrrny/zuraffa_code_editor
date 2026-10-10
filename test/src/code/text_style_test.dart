import 'package:zuraffa_code_editor/src/code/text_style.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TextStyleExtension.paled', () {
    test('halves the alpha and keeps the colour channels', () {
      const style = TextStyle(color: Color(0xffc86432));

      final paled = style.paled();

      expect(paled.color, const Color(0x7fc86432));
      expect(paled.color!.a, closeTo(0.498, 1e-3));
      expect(paled.color!.r, style.color!.r);
      expect(paled.color!.g, style.color!.g);
      expect(paled.color!.b, style.color!.b);
    });

    test('a transparent colour fades away entirely', () {
      // `~/ 2` truncates, so an alpha of 1/255 rounds down to zero.
      expect(
        const TextStyle(color: Color(0x01ff0000)).paled().color,
        const Color(0x00ff0000),
      );
    });

    test('returns the style unchanged when there is no colour', () {
      const style = TextStyle();

      expect(style.paled(), same(style));
    });
  });

  group('TextStyleExtension.toMapString', () {
    test('renders a colour-carrying style', () {
      expect(
        const TextStyle(color: Color(0xff102030)).toMapString(),
        '{color: Color(alpha: 1.0000, red: 0.0627, green: 0.1255, blue: '
        '0.1882, colorSpace: ColorSpace.sRGB)}',
      );
    });

    test('drops the colour entry when the style has none', () {
      expect(const TextStyle().toMapString(), '{}');
    });
  });
}
