// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/components/app_toggle.dart';
import 'package:aoravpn/theme/app_colors.dart';

void main() {
  testWidgets(
    'Borderless toggle keeps the same thumb size and supports keyboard',
    (tester) async {
      var value = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, setState) => AppToggle(
                value: value,
                onChanged: (next) => setState(() => value = next),
              ),
            ),
          ),
        ),
      );
      final track = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      expect((track.decoration as BoxDecoration).border, isNull);
      expect((track.decoration as BoxDecoration).color, AppColors.lineStrong);
      expect(tester.getSize(find.byType(AppToggle)), const Size(48, 48));
      final thumb = find.descendant(
        of: find.byType(AnimatedAlign),
        matching: find.byType(Container),
      );
      expect(tester.getSize(thumb), const Size(20, 20));
      await tester.tap(find.byType(AppToggle));
      await tester.pumpAndSettle();
      expect(value, isTrue);
      expect(tester.getSize(thumb), const Size(20, 20));
      expect(
        (tester
                    .widget<AnimatedContainer>(find.byType(AnimatedContainer))
                    .decoration
                as BoxDecoration)
            .color,
        AppColors.accent,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(value, isFalse);
    },
  );

  testWidgets('Disabled toggle exposes its state and cannot change', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppToggle(
            value: true,
            onChanged: null,
            semanticLabel: 'Statistics',
          ),
        ),
      ),
    );
    await tester.tap(find.byType(AppToggle));
    await tester.pumpAndSettle();
    expect(tester.widget<AppToggle>(find.byType(AppToggle)).value, isTrue);
    expect(
      tester.getSemantics(find.byType(AppToggle)),
      matchesSemantics(
        label: 'Statistics',
        hasEnabledState: true,
        isEnabled: false,
        hasToggledState: true,
        isToggled: true,
      ),
    );
    semantics.dispose();
  });
}
