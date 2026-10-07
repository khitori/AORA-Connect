// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/components/morphing_menu.dart';

void main() {
  testWidgets(
    'Expanded surface follows spacing and added content without clipping',
    (tester) async {
      tester.view.physicalSize = const Size(420, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Widget app({required int count, required double spacing}) => MaterialApp(
        home: MorphingMenuShell<int>(
          selected: 0,
          onSelected: (_) {},
          itemSpacing: spacing,
          entries: List.generate(
            count,
            (index) => MorphingMenuEntry(index, 'Entry $index', Icons.settings),
          ),
          child: const Scaffold(),
        ),
      );

      Finder button(int index) => find
          .ancestor(
            of: find.text('Entry $index'),
            matching: find.byWidgetPredicate((widget) => widget is TextButton),
          )
          .first;

      await tester.pumpWidget(app(count: 2, spacing: 8));
      await tester.tap(find.byTooltip('Open menu'));
      await tester.pumpAndSettle();
      final surface = find.byKey(const ValueKey('morphing-menu-surface'));
      final originalBounds = tester.getRect(surface);
      expect(
        tester.getRect(button(1)).top - tester.getRect(button(0)).bottom,
        8,
      );

      await tester.pumpWidget(app(count: 3, spacing: 32));
      await tester.pumpAndSettle();
      final enlargedBounds = tester.getRect(surface);
      expect(enlargedBounds.height, greaterThan(originalBounds.height));
      expect(enlargedBounds.topRight, originalBounds.topRight);
      expect(
        tester.getRect(button(2)).top - tester.getRect(button(1)).bottom,
        32,
      );
      expect(enlargedBounds.bottom - tester.getRect(button(2)).bottom, 12);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Close menu'));
      await tester.pumpAndSettle();
      expect(tester.getSize(surface), const Size(44, 44));
    },
  );
}
