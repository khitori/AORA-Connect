// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/components/app_select.dart';
import 'package:aoravpn/components/app_toggle.dart';
import 'package:aoravpn/components/subscription_input.dart';
import 'package:aoravpn/l10n/l10n.dart';

void main() {
  test(
    'Arabic uses all six count forms; Persian uses its own translation',
    () async {
      final ar = await AppLocalizations.delegate.load(const Locale('ar'));
      final fa = await AppLocalizations.delegate.load(const Locale('fa'));
      expect([0, 1, 2, 3, 11, 100].map(ar.serverCount).toSet(), hasLength(6));
      expect(ar.serverCount(2), 'خادمان');
      expect(fa.serverCount(2), '2 سرور');
      expect(isRtlLocale(ar), isTrue);
      expect(isRtlLocale(fa), isTrue);
    },
  );

  test(
    'Technical values are isolated only for display in RTL sentences',
    () async {
      const address = 'https://example.org/sub?id=abc&v=1';
      final ar = await AppLocalizations.delegate.load(const Locale('ar'));
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      expect(isolateTechnicalValue(ar, address), '\u2066$address\u2069');
      expect(isolateTechnicalValue(en, address), address);
      expect(address, 'https://example.org/sub?id=abc&v=1');
      expect(textDirectionFor('خادم إيران'), TextDirection.rtl);
      expect(textDirectionFor('Sweden 1'), TextDirection.ltr);
    },
  );

  testWidgets('Enabled toggle mirrors its thumb without changing its value', (
    tester,
  ) async {
    Future<double> thumbX(TextDirection direction) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Directionality(
                textDirection: direction,
                child: AppToggle(value: true, onChanged: (_) {}),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final alignment = find.descendant(
        of: find.byType(AppToggle),
        matching: find.byType(AnimatedAlign),
      );
      final thumb = find.descendant(
        of: alignment,
        matching: find.byType(Container),
      );
      return tester.getCenter(thumb).dx;
    }

    final ltr = await thumbX(TextDirection.ltr);
    final rtl = await thumbX(TextDirection.rtl);
    expect(rtl, lessThan(ltr));
    expect(tester.widget<AppToggle>(find.byType(AppToggle)).value, isTrue);
  });

  test('Hebrew has localized plural forms and uses RTL', () async {
    final he = await AppLocalizations.delegate.load(const Locale('he'));
    expect(isRtlLocale(he), isTrue);
    expect(he.serverCount(1), 'שרת אחד');
    expect(he.serverCount(2), 'שני שרתים');
    expect(he.serverCount(3), '3 שרתים');
    expect(he.daysLeft(1), 'נותר יום אחד');
    expect(he.daysLeft(2), 'נותרו יומיים');
    expect(he.daysLeft(10), 'נותרו 10 ימים');
    expect(textDirectionFor('שרת ישראל'), TextDirection.rtl);
    expect(isolateTechnicalValue(he, '1.1.4+8'), '\u20661.1.4+8\u2069');
  });

  for (final code in ['ar', 'fa', 'he']) {
    testWidgets('$code connection links stay LTR and are submitted unchanged', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(code),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: SubscriptionInput(
              controller: controller,
              enabled: true,
              onLoad: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final field = find.byType(TextField);
      expect(Directionality.of(tester.element(field)), TextDirection.rtl);
      expect(tester.widget<TextField>(field).textDirection, TextDirection.ltr);
      const link = 'https://example.org/sub?token=abc123';
      await tester.enterText(field, link);
      expect(controller.text, link);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Selector popup inherits local RTL even inside an English app', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: AppSelect<String>(
                  value: 'a',
                  items: const [
                    DropdownMenuItem(value: 'a', child: Text('First')),
                    DropdownMenuItem(value: 'b', child: Text('Second')),
                  ],
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(AppSelect<String>));
    await tester.pumpAndSettle();
    expect(
      Directionality.of(tester.element(find.text('Second'))),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
  });
}
