// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:aoravpn/components/subscription_input.dart';
import 'package:aoravpn/components/connection_controls.dart';
import 'package:aoravpn/controllers/connection_controller.dart';
import 'package:aoravpn/controllers/statistics_controller.dart';
import 'package:aoravpn/core/diagnostics_report.dart';
import 'package:aoravpn/core/tunnel_engine.dart';
import 'package:aoravpn/pages/settings_page.dart';
import 'package:aoravpn/profiles/subscription_loader.dart';
import 'package:aoravpn/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Engine implements TunnelEngine {
  @override
  TunnelState get state => TunnelState.stopped;
  @override
  Stream<String> get logs => const Stream.empty();
  @override
  Stream<TunnelState> get states => const Stream.empty();
  @override
  Future<void> start(String path) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> validate(String path) async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );

  test(
    'paste validation accepts only supported single links without fetching',
    () {
      for (final text in [
        'https://example.com/sub/token',
        'hy2://secret@example.com:443#Test',
      ]) {
        expect(isSupportedSubscriptionInput(text), isTrue);
      }
      for (final text in [
        '',
        'hello',
        'http://example.com/sub',
        'https://user:secret@example.com/sub',
        'file:///tmp/sub',
        'javascript:alert(1)',
        'https://one.example/\nhttps://two.example/',
        'hy2://',
      ]) {
        expect(isSupportedSubscriptionInput(text), isFalse, reason: text);
      }
    },
  );

  test(
    'diagnostics never exports raw URLs, identifiers, config or unknown logs',
    () {
      final signals = diagnosticsSignals([
        'ERROR quic: transport closed: recvmsg: connection refused https://user:supersecret@private.example/sub/token',
        'timeout UUID=27afbe6e-116c-4c41-8ae5-18e9ced1c17a password=private-password',
        '{"password":"also-secret", "server":"private.example"}',
        'Unknown error with arbitrary-sensitive-data',
      ]);
      expect(signals, contains('Connection refused'));
      expect(signals, contains('QUIC transport closed'));
      expect(signals, contains('Timeout'));
      for (final secret in [
        'supersecret',
        'private.example',
        'private-password',
        '27afbe6e',
        'also-secret',
        'arbitrary-sensitive-data',
      ]) {
        expect(signals, isNot(contains(secret)));
      }
    },
  );

  test(
    'successful TLS stages and failed validation do not become false signals',
    () {
      expect(
        diagnosticsSignals([
          'Connection check: DNS lookup / connection (including TLS).',
        ]),
        'No recognized diagnostic signals recorded.',
      );
      expect(
        diagnosticsSignals(['Configuration validation failed']),
        '- Configuration validation failed',
      );
    },
  );

  test(
    'TLS failures in the combined connection stage are not DNS failures',
    () {
      final signals = diagnosticsSignals([
        'Connection verification failed (Cloudflare DNS): Bad state: '
            'Connection check failed during DNS lookup / connection: '
            'HandshakeException: Handshake error in client '
            'CERTIFICATE_VERIFY_FAILED: unable to get local issuer certificate',
      ]);
      expect(signals, contains('TLS/certificate issue'));
      expect(signals, contains('Connection verification failed'));
      expect(signals, isNot(contains('DNS lookup failed')));
      expect(
        diagnosticsSignals([
          'Connection check failed during DNS lookup / connection: '
              "SocketException: Failed host lookup: 'private.example'",
        ]),
        contains('DNS lookup failed'),
      );
    },
  );

  Future<void> input(
    WidgetTester tester,
    TextEditingController controller,
    VoidCallback onLoad, {
    bool enabled = true,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            child: SubscriptionInput(
              controller: controller,
              enabled: enabled,
              onLoad: onLoad,
            ),
          ),
        ),
      ),
    ),
  );

  for (final width in [280.0, 340.0]) {
    for (final scale in [1.0, 1.4]) {
      testWidgets('Diagnostics matches Updates layout at $width / $scale', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: width,
                    child: ConnectionControls(
                      onValidate: () {},
                      onTest: () {},
                      onCopy: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final validate = tester.getRect(
          find.widgetWithText(OutlinedButton, 'Check'),
        );
        final test = tester.getRect(
          find.widgetWithText(OutlinedButton, 'Test'),
        );
        final copy = tester.getRect(
          find.widgetWithText(OutlinedButton, 'Copy diagnostics'),
        );
        expect(validate.width, test.width);
        expect(validate.height, AppTheme.controlHeight);
        expect(test.top, validate.top);
        expect(test.left - validate.right, 8);
        expect(copy.left, validate.left);
        expect(copy.right, test.right);
        expect(copy.width, width);
        expect(copy.top - validate.bottom, 8);
        expect(copy.height, AppTheme.controlHeight);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'paste is a separate left-hand button with input-matching corners',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await input(tester, controller, () {});
      final pasteFinder = find.byKey(const ValueKey('paste-subscription'));
      final paste = tester.getRect(pasteFinder);
      final field = tester.getRect(find.byType(TextField));
      final add = tester.getRect(find.widgetWithText(OutlinedButton, 'Add'));
      expect(
        paste.size,
        const Size(AppTheme.controlHeight, AppTheme.controlHeight),
      );
      expect(field.left - paste.right, 8);
      expect(add.left - field.right, 8);
      expect(paste.top, field.top);
      expect(paste.bottom, field.bottom);
      final fieldWidget = tester.widget<TextField>(find.byType(TextField));
      expect(fieldWidget.decoration!.suffixIcon, isNull);
      final shape =
          tester
                  .widget<Material>(
                    find.descendant(
                      of: pasteFinder,
                      matching: find.byType(Material),
                    ),
                  )
                  .shape!
              as RoundedRectangleBorder;
      final inputBorder =
          Theme.of(tester.element(pasteFinder))
                  .inputDecorationTheme
                  .enabledBorder!
              as OutlineInputBorder;
      expect(shape.borderRadius, inputBorder.borderRadius);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('paste fills compact field but never imports automatically', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var imported = 0;
    var reads = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') {
            reads++;
            return {'text': '  https://example.com/sub/token  '};
          }
          return null;
        });
    await input(tester, controller, () => imported++);
    expect(reads, 0);
    expect(tester.getSize(find.byType(SubscriptionInput)).height, 36);
    await tester.tap(find.byTooltip('Paste from clipboard'));
    await tester.pumpAndSettle();
    expect(controller.text, 'https://example.com/sub/token');
    expect(imported, 0);
    await tester.tap(find.text('Add'));
    expect(imported, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'invalid clipboard preserves input and disabled input does not read it',
    (tester) async {
      final controller = TextEditingController(text: 'existing');
      addTearDown(controller.dispose);
      var reads = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.getData') {
              reads++;
              return {'text': 'not a link'};
            }
            return null;
          });
      await input(tester, controller, () {});
      await tester.tap(find.byTooltip('Paste from clipboard'));
      await tester.pumpAndSettle();
      expect(controller.text, 'existing');
      expect(
        find.text('Copy a valid subscription or server link first.'),
        findsOneWidget,
      );
      await input(tester, controller, () {}, enabled: false);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('paste-subscription')),
            )
            .onPressed,
        isNull,
      );
      expect(reads, 1);
    },
  );

  testWidgets('delayed clipboard never overwrites newer typing', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final result = Completer<Object?>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') return result.future;
          return null;
        });
    await input(tester, controller, () {});
    await tester.tap(find.byTooltip('Paste from clipboard'));
    await tester.pump();
    controller.text = 'newer typing';
    result.complete({'text': 'https://example.com/sub'});
    await tester.pumpAndSettle();
    expect(controller.text, 'newer typing');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Diagnostics section contains three icon buttons and copies only on tap',
    (tester) async {
      final connection = ConnectionController(
        engine: _Engine(),
        xrayEngine: _Engine(),
      );
      final statistics = StatisticsController(connection);
      addTearDown(() async {
        statistics.dispose();
        await connection.shutdown();
        connection.dispose();
      });
      String? copied;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String;
            }
            return null;
          });
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SettingsPage(connection: connection, statistics: statistics),
          ),
        ),
      );
      await tester.scrollUntilVisible(find.text('Diagnostics'), 300);
      await tester.tap(find.text('Diagnostics'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Copy diagnostics'));
      expect(find.byType(ConnectionControls), findsOneWidget);
      expect(find.byIcon(Icons.fact_check_outlined), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ConnectionControls),
          matching: find.byIcon(Icons.network_check_rounded),
        ),
        findsOneWidget,
      );
      expect(copied, isNull);
      await tester.tap(find.text('Copy diagnostics'));
      await tester.pumpAndSettle();
      expect(copied, contains('AORA Connect diagnostics'));
      expect(copied, contains('State: stopped'));
      expect(copied, contains('raw configuration/logs are excluded'));
      expect(find.text('Diagnostics copied.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
