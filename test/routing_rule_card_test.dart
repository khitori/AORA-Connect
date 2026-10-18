// SPDX-License-Identifier: GPL-3.0-or-later
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
        theme: AppTheme.light,
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
    final edit = tester.getRect(find.text('Edit'));
    expect(toggle.top, lessThan(title.bottom));
    expect(edit.top, greaterThan(toggle.bottom));
    expect(tester.getSize(find.byType(RoutingRuleCard)).height, lessThan(125));
    expect(find.text('1 · Application'), findsNothing);
    await tester.tap(find.byType(AppToggle));
    await tester.tap(find.byTooltip('Move up'));
    await tester.tap(find.byTooltip('Move down'));
    await tester.tap(find.text('Edit'));
    await tester.tap(find.byTooltip('Delete rule'));
    expect(actions, ['toggle:false', 'up', 'down', 'edit', 'delete']);
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
        theme: AppTheme.light,
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
    expect(
      tester.widget<TextButton>(find.byType(TextButton)).onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}
