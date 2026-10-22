// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';

class UpdateCache {
  UpdateCache(
    this.runtime, {
    required this.packageName,
    required this.inspect,
    required this.newer,
  });

  final Directory runtime;
  final String packageName;
  final Future<Map<String, dynamic>> Function(String path) inspect;
  final bool Function(String candidate, String current) newer;
  static final _held = <String>{};
  static const _names = {
    'AORAConnect.apk',
    'AORAConnect-Setup.exe',
    'aora-update.json',
    'aoravpn_update.exe',
    '.update.lock',
    '.installer.lock',
    'installing.json',
  };

  static Future<RandomAccessFile?> acquire(Directory directory) async {
    final key = await directory.resolveSymbolicLinks();
    if (!_held.add(key)) return null;
    RandomAccessFile? lock;
    try {
      final file = File('${directory.path}/.update.lock');
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type != FileSystemEntityType.notFound &&
          type != FileSystemEntityType.file) {
        throw const FileSystemException('Unsafe update lock');
      }
      lock = await file.open(mode: FileMode.append);
      await lock.lock(FileLock.exclusive);
      return lock;
    } catch (_) {
      await lock?.close();
      _held.remove(key);
      return null;
    }
  }

  static Future<void> release(
    Directory directory,
    RandomAccessFile lock,
  ) async {
    try {
      await lock.close();
    } finally {
      _held.remove(await directory.resolveSymbolicLinks());
    }
  }

  Future<bool> _safe(Directory directory) async {
    if (await FileSystemEntity.type(runtime.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      return false;
    }
    if (!RegExp(r'^update-[a-zA-Z0-9_-]+$')
        .hasMatch(directory.uri.pathSegments.where((s) => s.isNotEmpty).last)) {
      return false;
    }
    if (await FileSystemEntity.type(directory.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      return false;
    }
    if (await directory.parent.resolveSymbolicLinks() !=
        await runtime.resolveSymbolicLinks()) {
      return false;
    }
    final name = directory.uri.pathSegments.where((s) => s.isNotEmpty).last;
    final canonicalRoot = Directory(await runtime.resolveSymbolicLinks());
    if (Directory(await directory.resolveSymbolicLinks()).uri !=
        canonicalRoot.uri.resolve('$name/')) {
      return false;
    }
    await for (final child in directory.list(followLinks: false)) {
      final name = child.uri.pathSegments.last;
      if (!_names.contains(name) ||
          await FileSystemEntity.type(child.path, followLinks: false) !=
              FileSystemEntityType.file) {
        return false;
      }
    }
    return true;
  }

  Future<void> discardLocked(Directory directory) async {
    if (!await _safe(directory)) return;
    await for (final child in directory.list(followLinks: false)) {
      if (child.uri.pathSegments.last != '.update.lock') {
        await child.delete();
      }
    }
  }

  static Future<void> removeEmptySession(Directory directory) async {
    try {
      if ((await directory.list(followLinks: false).toList()).every(
        (e) => e.uri.pathSegments.last == '.update.lock',
      )) {
        await File('${directory.path}/.update.lock').delete();
        await directory.delete();
      }
    } on FileSystemException {
    }
  }

  Future<({File file, Map<String, dynamic> release})?> sweep(
    String current, {
    String? preferredPackage,
  }) async {
    if (!await runtime.exists()) return null;
    final preferred = preferredPackage == null
        ? null
        : File(preferredPackage).absolute.uri;
    final entries =
        <
          ({
            Directory dir,
            RandomAccessFile lock,
            Map<String, dynamic>? release,
            bool installing,
          })
        >[];
    ({File file, Map<String, dynamic> release})? pending;
    try {
      await for (final child in runtime.list(followLinks: false)) {
        if (child is! Directory) continue;
        RandomAccessFile? lock;
        try {
          if (!await _safe(child)) continue;
          lock = await acquire(child);
          if (lock == null) continue;
          final installer = File('${child.path}/.installer.lock');
          if (await installer.exists()) {
            final handle = await installer.open(mode: FileMode.append);
            await handle.close();
          }
          Map<String, dynamic>? release;
          try {
            final value = await inspect('${child.path}/$packageName');
            if (newer(value['version'] as String, current)) release = value;
          } catch (_) {
          }
          var installing = false;
          if (release != null) {
            try {
              final marker = File('${child.path}/installing.json');
              if (await marker.length() <= 1024) {
                installing =
                    (jsonDecode(await marker.readAsString())
                        as Map)['version'] ==
                    release['version'];
              }
            } catch (_) {
            }
            final path = File('${child.path}/$packageName').absolute.uri;
            if (pending == null ||
                path == preferred ||
                (pending.file.absolute.uri != preferred &&
                    newer(
                      release['version'] as String,
                      pending.release['version'] as String,
                    ))) {
              pending = (
                file: File('${child.path}/$packageName'),
                release: release,
              );
            }
          }
          entries.add((
            dir: child,
            lock: lock,
            release: release,
            installing: installing,
          ));
          lock = null;
        } on FileSystemException {
        } finally {
          if (lock != null) await release(child, lock);
        }
      }
      for (final entry in entries) {
        if (entry.installing || entry.dir.uri == pending?.file.parent.uri) {
          continue;
        }
        try {
          await discardLocked(entry.dir);
        } on FileSystemException {
        }
      }
    } finally {
      for (final entry in entries) {
        await release(entry.dir, entry.lock);
        if (entry.installing || entry.dir.uri == pending?.file.parent.uri) {
          continue;
        }
        await removeEmptySession(entry.dir);
      }
    }
    return pending;
  }
}
