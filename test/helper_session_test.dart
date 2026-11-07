// SPDX-License-Identifier: GPL-3.0-or-later
@TestOn('windows')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/core/windows_service_transport.dart';

/// Stands in for the helper's session mode: answers each input line with the
/// same line, in order, until its input closes.
const _echo = [
  '-NoProfile',
  '-NonInteractive',
  '-Command',
  r'[Console]::InputEncoding = [Text.Encoding]::UTF8; '
      r'[Console]::OutputEncoding = [Text.Encoding]::UTF8; '
      r'while (($line = [Console]::In.ReadLine()) -ne $null) { '
      r'[Console]::Out.WriteLine($line); [Console]::Out.Flush() }',
];

void main() {
  test('One helper answers many requests in order', () async {
    final session = await HelperSession.open(
      'powershell.exe',
      arguments: _echo,
    );
    addTearDown(session.close);
    final replies = await Future.wait([
      for (var i = 0; i < 5; i++) session.send('{"n":$i,"text":"Привет"}'),
    ]);
    expect(replies, [for (var i = 0; i < 5; i++) '{"n":$i,"text":"Привет"}']);
    expect(session.alive, isTrue);
  });

  test('A helper without session mode is recognised', () async {
    final session = await HelperSession.open(
      'powershell.exe',
      arguments: const ['-NoProfile', '-Command', 'exit 1'],
    );
    await expectLater(
      session.send('{}'),
      throwsA(isA<HelperSessionUnsupported>()),
    );
    expect(session.alive, isFalse);
  });

  test('A closed session fails new requests', () async {
    final session = await HelperSession.open(
      'powershell.exe',
      arguments: _echo,
    );
    expect(await session.send('{"a":1}'), '{"a":1}');
    session.close();
    await expectLater(session.send('{}'), throwsStateError);
  });
}
