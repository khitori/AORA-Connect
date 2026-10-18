// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/components/installed_application_picker.dart';
import 'package:aoravpn/components/routing_rule_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var fail = false;
  var calls = 0;
  setUp(() {
    fail = false;
    calls = 0;
    messenger.setMockMethodCallHandler(InstalledApplication.channel, (
      call,
    ) async {
      expect(call.method, 'listInstalled');
      calls++;
      if (fail) throw PlatformException(code: 'APPLICATIONS');
      return [
        {'packageName': 'com.example.zebra', 'label': 'Zebra'},
        {'packageName': 'com.example.browser', 'label': 'Browser'},
        {'packageName': 'com.example.browser', 'label': 'Browser'},
      ];
    });
  });
  tearDown(
    () =>
        messenger.setMockMethodCallHandler(InstalledApplication.channel, null),
  );

  test(
    'Installed applications are sorted and deduplicated by package',
    () async {
      final apps = await InstalledApplication.load();
      expect(apps.map((app) => app.label), ['Browser', 'Zebra']);
      expect(apps.first.packageName, 'com.example.browser');
    },
  );

  Future<void> open(WidgetTester tester, ValueChanged<String?> selected) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selected(await showInstalledApplicationPicker(context));
              },
              child: const Text('Choose'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
  }

  testWidgets('Picker uses wider mobile content without overflowing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await open(tester, (_) {});
    expect(tester.getSize(find.byType(TextField)).width, 264);
    expect(
      tester.getRect(find.text('Cancel')).left -
          tester.getRect(find.text('Refresh')).right,
      greaterThan(24),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Rule editor uses short single-line application label on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showRoutingRuleEditor(context),
                child: const Text('Add'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(TextFormField)).width, 264);
      expect(find.text('Choose application'), findsOneWidget);
      expect(
        tester.getRect(find.text('Save')).left -
            tester.getRect(find.text('Cancel')).right,
        greaterThan(24),
      );
      expect(
        tester.getSize(find.text('Choose application')).height,
        lessThan(30),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Search matches labels and packages; selection returns package, not label',
    (tester) async {
      String? selected;
      await open(tester, (value) => selected = value);
      expect(find.text('Browser'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'ZEBRA');
      await tester.pump();
      expect(find.text('Browser'), findsNothing);
      expect(find.text('Zebra'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'com.example.browser');
      await tester.pump();
      await tester.tap(find.text('Browser'));
      await tester.pumpAndSettle();
      expect(selected, 'com.example.browser');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Load failure can be retried and cancel does not select anything',
    (tester) async {
      fail = true;
      final selected = Completer<String?>();
      await open(tester, selected.complete);
      expect(
        find.textContaining('Could not load applications.'),
        findsOneWidget,
      );
      fail = false;
      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Browser'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await selected.future, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
