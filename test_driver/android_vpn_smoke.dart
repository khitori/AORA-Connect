// SPDX-License-Identifier: GPL-3.0-or-later
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:aoravpn/core/android_tunnel_engine.dart';
import 'package:aoravpn/core/connection_probe.dart';
import 'package:aoravpn/core/tunnel_engine.dart';
import 'package:aoravpn/storage/app_paths.dart';
import 'package:aoravpn/core/core_kind.dart';
import 'package:aoravpn/core/node_ping.dart';
import 'package:aoravpn/core/ping_type.dart';
import 'package:aoravpn/core/server_ping.dart';
import 'package:aoravpn/profiles/subscription_loader.dart';
import 'package:aoravpn/profiles/server_profile.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final message = ValueNotifier('VPN service test');
  runApp(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: ValueListenableBuilder(
            valueListenable: message,
            builder: (_, value, _) => Text(value),
          ),
        ),
      ),
    ),
  );
  final engines = [
    AndroidTunnelEngine(),
    AndroidTunnelEngine(core: CoreKind.xray),
  ];
  final directory = await AppPaths.createSession('vpn-smoke-');
  final file = File('${directory.path}/config.json');
  var ownsSession = false;
  AndroidTunnelEngine? active;
  try {
    await Future.wait(engines.map((engine) => engine.ready));
    if (engines.any((engine) => engine.state != TunnelState.stopped)) {
      throw StateError('Disconnect the current AORA session before testing.');
    }
    final profiles = parseSubscription(_links);
    if (profiles.length != 2) {
      throw StateError('Provide both test gateway profiles.');
    }
    await _checks(profiles, 'disconnected');
    for (final engine in engines) {
      active = engine;
      final encoded = engine.core == CoreKind.xray
          ? const String.fromEnvironment('AORA_SMOKE_XRAY_CONFIG')
          : const String.fromEnvironment('AORA_SMOKE_CONFIG');
      await file.writeAsBytes(base64Decode(encoded));
      await engine.validate(file.path);
      for (var cycle = 0; cycle < 2; cycle++) {
        message.value = 'Approve the Android VPN request';
        ownsSession = true;
        await engine.start(file.path);
        if (engine.state != TunnelState.running) {
          throw StateError('Service did not report running.');
        }
        print('AORA_VPN_CONNECTED_${engine.core.name}_$cycle');
        message.value = 'Testing the encrypted tunnel';
        await Future<void>.delayed(const Duration(seconds: 5));
        await _probe('198.18.0.2');
        print('AORA_VPN_IPV4_OK_$cycle');
        await _probe('2001:db8::2');
        print('AORA_VPN_IPV6_OK_$cycle');
        await probeConnection(port: null);
        print('AORA_VPN_HTTPS_DNS_OK_$cycle');
        await _checks(profiles, engine.core.name);
        if (engine.state != TunnelState.running) {
          throw StateError('Ping checks stopped the VPN.');
        }
        await _probe('198.18.0.2');
        final reopened = AndroidTunnelEngine(core: engine.core);
        await reopened.ready;
        if (reopened.state != TunnelState.running) {
          throw StateError('Reopened client lost native state.');
        }
        await reopened.dispose();
        await engine.stop();
        ownsSession = false;
        if (engine.state != TunnelState.stopped) {
          throw StateError('Service did not stop.');
        }
        await probeConnection(port: null);
        print('AORA_VPN_DISCONNECT_INTERNET_OK_$cycle');
      }
    }
    message.value = 'VPN service test passed';
    print('AORA_ANDROID_VPN_SMOKE_OK');
  } catch (error) {
    message.value = 'VPN service test failed';
    print('AORA_ANDROID_VPN_SMOKE_FAILED: $error');
  } finally {
    if (ownsSession) await active?.stop();
    for (final engine in engines) {
      await engine.dispose();
    }
    await directory.delete(recursive: true);
  }
}

Future<void> _checks(List<ServerProfile> profiles, String phase) async {
  final icmp = await androidPing('127.0.0.1');
  if (icmp.inMicroseconds <= 0) {
    throw StateError('ICMP returned an invalid zero duration.');
  }
  final icmp6 = await androidPing('::1');
  if (icmp6.inMicroseconds <= 0) throw StateError('IPv6 ICMP returned zero.');
  print('AORA_PING_ICMP_OK_$phase');
  final cancellation = PingCancellation();
  final service = NodePingService(
    targetUrl: Uri.parse('http://198.18.0.2:18080/'),
  );
  await service.check(profiles.last, PingType.tcp, cancellation);
  print('AORA_PING_TCP_OK_$phase');
  final failed = parseSubscription(
    _links.replaceAll(':17991', ':17993').replaceAll(':17992', ':17993'),
  );
  failed.add(
    parseSubscription(
      _links
          .split('\n')
          .last
          .replaceFirst(RegExp(r'pcs=[^&#]+'), 'pcs=${'00' * 32}'),
    ).single,
  );
  final healthy = [
    for (var index = 0; index < 16; index++) ...parseSubscription(_links),
  ];
  final malformed = <ServerProfile>[
    const MappedServerProfile(
      name: 'Malformed sing-box test',
      server: '127.0.0.1',
      port: 17991,
      protocol: 'not-supported',
      fields: {},
    ),
    const _MalformedXray(),
  ];
  for (final type in [PingType.proxyGet, PingType.proxyHead]) {
    final batch = await service.openBatch([
      ...healthy,
      ...failed,
      ...malformed,
    ], cancellation);
    try {
      await Future.wait([
        for (final profile in healthy)
          (() async {
            try {
              await batch.check(profile, type, cancellation);
            } catch (error) {
              throw StateError('${profile.coreKind.name} ${type.name}: $error');
            }
          })(),
      ]);
      await Future.wait(
        [...failed, ...malformed].map((profile) async {
          try {
            await batch.check(profile, PingType.proxyGet, cancellation);
          } catch (_) {
            return;
          }
          throw StateError('Unreachable proxy unexpectedly succeeded.');
        }),
      );
      print('AORA_PING_${type.name}_32_OK_$phase');
    } finally {
      await batch.dispose();
    }
  }
  final cancelled = PingCancellation();
  final cancelledBatch = await service.openBatch(profiles, cancelled);
  cancelled.cancel();
  await cancelledBatch.dispose();
  print('AORA_PING_BATCH_CANCEL_OK_$phase');
}

class _MalformedXray extends ServerProfile {
  const _MalformedXray()
    : super(name: 'Malformed Xray test', server: '127.0.0.1', port: 17992);
  @override
  String get protocol => 'vless';
  @override
  CoreKind get coreKind => CoreKind.xray;
  @override
  Map<String, Object?> outbound({String? serverAddress}) => {
    'protocol': 'not-supported',
    'tag': 'proxy',
  };
}

String get _links =>
    utf8.decode(base64Decode(const String.fromEnvironment('AORA_SMOKE_LINKS')));

Future<void> _probe(String address) async {
  final socket = await Socket.connect(
    address,
    18080,
    timeout: const Duration(seconds: 15),
  );
  try {
    socket.write(
      'GET / HTTP/1.0\r\nHost: aora-smoke\r\nConnection: close\r\n\r\n',
    );
    await socket.flush();
    final response = await utf8.decoder
        .bind(socket)
        .join()
        .timeout(const Duration(seconds: 15));
    if (!response.contains(const String.fromEnvironment('AORA_SMOKE_NONCE'))) {
      throw StateError(
        'Tunnel response did not come from the controlled gateway.',
      );
    }
  } finally {
    socket.destroy();
  }
}
