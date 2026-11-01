// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/components/app_toggle.dart';
import 'package:aoravpn/theme/app_colors.dart';

void main() {
  testWidgets(
    'Glass toggle: groove stays, knob turns red glass, keyboard works',
    (tester) async {
      List<Color> trackColors() =>
          ((tester
                              .widget<AnimatedContainer>(
                                find.byType(AnimatedContainer),
                              )
                              .decoration
                          as BoxDecoration)
                      .gradient!
                  as LinearGradient)
              .colors;
      final knob = find.byKey(const ValueKey('app-toggle-knob'));
      List<Color> knobColors() =>
          ((tester
                              .widget<DecoratedBox>(
                                find.descendant(
                                  of: knob,
                                  matching: find.byType(DecoratedBox),
                                ),
                              )
                              .decoration
                          as ShapeDecoration)
                      .gradient!
                  as LinearGradient)
              .colors;
      const groove = [AppColors.toggleGrooveTop, AppColors.toggleGrooveBottom];
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
      expect(trackColors(), groove);
      expect(knobColors(), [AppColors.glassTop, AppColors.glassBottom]);
      expect(tester.getSize(find.byType(AppToggle)), const Size(48, 48));
      expect(tester.getSize(knob), const Size(18, 18));
      await tester.tap(find.byType(AppToggle));
      await tester.pumpAndSettle();
      expect(value, isTrue);
      expect(tester.getSize(knob), const Size(18, 18));
      expect(trackColors(), groove);
      expect(knobColors(), [AppColors.accentDark, AppColors.accent]);
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
