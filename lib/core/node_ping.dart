// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../profiles/server_profile.dart';
import '../storage/app_paths.dart';
import 'core_kind.dart';
import 'development_paths.dart';
import 'ping_type.dart';
import 'server_ping.dart';
import 'tunnel_engine.dart';
import 'windows_core_engine.dart';
import 'android_tunnel_engine.dart';

class PingCancellation {
  bool cancelled = false;
  final _callbacks = <void Function()>[];
  void cancel() {
    if (cancelled) return;
    cancelled = true;
    for (final callback in List.of(_callbacks)) {
      callback();
    }
    _callbacks.clear();
  }

  void add(void Function() callback) {
    if (cancelled) {
      callback();
    } else {
      _callbacks.add(callback);
    }
  }

  void remove(void Function() callback) => _callbacks.remove(callback);
  void check() {
    if (cancelled) throw const ServerPingException('Cancelled');
  }
}

typedef NodePingProbe = Future<Duration> Function(
  ServerProfile profile,
  PingType type,
  PingCancellation cancellation,
);
typedef PingEngineFactory = TunnelEngine Function(
  String executable,
  CoreKind kind,
);

class NodePingService {
  NodePingService({
    this.helperPath,
    Uri? targetUrl,
    PingEngineFactory? engineFactory,
  }) : targetUrl = targetUrl ?? testUrl,
       _engineFactory =
           engineFactory ??
           ((executable, kind) =>
               WindowsCoreEngine(executablePath: executable, coreKind: kind));
  static final testUrl = Uri.parse('https://www.gstatic.com/generate_204');
  final String? helperPath;
  final Uri targetUrl;
  final PingEngineFactory _engineFactory;

  static Future<String> _resolve(String server) async {
    if (InternetAddress.tryParse(server) != null) return server;
    if (Platform.isAndroid) {
      final address = await AndroidTunnelEngine.channel.invokeMethod<String>(
        'resolve',
        {'host': server},
      );
      if (address == null || InternetAddress.tryParse(address) == null) {
        throw const ServerPingException('DNS lookup failed.');
      }
      return address;
    }
    final addresses = await InternetAddress.lookup(server)
        .timeout(const Duration(seconds: 5));
    if (addresses.isEmpty) {
      throw const ServerPingException('DNS lookup failed.');
    }
    return addresses
        .firstWhere(
          (value) => value.type == InternetAddressType.IPv4,
          orElse: () => addresses.first,
        )
        .address;
  }

  Future<Duration> check(
    ServerProfile profile,
    PingType type,
    PingCancellation cancellation,
  ) async {
    cancellation.check();
    if (type.viaProxy) {
      final batch = await openBatch([profile], cancellation);
      try {
        return await batch.check(profile, type, cancellation);
      } finally {
        await batch.dispose();
      }
    }
    if (type == PingType.tcp &&
        {'hysteria', 'hysteria2', 'tuic'}.contains(profile.protocol)) {
      throw const ServerPingException(
        'TCP check unavailable for a UDP-only server.',
      );
    }
    final address = await _resolve(profile.server);
    cancellation.check();
    if (Platform.isAndroid) {
      final duration = await androidPing(
        address,
        port: type == PingType.tcp ? profile.port : null,
      );
      cancellation.check();
      return duration;
    }
    final output = await runPingHelper(
      address,
      helperPath: helperPath,
      options: type == PingType.tcp ? ['tcp', '${profile.port}'] : const [],
    );
    final milliseconds = int.tryParse(output);
    if (milliseconds == null || milliseconds < 0) {
      throw const ServerPingException('Invalid ping response.');
    }
    return Duration(milliseconds: milliseconds);
  }

