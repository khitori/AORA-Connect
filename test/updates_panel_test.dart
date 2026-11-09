// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/components/updates_panel.dart';
import 'package:aoravpn/components/pill_button.dart';
import 'package:aoravpn/components/app_dialog.dart';
import 'package:aoravpn/components/app_toggle.dart';
import 'package:aoravpn/controllers/connection_controller.dart';
import 'package:aoravpn/core/tunnel_engine.dart';
import 'package:aoravpn/theme/app_theme.dart';
import 'package:aoravpn/updates/update_controller.dart';

class _IdleEngine implements TunnelEngine {
  @override
  TunnelState get state => TunnelState.stopped;
  @override
  Stream<TunnelState> get states => const Stream.empty();
  @override
  Stream<String> get logs => const Stream.empty();
  @override
  Future<void> validate(String path) async {}
  @override
  Future<void> start(String path) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

Future<(UpdateController, Directory)> _mount(
  WidgetTester tester, {
  double width = 420,
}) async {
  tester.view.physicalSize = Size(width, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final directory = Directory.systemTemp.createTempSync('aora-update-dialog-');
  final updates = UpdateController(preferencesDirectory: directory);
  final connection = ConnectionController(
    engine: _IdleEngine(),
    xrayEngine: _IdleEngine(),
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    updates.dispose();
    await connection.shutdown();
    connection.dispose();
    directory.deleteSync(recursive: true);
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.current,
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            UpdatesPanel(
              updates: updates,
              connection: connection,
              onInstall: () async {},
            ),
          ],
        ),
      ),
    ),
  );
  await tester.tap(find.text('Updates'));
  await tester.pumpAndSettle();
  return (updates, directory);
}

Future<void> _openSources(WidgetTester tester) async {
  await tester.tap(find.text('Additional sources'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byType(TextField),
    'https://mirror.example/aora-update.json',
  );
}

Future<void> _expectClosed(WidgetTester tester) async {
  await tester.pump();
  expect(tester.takeException(), isNull);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  expect(find.byType(AppDialog), findsNothing);
}

void main() {
  testWidgets(
    'Closing a focused update sources dialog is safe during its transition',
    (tester) async {
      await _mount(tester);
      for (var i = 0; i < 3; i++) {
        await _openSources(tester);
        await tester.tap(find.text('Cancel'));
        await _expectClosed(tester);
      }
      await _openSources(tester);
      await tester.tapAt(const Offset(4, 4));
      await _expectClosed(tester);
      await _openSources(tester);
      Navigator.of(tester.element(find.byType(TextField))).pop();
      await _expectClosed(tester);
    },
  );

  testWidgets('Sources are validated in the dialog and saved before closing', (
    tester,
  ) async {
    final (updates, directory) = await _mount(tester);
    await _openSources(tester);
    await tester.enterText(find.byType(TextField), 'http://invalid.example');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.byType(AppDialog), findsOneWidget);
    expect(
      find.text('Update sources must be HTTPS URLs without credentials.'),
      findsOneWidget,
    );
    expect(updates.additionalSources, isEmpty);
    await tester.enterText(
      find.byType(TextField),
      ' https://mirror.example/aora-update.json \n\n',
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      for (var i = 0; i < 100 && updates.additionalSources.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    expect(updates.additionalSources, [
      'https://mirror.example/aora-update.json',
    ]);
    expect(
      jsonDecode(
        File('${directory.path}/updates.json').readAsStringSync(),
      )['sources'],
      updates.additionalSources,
    );
    await _expectClosed(tester);
    await tester.tap(find.text('1 additional sources'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'https://mirror.example/aora-update.json',
    );
    await tester.tap(find.text('Cancel'));
    await _expectClosed(tester);
  });

  for (final width in [360.0, 420.0]) {
    testWidgets('Update actions and dialog fit a $width px window', (
      tester,
    ) async {
      await _mount(tester, width: width);
      // Toggle row, then the status card, then one full-width main action
      // with From file and Sources each on its own line under it.
      final status = tester.getRect(
        find.byKey(const ValueKey('update-status')),
      );
      final main = tester.getRect(find.byKey(const ValueKey('check-updates')));
      final fromFile = tester.getRect(
        find.byKey(const ValueKey('update-from-file')),
      );
      final sources = tester.getRect(
        find.byKey(const ValueKey('update-sources')),
      );
      expect(
        tester.getRect(find.byType(AppToggle)).bottom,
        lessThan(status.top),
      );
      expect(main.top - status.bottom, AppTheme.sectionGap);
      expect(main.left, status.left);
      expect(main.right, status.right);
      expect(main.height, 48);
      expect(fromFile.top - main.bottom, AppTheme.sectionButtonGap);
      expect(sources.top - fromFile.bottom, AppTheme.sectionButtonGap);
      for (final pill in [fromFile, sources]) {
        expect(pill.left, main.left);
        expect(pill.right, main.right);
      }
      expect(fromFile.height, 48);
      expect(tester.takeException(), isNull);
      await _openSources(tester);
      // The glass dialog's pill column: blue Save above Cancel.
      final cancel = find.ancestor(
        of: find.text('Cancel'),
        matching: find.byType(PillButton),
      );
      final save = find.ancestor(
        of: find.text('Save'),
        matching: find.byType(PillButton),
      );
      final cancelRect = tester.getRect(cancel);
      final saveRect = tester.getRect(save);
      expect(tester.widget<PillButton>(save).multiplyColor, isNotNull);
      expect(cancelRect.width, saveRect.width);
      expect(cancelRect.left, saveRect.left);
      expect(cancelRect.top - saveRect.bottom, AppTheme.sectionButtonGap);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await _expectClosed(tester);
    });
  }
}
