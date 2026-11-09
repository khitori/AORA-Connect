// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/app.dart';
import 'package:aoravpn/components/app_select.dart';
import 'package:aoravpn/pages/settings_page.dart';
import 'package:aoravpn/theme/app_colors.dart';
import 'package:aoravpn/theme/theme_controller.dart';

import 'widget_test.dart' show FakeEngine;

class _MemoryThemeStore implements ThemeStore {
  _MemoryThemeStore([this.saved = ThemeChoice.system]);
  ThemeChoice saved;
  bool failWrites = false;

  @override
  Future<ThemeChoice> read() async => saved;

  @override
  Future<void> write(ThemeChoice choice) async {
    if (failWrites) throw StateError('No service');
    saved = choice;
  }
}

void main() {
  tearDown(() => AppColors.current = AppColors.light);

  test('The saved theme is loaded and a new choice is saved', () async {
    final store = _MemoryThemeStore(ThemeChoice.dark);
    final controller = ThemeController(store: store);
    addTearDown(controller.dispose);
    expect(controller.choice, ThemeChoice.light);
    await controller.initialize();
    expect(controller.choice, ThemeChoice.dark);
    await controller.select(ThemeChoice.light);
    expect(controller.choice, ThemeChoice.light);
    expect(store.saved, ThemeChoice.light);
  });

  test('A theme that cannot be saved still applies', () async {
    final store = _MemoryThemeStore()..failWrites = true;
    final controller = ThemeController(store: store);
    addTearDown(controller.dispose);
    await expectLater(controller.select(ThemeChoice.dark), throwsStateError);
    expect(controller.choice, ThemeChoice.dark);
  });

  test('The file store keeps the choice', () async {
    final directory = await Directory.systemTemp.createTemp('theme-');
    addTearDown(() => directory.delete(recursive: true));
    final store = FileThemeStore(directory: directory);
    expect(await store.read(), ThemeChoice.light);
    await store.write(ThemeChoice.dark);
    expect(await store.read(), ThemeChoice.dark);
  });

  testWidgets('Choosing Dark in Settings switches the whole app', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = FakeEngine();
    await tester.pumpWidget(MyApp(engine: engine));
    await tester.tap(find.byKey(const ValueKey('open-settings')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(AppColors.isDark, isFalse);

    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AppSelect<ThemeChoice>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(AppColors.isDark, isTrue);
    expect(
      Theme.of(tester.element(find.byType(SettingsPage))).brightness,
      Brightness.dark,
    );
    expect(
      tester.widget<AnimatedTheme>(find.byType(AnimatedTheme)).duration,
      Duration.zero,
    );
    // The section's value follows, and nothing failed while redrawing.
    expect(find.text('Dark'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await engine.changes.close();
    await engine.messages.close();
  });

  testWidgets('A hot reload picks up edited palette values', (tester) async {
    final engine = FakeEngine();
    await tester.pumpWidget(MyApp(engine: engine));
    await tester.pumpAndSettle();
    final before = AppColors.current;

    // Finishes with the next frame, so the frame is pumped before waiting.
    final reload = tester.binding.reassembleApplication();
    await tester.pump();
    await reload;
    await tester.pumpAndSettle();

    expect(AppColors.current, isNot(same(before)));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await engine.changes.close();
    await engine.messages.close();
  });
}
