// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/components/app_dialog.dart';
import 'package:aoravpn/components/core_logs.dart';
import 'package:aoravpn/components/pill_button.dart';
import 'package:aoravpn/l10n/app_localizations.dart';
import 'package:aoravpn/theme/app_theme.dart';

void main() {
  Future<void> mount(WidgetTester tester, List<String> lines) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.current,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Align(
                alignment: Alignment.topCenter,
                child: CoreLogs(lines: lines),
              ),
            ),
          ),
        ),
      );

  testWidgets('Clicking the logs opens them all and Copy copies them', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final lines = [for (var i = 1; i <= 20; i++) 'line $i'];
    await mount(tester, lines);
    // The box previews only the newest lines.
    expect(find.textContaining('line 20'), findsOneWidget);
    expect(find.textContaining('line 1\n'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('core-logs-open')));
    await tester.pumpAndSettle();
    expect(find.byType(AppDialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppDialog),
        matching: find.text(lines.join('\n')),
      ),
      findsOneWidget,
    );
    // Copy is the blue button, above Close.
    final copy = find.byKey(const ValueKey('copy-core-logs'));
    expect(tester.widget<PillButton>(copy).multiplyColor, isNotNull);
    expect(
      tester.getRect(copy).bottom,
      lessThan(tester.getRect(find.text('Close')).top),
    );

    await tester.tap(copy);
    await tester.pumpAndSettle();
    expect(copied, lines.join('\n'));
    expect(find.byType(AppDialog), findsNothing);
    expect(find.text('Logs copied.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Without logs Copy is off and Close closes the dialog', (
    tester,
  ) async {
    await mount(tester, const []);
    expect(find.text('No logs yet.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('core-logs-open')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<PillButton>(find.byKey(const ValueKey('copy-core-logs')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(AppDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
