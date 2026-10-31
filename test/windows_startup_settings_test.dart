// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/components/app_toggle.dart';
import 'package:aoravpn/components/windows_startup_settings.dart';
import 'package:aoravpn/controllers/windows_startup_controller.dart';
import 'package:aoravpn/l10n/app_localizations.dart';
import 'package:aoravpn/theme/app_theme.dart';

void main() {
  test('Failed startup changes retain the last confirmed values', () async {
    var fail = false;
    final controller = WindowsStartupController(
      request: (preferences) async {
        if (fail) throw StateError('Task registration failed');
        return preferences ??
            {'startWithWindows': false, 'startMinimized': true};
      },
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    expect(controller.startMinimized, isTrue);
    fail = true;
    await controller.update(startWithWindows: true, startMinimized: false);
    expect(controller.failed, isTrue);
    expect(controller.startWithWindows, isFalse);
    expect(controller.startMinimized, isTrue);
  });

  test(
    'Startup changes cannot overlap or notify a disposed controller',
    () async {
      final pending = Completer<Map<String, dynamic>>();
      var requests = 0;
      final controller = WindowsStartupController(
        request: (_) {
          requests++;
          return pending.future;
        },
      );
      final loading = controller.initialize();
      await controller.initialize();
      expect(requests, 1);
      controller.dispose();
      pending.complete({'startWithWindows': false, 'startMinimized': false});
      await loading;
    },
  );

  testWidgets(
    'Startup controls use shared toggles and persist independent choices',
    (tester) async {
      var saved = <String, dynamic>{
        'startWithWindows': false,
        'startMinimized': false,
      };
      final controller = WindowsStartupController(
        request: (preferences) async {
          if (preferences != null) saved = Map.of(preferences);
          return Map.of(saved);
        },
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ListView(
              children: [WindowsStartupSettings(controller: controller)],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Startup'));
      await tester.pumpAndSettle();
      expect(find.byType(AppToggle), findsNWidgets(2));
      await tester.tap(find.byType(AppToggle).first);
      await tester.pumpAndSettle();
      expect(saved['startWithWindows'], isTrue);
      expect(saved['startMinimized'], isFalse);
      await tester.tap(find.byType(AppToggle).last);
      await tester.pumpAndSettle();
      expect(saved['startWithWindows'], isTrue);
      expect(saved['startMinimized'], isTrue);
      expect(
        find.text('Opening the app does not connect the VPN automatically.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      final restored = WindowsStartupController(
        request: (_) async => Map.of(saved),
      );
      await restored.initialize();
      expect(restored.startWithWindows, isTrue);
      expect(restored.startMinimized, isTrue);
      restored.dispose();
    },
  );
}
