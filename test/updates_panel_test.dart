// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/components/updates_panel.dart';
import 'package:aoravpn/components/app_action_button.dart';
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
      theme: AppTheme.light,
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
  expect(find.byType(AlertDialog), findsNothing);
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
    expect(find.byType(AlertDialog), findsOneWidget);
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
      final check = tester.getRect(find.byKey(const ValueKey('check-updates')));
      final fromFile = tester.getRect(
        find.byKey(const ValueKey('update-from-file')),
      );
      expect(check.width, fromFile.width);
      expect(check.top, fromFile.top);
      expect(fromFile.left - check.right, 8);
      expect(check.height, AppTheme.controlHeight);
      expect(tester.getSize(find.byType(AppToggle)), const Size(48, 36));
      expect(
        tester.getSize(find.byType(AnimatedContainer)),
        const Size(44, 26),
      );
      final separator = tester.getRect(find.byType(Divider));
      final track = tester.getRect(find.byType(AnimatedContainer));
      expect(track.top - separator.bottom, AppTheme.sectionContentTopPadding);
      expect(tester.takeException(), isNull);
      await _openSources(tester);
      final cancel = find.ancestor(
        of: find.text('Cancel'),
        matching: find.byType(AppActionButton),
      );
      final save = find.ancestor(
        of: find.text('Save'),
        matching: find.byType(AppActionButton),
      );
      final cancelRect = tester.getRect(cancel);
      final saveRect = tester.getRect(save);
      expect(cancelRect.width, saveRect.width);
      expect(saveRect.left - cancelRect.right, 8);
      expect(cancelRect.top, saveRect.top);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await _expectClosed(tester);
    });
  }
}
