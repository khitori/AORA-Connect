// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/components/app_toggle.dart';
import 'package:aoravpn/components/installed_application_picker.dart';
import 'package:aoravpn/components/routing_rule_card.dart';
import 'package:aoravpn/routing/routing_policy.dart';
import 'package:aoravpn/theme/app_theme.dart';

void main() {
  const rule = RoutingRule(
    match: RoutingMatch.application,
    target: 'com.microsoft.emmx',
  );
  const application = InstalledApplication(
    packageName: 'com.microsoft.emmx',
    label: 'Microsoft Edge',
  );

  testWidgets('Compact card separates identity, toggle and working actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final actions = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.current,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Align(
              alignment: Alignment.topCenter,
              child: RoutingRuleCard(
                rule: rule,
                application: application,
                onEnabledChanged: (value) => actions.add('toggle:$value'),
                onMoveUp: () => actions.add('up'),
                onMoveDown: () => actions.add('down'),
                onEdit: () => actions.add('edit'),
                onDelete: () => actions.add('delete'),
              ),
            ),
          ),
        ),
      ),
    );
    final toggle = tester.getRect(find.byType(AppToggle));
    final title = tester.getRect(find.text('Microsoft Edge'));
    final settings = tester.getRect(find.byTooltip('Rule actions'));
    expect(toggle.top, lessThan(title.bottom));
    expect(settings.left, greaterThan(toggle.right));
    // The actions stay hidden until the settings button opens them.
    expect(find.byTooltip('Move up'), findsNothing);
    expect(tester.getSize(find.byType(RoutingRuleCard)).height, lessThan(90));
    expect(find.text('1 · Application'), findsNothing);
    await tester.tap(find.byType(AppToggle));

    Future<void> run(String action) async {
      await tester.tap(find.byTooltip('Rule actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(action));
      await tester.pumpAndSettle();
      // Running an action closes the bubble.
      expect(find.byTooltip(action), findsNothing);
    }

    // The bubble shows the actions in one row above the settings button.
    await tester.tap(find.byTooltip('Rule actions'));
    await tester.pumpAndSettle();
    final row = [
      'Move up',
      'Move down',
      'Edit rule',
      'Delete rule',
    ].map((action) => tester.getRect(find.byTooltip(action))).toList();
    for (var i = 1; i < row.length; i++) {
      expect(row[i].top, row[0].top);
      expect(row[i].left, greaterThan(row[i - 1].right - 0.01));
    }
    expect(row.last.bottom, lessThan(settings.top));
    // A tap outside closes it without running anything.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Move up'), findsNothing);

    for (final action in ['Move up', 'Move down', 'Edit rule', 'Delete rule']) {
      await run(action);
    }
    expect(actions, ['toggle:false', 'up', 'down', 'edit', 'delete']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Hovering the action bubble shows tooltips without errors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.current,
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.fromLTRB(24, 200, 24, 24),
            children: [
              for (final target in ['one.exe', 'two.exe'])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: RoutingRuleCard(
                    rule: RoutingRule(
                      match: RoutingMatch.application,
                      target: target,
                    ),
                    onMoveUp: () {},
                    onMoveDown: () {},
                    onEdit: () {},
                    onDelete: () {},
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await tester.tap(find.byTooltip('Rule actions').first);
    await tester.pumpAndSettle();
    for (final action in ['Move up', 'Move down', 'Edit rule', 'Delete rule']) {
      await mouse.moveTo(tester.getCenter(find.byTooltip(action)));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    }
    // The bubble sits above its card's settings button.
    expect(
      tester.getRect(find.byTooltip('Move up')).bottom,
      lessThan(tester.getRect(find.byTooltip('Rule actions').first).top),
    );
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Move up'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Long names and disabled controls fit without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.current,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: RoutingRuleCard(
              rule: rule.withEnabled(false),
              application: const InstalledApplication(
                packageName: 'com.microsoft.emmx',
                label: 'An application with a particularly long name',
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.widget<AppToggle>(find.byType(AppToggle)).onChanged, isNull);
    await tester.tap(find.byTooltip('Rule actions'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.edit_rounded),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}
