import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../common/create_app.dart';
import '../common/snippets.dart';

void main() {
  group('CodeController.foldBlocks.', () {
    test('Folds every given block, matching the foldAt loop', () {
      final batch = createController(TwoMethodsSnippet.full);
      final loop = createController(TwoMethodsSnippet.full);
      final blocks = batch.code.foldableBlocks.toList();

      batch.foldBlocks(blocks);
      for (final block in blocks) {
        loop.foldAt(block.firstLine);
      }

      expect(batch.code.foldedBlocks, loop.code.foldedBlocks);
      expect(batch.code.hiddenRanges, loop.code.hiddenRanges);
      expect(batch.code.visibleText, loop.code.visibleText);
      expect(batch.text, loop.text);
    });

    test('One value assignment and one listener notification for N blocks', () {
      final batch = createController(TwoMethodsSnippet.full);
      final loop = createController(TwoMethodsSnippet.full);
      // Leaf blocks only. Folding a block nested inside an already folded
      // one leaves the visible value equal, so the loop notifies less than
      // once per block; the pathology this pins is N independent folds.
      final all = batch.code.foldableBlocks.toList();
      final blocks = all
          .where(
            (block) => all.every(
              (other) =>
                  other == block ||
                  other.firstLine < block.firstLine ||
                  other.lastLine > block.lastLine,
            ),
          )
          .toList();
      for (var i = 0; i < blocks.length; i++) {
        for (var j = i + 1; j < blocks.length; j++) {
          expect(
            blocks[i].lastLine < blocks[j].firstLine ||
                blocks[j].lastLine < blocks[i].firstLine,
            true,
            reason:
                'blocks must be pairwise disjoint for the loop to notify '
                'once per fold',
          );
        }
      }
      expect(
        blocks.length,
        greaterThan(1),
        reason: 'a batch of one block proves nothing',
      );

      var batchNotifications = 0;
      batch.addListener(() => batchNotifications++);
      var loopNotifications = 0;
      loop.addListener(() => loopNotifications++);

      batch.foldBlocks(blocks);
      for (final block in blocks) {
        loop.foldAt(block.firstLine);
      }

      expect(batchNotifications, 1);
      expect(loopNotifications, blocks.length);
      expect(batch.value, loop.value);
    });

    test('Skips already-folded blocks without extra work', () {
      final controller = createController(TwoMethodsSnippet.full);
      final blocks = controller.code.foldableBlocks.toList();

      controller.foldBlocks(blocks);

      var notifications = 0;
      controller.addListener(() => notifications++);
      final codeBefore = controller.code;

      controller.foldBlocks(blocks);

      expect(notifications, 0);
      expect(controller.code, codeBefore);
    });

    test('Skips stale blocks the current code no longer holds', () {
      final controller = createController(TwoMethodsSnippet.full);
      final other = createController(MethodSnippet.full);

      var notifications = 0;
      controller.addListener(() => notifications++);
      final codeBefore = controller.code;

      controller.foldBlocks(other.code.foldableBlocks);

      expect(notifications, 0);
      expect(controller.code, codeBefore);
    });

    test('Selection recovery through a batch matches the single-fold path', () {
      final batch = createController(TwoMethodsSnippet.full);
      final loop = createController(TwoMethodsSnippet.full);
      final blocks = batch.code.foldableBlocks.toList();

      final start = batch.text.indexOf('    return;');
      final selection = TextSelection(
        baseOffset: start,
        extentOffset: start + 15,
      );

      batch.selection = selection;
      loop.selection = selection;

      batch.foldBlocks(blocks);
      for (final block in blocks) {
        loop.foldAt(block.firstLine);
      }

      expect(batch.value.selection, loop.value.selection);

      for (final block in blocks) {
        batch.unfoldAt(block.firstLine);
        loop.unfoldAt(block.firstLine);
      }

      expect(batch.selection, loop.selection);
      expect(batch.selection, selection);
    });
  });
}
