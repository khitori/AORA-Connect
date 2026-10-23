// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/components/app_action_button.dart';
import 'package:aoravpn/components/app_select.dart';
import 'package:aoravpn/theme/app_theme.dart';

void main() {
  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets('$platform buttons and selects paint at the same height', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light.copyWith(platform: platform),
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: Column(
                children: [
                  AppSelect<String>(
                    value: 'a',
                    items: const [
                      DropdownMenuItem(
                        value: 'a',
                        child: Text('Through tunnel'),
                      ),
                    ],
                    onChanged: (_) {},
                  ),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add),
                    label: const Text('Add rule'),
                  ),
                  FilledButton(onPressed: () {}, child: const Text('Save')),
                  TextButton(onPressed: () {}, child: const Text('Cancel')),
                  AppActionButton(label: 'Download update', onPressed: () {}),
                  SizedBox(
                    height: AppTheme.controlHeight,
                    child: OutlinedButton(
                      onPressed: () {},
                      child: const Text('Add subscription'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final select = find.byType(AppSelect<String>);
      final height = tester.getSize(select).height;
      expect(height, AppTheme.controlHeight);
      final buttons = find.byWidgetPredicate(
        (w) => w is OutlinedButton || w is FilledButton || w is TextButton,
      );
      expect(buttons, findsNWidgets(5));
      for (final element in buttons.evaluate()) {
        final material = find
            .descendant(
              of: find.byWidget(element.widget),
              matching: find.byType(Material),
            )
            .first;
        expect(tester.getSize(material).height, height);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
