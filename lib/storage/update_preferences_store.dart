// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';

import 'app_paths.dart';

class UpdatePreferencesData {
  const UpdatePreferencesData({
    this.automaticChecks = true,
    this.sources = const [],
  });
  final bool automaticChecks;
  final List<String> sources;
  factory UpdatePreferencesData.fromJson(Map<String, dynamic>? value) {
    if (value == null) return const UpdatePreferencesData();
    final sources = (value['sources'] as List? ?? []).cast<String>();
    for (final source in sources) {
      final uri = Uri.tryParse(source);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasFragment) {
        throw const FormatException('Saved update sources are invalid.');
      }
    }
    return UpdatePreferencesData(
      automaticChecks: value['automaticChecks'] != false,
      sources: List.unmodifiable(sources),
    );
  }
  Map<String, Object?> toJson() => {
    'automaticChecks': automaticChecks,
    'sources': sources,
  };
}

abstract interface class UpdatePreferencesStore {
  Future<UpdatePreferencesData> read();
  Future<void> write(UpdatePreferencesData value);
}

class FileUpdatePreferencesStore implements UpdatePreferencesStore {
  FileUpdatePreferencesStore({this.directory});
  final Directory? directory;
  Future<File> _file() async => File(
    '${directory?.path ?? '${(await AppPaths.root()).path}/settings'}/updates.json',
  );
  @override
  Future<UpdatePreferencesData> read() async {
    final file = await _file();
    if (!await file.exists()) return const UpdatePreferencesData();
    return UpdatePreferencesData.fromJson(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> write(UpdatePreferencesData value) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(value.toJson()), flush: true);
    await temporary.rename(file.path);
  }
}
