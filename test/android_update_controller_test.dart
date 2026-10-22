// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:aoravpn/updates/update_controller.dart';

class Response extends Stream<List<int>> implements HttpClientResponse {
  Response(this.bytes);
  final List<int> bytes;
  @override
  int get statusCode => 200;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Request implements HttpClientRequest {
  Request(this.bytes);
  final List<int> bytes;
  @override
  Future<HttpClientResponse> close() async => Response(bytes);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class Client implements HttpClient {
  Client(this.resources, this.requests);
  final Map<String, List<int>> resources;
  final List<String> requests;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requests.add('$url');
    final body = resources['$url'];
    if (body == null) throw const SocketException('Unavailable');
    return Request(body);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late Directory root;
  late File input;
  late UpdateController updates;
  var version = '1.0.5+2';
  var accepted = true;
  var hash = 'ab' * 32;
  final requests = <String>[];
  final resources = <String, List<int>>{};
  Map<String, dynamic> metadata() => {
    'version': version,
    'size': 4,
    'sha256': hash,
    'urls': ['https://example.com/AORAConnect.apk'],
    'notes': '',
  };
  setUp(() async {
    root = await Directory.systemTemp.createTemp('aora-android-updates-');
    input = await File('${root.path}/download.apk').writeAsBytes([1, 2, 3, 4]);
    requests.clear();
    resources.clear();
    version = '1.0.5+2';
    accepted = true;
    hash = 'ab' * 32;
    updates = UpdateController(
      platform: UpdatePlatform.android,
      preferencesDirectory: Directory('${root.path}/preferences'),
      sessionCreator: () => root.createTemp('update-'),
      verifier: (command, path) async {
        if (command == 'info') return {'version': '1.0.5+1'};
        if (!accepted) throw StateError('Signature rejected');
        if (command == 'verify-manifest') {
          return Map<String, dynamic>.from(
            jsonDecode(await File(path).readAsString()) as Map,
          );
        }
        return metadata();
      },
    );
    await updates.initialize(checkAutomatically: false);
  });
  tearDown(() async {
    updates.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    if (await root.exists()) await root.delete(recursive: true);
  });
  test('Manual APK import requires no Windows helper; gates and re-verification remain active', () async {
    expect(updates.defaultSource, UpdateController.androidGithubSource);
    await updates.importFile(input.path);
    expect(updates.package!.path, endsWith('AORAConnect.apk'));
    var launches = 0;
    await updates.install(
      canInstall: () => false,
      launch: (_) async {
        launches++;
      },
    );
    expect(launches, 0);
    hash = 'cd' * 32;
    await updates.install(
      canInstall: () => true,
      launch: (_) async {
        launches++;
      },
    );
    expect(updates.error, contains('changed after verification'));
    expect(launches, 0);
    hash = 'ab' * 32;
    await updates.importFile(input.path);
    await updates.install(
      canInstall: () => true,
      launch: (_) async {
        launches++;
      },
    );
    expect(launches, 1);
    expect(updates.installing, isFalse);
    accepted = false;
    await updates.importFile(input.path);
    expect(updates.package, isNull);
    expect(updates.error, contains('Signature rejected'));
  });
  test('Android requires an increasing build number even if the version name is newer', () async {
    version = '2.0.0+1';
    await updates.importFile(input.path);
    expect(updates.package, isNull);
    expect(updates.error, contains('newer'));
  });
  test(
    'GitHub is first, optional metadata mirror works, APK bytes match exactly',
    () async {
      const mirror = 'https://mirror.example/aora-update-android.json';
      await updates.setPreferences(sources: [mirror]);
      resources[mirror] = utf8.encode(jsonEncode(metadata()));
      resources['https://example.com/AORAConnect.apk'] = [1, 2, 3, 4];
      await HttpOverrides.runZoned(() async {
        await updates.check();
        expect(updates.error, isNull);
        expect(requests.take(2), [
          UpdateController.androidGithubSource,
          mirror,
        ]);
        await updates.download();
        expect(updates.error, isNull);
        expect(updates.package, isNotNull);
        expect(updates.progress, 1);
      }, createHttpClient: (_) => Client(resources, requests));
    },
  );
  test('Incomplete and oversized APK downloads cannot be installed', () async {
    resources[UpdateController.androidGithubSource] = utf8.encode(
      jsonEncode(metadata()),
    );
    await HttpOverrides.runZoned(() async {
      await updates.check();
      for (final bytes in [
        [1, 2, 3],
        [1, 2, 3, 4, 5],
      ]) {
        resources['https://example.com/AORAConnect.apk'] = bytes;
        await updates.download();
        expect(updates.package, isNull);
        expect(updates.error, isNotNull);
      }
    }, createHttpClient: (_) => Client(resources, requests));
  });
}