  Future<NodePingBatch> openBatch(
    List<ServerProfile> profiles,
    PingCancellation cancellation,
  ) async {
    if (Platform.isAndroid) return _openAndroidBatch(profiles, cancellation);
    final batch = NodePingBatch._(targetUrl);
    final reservations = <ServerSocket>[];
    final prepared = <ServerProfile, _PreparedNode>{};
    final addresses = <String, Future<String>>{};
    final sources = <String, Future<String>>{};
    try {
      cancellation.check();
      if (!Platform.isWindows) {
        throw const ServerPingException(
          'Server checks are currently available on Windows.',
        );
      }
      var next = 0;
      Future<void> prepare() async {
        while (!cancellation.cancelled && next < profiles.length) {
          final index = next++;
          final profile = profiles[index];
          try {
            final address = await addresses.putIfAbsent(
              profile.server,
              () => _resolve(profile.server),
            );
            final source = await sources.putIfAbsent(
              address,
              () => runPingHelper(
                address,
                options: ['source'],
                helperPath: helperPath,
              ),
            );
            if (InternetAddress.tryParse(source) == null) {
              throw const ServerPingException(
                'Invalid physical network address.',
              );
            }
            cancellation.check();
            final reserved = await ServerSocket.bind(
              InternetAddress.loopbackIPv4,
              0,
            );
            reservations.add(reserved);
            final outbound = profile.outbound(serverAddress: address);
            outbound['tag'] = 'node-$index';
            if (profile.coreKind == CoreKind.xray) {
              outbound['sendThrough'] = source;
            } else {
              outbound[InternetAddress(source).type == InternetAddressType.IPv4
                      ? 'inet4_bind_address'
                      : 'inet6_bind_address'] =
                  source;
            }
            prepared[profile] = _PreparedNode(
              profile,
              index,
              reserved,
              outbound,
            );
          } catch (error) {
            batch._errors[profile] = error;
          }
        }
      }

      await Future.wait(
        List.generate(
          profiles.length < 24 ? profiles.length : 24,
          (_) => prepare(),
        ),
      );
      cancellation.check();
      await Future.wait(
        CoreKind.values.map((kind) async {
          final nodes = [
            for (final profile in profiles)
              if (profile.coreKind == kind && prepared.containsKey(profile))
                prepared[profile]!,
          ];
          if (nodes.isEmpty) return;
          final root = findCoreRoot();
          final executable = kind == CoreKind.xray
              ? '${root.path}/cores/windows/xray-v${kind.configuredVersion}-windows-64/xray.exe'
              : '${root.path}/cores/windows/sing-box-${kind.configuredVersion}-windows-amd64/sing-box.exe';
          _PingSession? session;
          try {
            if (!await File(executable).exists()) {
              throw ServerPingException(
                '${kind.displayName} is not installed.',
              );
            }
            cancellation.check();
            final directory = await AppPaths.createSession('ping-');
            session = _PingSession(_engineFactory(executable, kind), directory);
            Map<String, Object?> configuration(List<_PreparedNode> members) => {
              'log': kind == CoreKind.xray
                  ? {'loglevel': 'warning'}
                  : {'level': 'info'},
              if (kind == CoreKind.singBox)
                'dns': {
                  'servers': [
                    {'type': 'local', 'tag': 'local-dns'},
                  ],
                  'final': 'local-dns',
                },
              'inbounds': [
                for (final node in members)
                  kind == CoreKind.xray
                      ? {
                          'tag': node.inboundTag,
                          'listen': '127.0.0.1',
                          'port': node.port,
                          'protocol': 'http',
                        }
                      : {
                          'tag': node.inboundTag,
                          'listen': '127.0.0.1',
                          'listen_port': node.port,
                          'type': 'mixed',
                        },
              ],
              'outbounds': [for (final node in members) node.outbound],
              if (kind == CoreKind.singBox)
                'route': {
                  'final': members.first.outbound['tag'],
                  'auto_detect_interface': true,
                  'default_domain_resolver': 'local-dns',
                  'rules': [
                    for (final node in members)
                      {
                        'inbound': [node.inboundTag],
                        'action': 'route',
                        'outbound': node.outbound['tag'],
                      },
                  ],
                },
              if (kind == CoreKind.xray)
                'routing': {
                  'domainStrategy': 'IPIfNonMatch',
                  'rules': [
                    for (final node in members)
                      {
                        'type': 'field',
                        'inboundTag': [node.inboundTag],
                        'outboundTag': node.outbound['tag'],
                      },
                  ],
                },
            };
            final file = File('${directory.path}/config.json');
            await file.writeAsString(jsonEncode(configuration(nodes)));
            for (final node in nodes) {
              await node.reservation.close();
            }
            cancellation.check();
            final engine = session.engine;
            try {
              await engine.start(file.path);
            } on StateError catch (error) {
              if (!error.message.toString().contains(
                'Configuration rejected',
              )) {
                rethrow;
              }
              Future<List<_PreparedNode>> accepted(
                List<_PreparedNode> candidates,
              ) async {
                cancellation.check();
                await file.writeAsString(jsonEncode(configuration(candidates)));
                try {
                  await engine.validate(file.path);
                  return candidates;
                } on StateError catch (error) {
                  if (!error.message.toString().contains(
                    'Configuration rejected',
                  )) {
                    rethrow;
                  }
                  if (candidates.length == 1) {
                    batch._errors[candidates.single.profile] =
                        const ServerPingException(
                          'Core rejected this profile.',
                        );
                    return [];
                  }
                  final middle = candidates.length ~/ 2;
                  final left = await accepted(candidates.sublist(0, middle));
                  final right = await accepted(candidates.sublist(middle));
                  return [...left, ...right];
                }
              }

              final valid = List<_PreparedNode>.of(await accepted(nodes));
              nodes
                ..clear()
                ..addAll(valid);
              if (nodes.isEmpty) {
                await session.dispose();
                return;
              }
              await file.writeAsString(jsonEncode(configuration(nodes)));
              cancellation.check();
              await engine.start(file.path);
            }
            cancellation.check();
            batch._sessions.add(session);
            for (final node in nodes) {
              batch._ports[node.profile] = node.port;
            }
          } catch (error) {
            for (final node in nodes) {
              batch._errors[node.profile] = error is ServerPingException
                  ? error
                  : ServerPingException(
                      '${kind.label} could not start the server checks.',
                    );
            }
            await session?.dispose();
          }
        }),
      );
      cancellation.check();
      return batch;
    } catch (_) {
      await batch.dispose();
      rethrow;
    } finally {
      for (final reserved in reservations) {
        await reserved.close();
      }
    }
  }

