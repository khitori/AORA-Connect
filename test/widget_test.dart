// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/app.dart';
import 'package:aoravpn/components/app_select.dart';
import 'package:aoravpn/core/tunnel_engine.dart';
import 'package:aoravpn/core/connection_mode.dart';

class FakeEngine implements TunnelEngine {
  final changes = StreamController<TunnelState>.broadcast();
  final messages = StreamController<String>.broadcast();
  @override
  TunnelState state = TunnelState.stopped;
  @override
  Stream<TunnelState> get states => changes.stream;
  @override
  Stream<String> get logs => messages.stream;
  @override
  Future<void> validate(String configPath) async {}
  @override
  Future<void> start(String configPath) async {
    state = TunnelState.running;
    changes.add(state);
    messages.add('Test core started');
  }

  @override
  Future<void> stop() async {
    state = TunnelState.stopped;
    changes.add(state);
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets(
    'Connect stays visible without a subscription and prompts before starting',
    (tester) async {
      tester.view.physicalSize = const Size(420, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final engine = FakeEngine();
      await tester.pumpWidget(MyApp(engine: engine));
      expect(find.text('Connect'), findsOneWidget);
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();
      expect(
        find.text('Load a subscription and select a server first.'),
        findsOneWidget,
      );
      expect(engine.state, TunnelState.stopped);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await engine.changes.close();
      await engine.messages.close();
    },
  );

  testWidgets(
    'Menu opens settings, changes mode and returns without losing input',
    (tester) async {
      tester.view.physicalSize = const Size(420, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final engine = FakeEngine();
      await tester.pumpWidget(MyApp(engine: engine, configPath: 'test.json'));
      expect(tester.takeException(), isNull);
      await tester.enterText(
        find.byType(TextField),
        'https://example.test/sub/demo',
      );
      expect(find.byType(AppSelect<ConnectionMode>), findsNothing);
      final surface = find.byKey(const ValueKey('morphing-menu-surface'));
      final closedBounds = tester.getRect(surface);
      expect(closedBounds.size, const Size(44, 44));
      await tester.tap(find.byTooltip('Open menu'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));
      final midwayBounds = tester.getRect(surface);
      expect(midwayBounds.width, greaterThan(44));
      expect(midwayBounds.width, lessThan(208));
      expect(midwayBounds.topRight, closedBounds.topRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(tester.getSize(surface), const Size(44, 44));
      expect(find.text('Connection'), findsNothing);
      await tester.tap(find.byTooltip('Open menu'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(24, 250));
      await tester.pumpAndSettle();
      expect(tester.getSize(surface), const Size(44, 44));
      await tester.tap(find.byTooltip('Open menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      expect(find.text('Connection mode'), findsOneWidget);
      final selector = tester.widget<AppSelect<ConnectionMode>>(
        find.byType(AppSelect<ConnectionMode>),
      );
      expect(selector.value, ConnectionMode.tun);
      await tester.tap(find.byType(AppSelect<ConnectionMode>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Local proxy').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back to connection'));
      await tester.pumpAndSettle();
      expect(find.text('Local proxy'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'https://example.test/sub/demo',
      );
      await tester.pumpWidget(const SizedBox());
      await engine.changes.close();
      await engine.messages.close();
    },
  );

  testWidgets('Controls reflect the core lifecycle and display logs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = FakeEngine();
    await tester.pumpWidget(MyApp(engine: engine, configPath: 'test.json'));
    expect(tester.takeException(), isNull);
    expect(find.text('Core: stopped'), findsOneWidget);
    expect(find.text('VPN (TUN)'), findsOneWidget);
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    expect(find.text('Core: running'), findsOneWidget);
    await tester.tap(find.text('Diagnostics'));
    await tester.pumpAndSettle();
    expect(find.text('Test core started'), findsOneWidget);
    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AppSelect<ConnectionMode>>(
            find.byType(AppSelect<ConnectionMode>),
          )
          .onChanged,
      isNull,
    );
    expect(find.text('License: GNU GPL version 3 or later.'), findsOneWidget);
    expect(engine.state, TunnelState.running);
    await tester.tap(find.byTooltip('Back to connection'));
    await tester.pumpAndSettle();
    expect(find.text('Core: running'), findsOneWidget);
    await tester.ensureVisible(find.text('Disconnect'));
    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();
    expect(find.text('Core: stopped'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await engine.changes.close();
    await engine.messages.close();
  });
}
