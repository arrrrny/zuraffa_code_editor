import 'package:flutter/services.dart';
import 'package:zuraffa_code_editor/src/code/key_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KeyEventExtension', () {
    LogicalKeyboardKey keyF() => LogicalKeyboardKey.keyF;

    test('isCtrlF is false for any key that is not F', () {
      final event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyG,
        logicalKey: LogicalKeyboardKey.keyG,
        character: null,
        timeStamp: Duration.zero,
      );

      expect(event.isCtrlF({LogicalKeyboardKey.controlLeft}), isFalse);
    });

    test('isCtrlF is false without a modifier', () {
      final event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyF,
        logicalKey: keyF(),
        character: 'f',
        timeStamp: Duration.zero,
      );

      expect(event.isCtrlF(const {}), isFalse);
    });

    test('isCtrlF is true for every one of the four modifier keys', () {
      for (final modifier in const [
        LogicalKeyboardKey.metaLeft,
        LogicalKeyboardKey.metaRight,
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.controlRight,
      ]) {
        final event = KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyF,
          logicalKey: keyF(),
          character: 'f',
          timeStamp: Duration.zero,
        );

        expect(
          event.isCtrlF({modifier}),
          isTrue,
          reason: 'Ctrl/Meta-F opens search from any of the four keys',
        );
      }
    });
  });
}