  Future<NodePingBatch> _openAndroidBatch(
    List<ServerProfile> profiles,
    PingCancellation cancellation,
  ) async {
    final batch = NodePingBatch._(targetUrl);
    final nodes = <Map<String, Object?>>[];
    final addresses = <String, Future<String>>{};
    var next = 0;
    Future<void> prepare() async {
      while (!cancellation.cancelled && next < profiles.length) {
        final index = next++;
        final profile = profiles[index];
        try {
          final address = await addresses.putIfAbsent(
            profile.server,
            () => _resolve(profile.server),
          );
          cancellation.check();
          nodes.add({
            'index': index,
            'core': profile.coreKind.name,
            'outbound': profile.outbound(serverAddress: address),
          });
        } catch (error) {
          batch._errors[profile] = error;
        }
      }
    }

    try {
      await Future.wait(
        List.generate(profiles.length.clamp(0, 24), (_) => prepare()),
      );
      cancellation.check();
      if (nodes.isEmpty) return batch;
      final response = await AndroidTunnelEngine.channel
          .invokeMapMethod<String, dynamic>('openPingBatch', {'nodes': nodes});
      batch._androidId = response!['id'] as int;
      final prepared = response['nodes'] as Map;
      for (var index = 0; index < profiles.length; index++) {
        final item = prepared['$index'] as Map?;
        if (item == null) continue;
        if (item['error'] case final String error) {
          batch._errors[profiles[index]] = ServerPingException(error);
        }
        if (item['port'] case final int port) {
          batch._ports[profiles[index]] = port;
        }
        if (item['xrayIndex'] case final int position) {
          batch._xrayIndices[profiles[index]] = position;
        }
      }
      cancellation.check();
      batch._cancellation = cancellation;
      batch._abort = () => unawaited(batch.dispose().catchError((Object _) {}));
      cancellation.add(batch._abort!);
      return batch;
    } on PlatformException catch (error) {
      await batch.dispose();
      throw ServerPingException(
        error.message ?? 'Could not prepare server checks.',
      );
    } catch (_) {
      await batch.dispose();
      rethrow;
    }
  }
}

