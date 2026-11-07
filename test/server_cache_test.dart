// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/controllers/connection_controller.dart';
import 'package:aoravpn/profiles/subscription_loader.dart';
import 'package:aoravpn/storage/app_settings_store.dart';
import 'package:aoravpn/storage/server_cache_store.dart';

import 'connection_controller_test.dart' show ControlledEngine;
import 'connection_controller_test.dart' show MemorySettingsStore;
import 'support/runtime_session.dart';

class MemoryServerCacheStore implements ServerCacheStore {
  Map<String, Object?>? saved;
  int writes = 0;

  @override
  Future<ServerCache?> read() async =>
      ServerCache.fromJson(saved?.cast<String, dynamic>());

  @override
  Future<void> write(ServerCache? cache) async {
    writes++;
    saved = cache?.toJson();
  }
}

const _url = 'https://example.com/sub';

SubscriptionLoadResult _list(List<String> names) => parseSubscriptionDetailed(
  [
    for (final name in names)
      'hysteria2://secret@127.0.0.1:443?sni=example.com#$name',
  ].join('\n'),
);

void main() {
  test('A saved list keeps its servers and details', () {
    final result = parseSubscriptionDetailed(
      '#profile-title: Provider\n'
      'hysteria2://secret@127.0.0.1:443?sni=example.com#One\n'
      'hysteria2://secret@127.0.0.1:443?sni=example.com#Two',
    );
    final cache = ServerCache(
      url: _url,
      result: SubscriptionLoadResult(
        profiles: result.profiles,
        title: 'Provider',
        description: 'Line one\nLine two',
        expiresAt: DateTime.utc(2027),
        source: result.source,
      ),
    );
    final restored = ServerCache.fromJson(cache.toJson())!;
    expect(restored.url, _url);
    expect(restored.result.profiles.map((p) => p.name), ['One', 'Two']);
    expect(restored.result.title, 'Provider');
    expect(restored.result.description, 'Line one\nLine two');
    expect(restored.result.expiresAt, DateTime.utc(2027));
    expect(ServerCache.fromJson({'version': 1}), isNull);
    expect(ServerCache.fromJson(null), isNull);
  });

  test('The file store saves, reads and forgets the list', () async {
    final directory = await Directory.systemTemp.createTemp('server-cache-');
    addTearDown(() => directory.delete(recursive: true));
    final store = FileServerCacheStore(directory: directory);
    expect(await store.read(), isNull);
    await store.write(ServerCache(url: _url, result: _list(['One'])));
    expect((await store.read())!.result.profiles.single.name, 'One');
    await store.write(null);
    expect(await store.read(), isNull);
  });

  test('Start shows the saved list at once, then the downloaded one', () async {
    final download = Completer<SubscriptionLoadResult>();
    final cache = MemoryServerCacheStore()
      ..saved = ServerCache(url: _url, result: _list(['Saved'])).toJson();
    final controller = ConnectionController(
      sessionCreator: createTestRuntimeSession,
      engine: ControlledEngine(),
      settingsStore: MemorySettingsStore()
        ..data = const AppSettingsData(
          subscriptions: [SavedSubscription(_url)],
          activeSubscriptionUrl: _url,
        ),
      serverCache: cache,
      subscriptionLoader: (_) => download.future,
    );
    addTearDown(() async {
      await controller.shutdown();
      controller.dispose();
    });
    final restoring = controller.restore();
    await Future<void>.delayed(Duration.zero);
    // Shown before the download finished, but nothing connects with it yet.
    expect(controller.profiles.single.name, 'Saved');
    expect(controller.selected!.name, 'Saved');
    expect(controller.canConnect, isFalse);

    download.complete(_list(['Fresh']));
    await restoring;
    expect(controller.error, isNull);
    expect(controller.profiles.single.name, 'Fresh');
    expect(controller.selected!.name, 'Fresh');
    expect(controller.canConnect, isTrue);
    // The new list is saved for the next start.
    await Future<void>.delayed(Duration.zero);
    expect(
      ServerCache.fromJson(cache.saved!.cast())!.result.profiles.single.name,
      'Fresh',
    );
  });

  test('Without a network the saved list stays usable', () async {
    final cache = MemoryServerCacheStore()
      ..saved = ServerCache(url: _url, result: _list(['Saved'])).toJson();
    final controller = ConnectionController(
      sessionCreator: createTestRuntimeSession,
      engine: ControlledEngine(),
      settingsStore: MemorySettingsStore()
        ..data = const AppSettingsData(
          subscriptions: [SavedSubscription(_url)],
          activeSubscriptionUrl: _url,
        ),
      serverCache: cache,
      subscriptionLoader: (_) async =>
          throw StateError('Could not retrieve the subscription.'),
    );
    addTearDown(() async {
      await controller.shutdown();
      controller.dispose();
    });
    await controller.restore();
    // The refresh failure is still reported, but the saved server was
    // prepared and can be used.
    expect(controller.error, contains('Could not retrieve'));
    expect(controller.profiles.single.name, 'Saved');
    expect(controller.selected!.name, 'Saved');
    expect(controller.canConnect, isTrue);
  });

  test('A failed early download is tried once more after startup', () async {
    var loads = 0;
    final controller = ConnectionController(
      sessionCreator: createTestRuntimeSession,
      engine: ControlledEngine(),
      settingsStore: MemorySettingsStore()
        ..data = const AppSettingsData(
          subscriptions: [SavedSubscription(_url)],
          activeSubscriptionUrl: _url,
        ),
      subscriptionLoader: (_) async {
        // Blocked the first time, as by protection left from a crash.
        if (++loads == 1) throw StateError('Blocked');
        return _list(['Fresh']);
      },
    );
    addTearDown(() async {
      await controller.shutdown();
      controller.dispose();
    });
    await controller.restore();
    expect(loads, 2);
    expect(controller.error, isNull);
    expect(controller.profiles.single.name, 'Fresh');
  });

  test('A saved list of another subscription is not shown', () async {
    final download = Completer<SubscriptionLoadResult>();
    final cache = MemoryServerCacheStore()
      ..saved = ServerCache(
        url: 'https://other.example/sub',
        result: _list(['Other']),
      ).toJson();
    final controller = ConnectionController(
      sessionCreator: createTestRuntimeSession,
      engine: ControlledEngine(),
      settingsStore: MemorySettingsStore()
        ..data = const AppSettingsData(
          subscriptions: [SavedSubscription(_url)],
          activeSubscriptionUrl: _url,
        ),
      serverCache: cache,
      subscriptionLoader: (_) => download.future,
    );
    addTearDown(() async {
      await controller.shutdown();
      controller.dispose();
    });
    final restoring = controller.restore();
    await Future<void>.delayed(Duration.zero);
    expect(controller.profiles, isEmpty);
    download.complete(_list(['Fresh']));
    await restoring;
    expect(controller.profiles.single.name, 'Fresh');
  });
}
