// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/core/desktop_window.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final commands = <String?>[];
  setUp(() {
    commands.clear();
    messenger.setMockDecodedMessageHandler<String>(DesktopWindow.channel, (
      message,
    ) async {
      commands.add(message);
      return 'ok';
    });
  });
  tearDown(
    () => messenger.setMockDecodedMessageHandler<String>(
      DesktopWindow.channel,
      null,
    ),
  );

  Future<String?> event(String value) {
    final reply = Completer<String?>();
    // ignore: deprecated_member_use
    messenger.handlePlatformMessage(
      'aora/window',
      const StringCodec().encodeMessage(value),
      (bytes) => reply.complete(const StringCodec().decodeMessage(bytes)),
    );
    return reply.future;
  }

  test(
    'Tray and drag preserve the session; disconnect state is deduplicated',
    () async {
      if (!Platform.isWindows) return;
      final window = DesktopWindow();
      addTearDown(window.dispose);
      var exits = 0;
      var disconnects = 0;
      await window.initialize(
        onExit: () async {
          exits++;
        },
        onDisconnect: () async {
          disconnects++;
        },
        onError: (_) => fail('Unexpected error'),
      );
      await window.command('tray');
      await window.command('drag');
      await window.setCanDisconnect(true);
      await window.setCanDisconnect(true);
      expect(commands, ['ready', 'tray', 'drag', 'connected']);
      expect(exits, 0);
      expect(disconnects, 0);
      expect(await event('disconnect'), 'ok');
      expect(disconnects, 1);
    },
  );

  test(
    'Repeated exit events await cleanup before destroying the window',
    () async {
      if (!Platform.isWindows) return;
      final window = DesktopWindow();
      addTearDown(window.dispose);
      final cleanup = Completer<void>();
      var exits = 0;
      await window.initialize(
        onExit: () async {
          exits++;
          await cleanup.future;
          await window.command('destroy');
        },
        onDisconnect: () async {},
        onError: (_) => fail('Unexpected error'),
      );
      final first = event('exit');
      final second = event('exit');
      await Future<void>.delayed(Duration.zero);
      expect(exits, 1);
      expect(commands.contains('destroy'), isFalse);
      cleanup.complete();
      expect(await first, 'ok');
      expect(await second, 'ok');
      expect(commands.where((command) => command == 'destroy'), hasLength(1));
    },
  );

  test(
    'Native failures surface; failed cleanup reopens rather than forces exit',
    () async {
      if (!Platform.isWindows) return;
      final window = DesktopWindow();
      addTearDown(window.dispose);
      Object? error;
      await window.initialize(
        onExit: () async {
          throw StateError('cleanup failed');
        },
        onDisconnect: () async {},
        onError: (value) => error = value,
      );
      expect(await event('exit'), 'error');
      expect(error.toString(), contains('cleanup failed'));
      expect(commands.last, 'show');
      expect(commands.contains('destroy'), isFalse);
      messenger.setMockDecodedMessageHandler<String>(
        DesktopWindow.channel,
        (_) async => 'Tray registration failed',
      );
      await expectLater(window.command('tray'), throwsStateError);
    },
  );
}
