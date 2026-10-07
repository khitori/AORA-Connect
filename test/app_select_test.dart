// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/components/app_select.dart';

void main() {
  testWidgets('Selector opens below at matching width and scrolls long lists', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    int? selection;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
            child: AppSelect<int>(
              value: 19,
              items: List.generate(
                20,
                (index) => DropdownMenuItem(
                  value: index,
                  child: Text('Option $index'),
                ),
              ),
              onChanged: (value) => selection = value,
            ),
          ),
        ),
      ),
    );
    final field = find.byType(AppSelect<int>);
    final anchor = tester.getRect(field);
    await tester.tap(field);
    await tester.pumpAndSettle();
    final menu = find.byKey(const ValueKey('app-select-menu'));
    final bounds = tester.getRect(menu);
    expect(bounds.top, anchor.bottom + 4);
    expect(bounds.left, anchor.left);
    expect(bounds.width, anchor.width);
    expect(bounds.bottom, lessThanOrEqualTo(308));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Option 0'));
    await tester.pumpAndSettle();
    expect(selection, 0);
    expect(menu, findsNothing);
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(menu, findsNothing);
  });
}