class _PreparedNode {
  _PreparedNode(this.profile, this.index, this.reservation, this.outbound)
    : port = reservation.port;
  final ServerProfile profile;
  final int index;
  final int port;
  final ServerSocket reservation;
  final Map<String, Object?> outbound;
  String get inboundTag => 'check-$index';
}

class _PingSession {
  _PingSession(this.engine, this.directory);
  final TunnelEngine engine;
  final Directory directory;
  Future<void>? _disposal;
  Future<void> dispose() => _disposal ??= _dispose();
  Future<void> _dispose() async {
    try {
      await engine.dispose();
    } finally {
      await directory.delete(recursive: true);
    }
  }
}

class NodePingBatch {
  NodePingBatch._(this.targetUrl);
  final Uri targetUrl;
  final _ports = <ServerProfile, int>{};
  final _errors = <ServerProfile, Object>{};
  final _sessions = <_PingSession>[];
  int? _androidId;
  final _xrayIndices = <ServerProfile, int>{};
  PingCancellation? _cancellation;
  void Function()? _abort;
  Future<void>? _disposal;

  Future<Duration> check(
    ServerProfile profile,
    PingType type,
    PingCancellation cancellation,
  ) async {
    cancellation.check();
    final error = _errors[profile];
    if (error != null) throw error;
    final xrayIndex = _xrayIndices[profile];
    if (xrayIndex != null && _disposal == null) {
      try {
        final microseconds = await AndroidTunnelEngine.channel
            .invokeMethod<int>('checkPingBatch', {
              'id': _androidId,
              'index': xrayIndex,
              'method': type == PingType.proxyHead ? 'HEAD' : 'GET',
              'url': targetUrl.toString(),
            });
        cancellation.check();
        if (microseconds == null || microseconds < 0) {
          throw const ServerPingException('Invalid ping response.');
        }
        return Duration(microseconds: microseconds);
      } on PlatformException catch (error) {
        throw ServerPingException(error.message ?? 'Proxy request failed.');
      }
    }
    final port = _ports[profile];
    if (port == null || _disposal != null) {
      throw const ServerPingException('Proxy check session is unavailable.');
    }
    final client = HttpClient()
      ..findProxy = ((_) => 'PROXY 127.0.0.1:$port')
      ..connectionTimeout = const Duration(seconds: 8);
    void abort() => client.close(force: true);
    cancellation.add(abort);
    try {
      final watch = Stopwatch()..start();
      final request = await client
          .openUrl(type == PingType.proxyHead ? 'HEAD' : 'GET', targetUrl)
          .timeout(const Duration(seconds: 8));
      request.followRedirects = false;
      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      watch.stop();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ServerPingException(
          'Test resource returned HTTP ${response.statusCode}.',
        );
      }
      cancellation.check();
      return watch.elapsed;
    } on TimeoutException {
      throw const ServerPingException('Timeout');
    } on IOException {
      throw const ServerPingException('Proxy request failed.');
    } finally {
      cancellation.remove(abort);
      client.close(force: true);
    }
  }

  Future<void> dispose() => _disposal ??= _dispose();
  Future<void> _dispose() async {
    if (_abort != null) _cancellation?.remove(_abort!);
    try {
      await Future.wait(_sessions.map((session) => session.dispose()));
    } finally {
      if (_androidId != null) {
        await AndroidTunnelEngine.channel.invokeMethod<void>('closePingBatch', {
          'id': _androidId,
        });
      }
    }
  }
}
