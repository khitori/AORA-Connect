// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/components/app_dialog.dart';
import 'package:aoravpn/theme/app_theme.dart';

void main() {
  testWidgets('A dialog fades out while another dialog is open on top', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.current,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppDialog<void>(
                context: context,
                builder: (context) => AppDialog(
                  title: 'Lower',
                  content: TextButton(
                    onPressed: () => showAppDialog<void>(
                      context: context,
                      builder: (context) => AppDialog(
                        title: 'Upper',
                        content: const SizedBox(),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close upper'),
                          ),
                        ],
                      ),
                    ),
                    child: const Text('Open upper'),
                  ),
                  actions: const [],
                ),
              ),
              child: const Text('Open lower'),
            ),
          ),
        ),
      ),
    );
    double lowerOpacity() => tester
        .widget<Opacity>(
          find.ancestor(of: find.text('Lower'), matching: find.byType(Opacity)),
        )
        .opacity;

    await tester.tap(find.text('Open lower'));
    await tester.pumpAndSettle();
    expect(lowerOpacity(), 1);

    await tester.tap(find.text('Open upper'));
    await tester.pumpAndSettle();
    expect(lowerOpacity(), 0);
    expect(find.text('Upper'), findsOneWidget);

    await tester.tap(find.text('Close upper'));
    await tester.pumpAndSettle();
    expect(find.text('Upper'), findsNothing);
    expect(lowerOpacity(), 1);
    expect(tester.takeException(), isNull);
  });
}
