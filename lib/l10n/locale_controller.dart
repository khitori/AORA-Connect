// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';

import '../storage/app_paths.dart';
import 'app_localizations.dart';

abstract interface class LanguageStore {
  Future<String?> read();
  Future<void> write(String? language);
}

class FileLanguageStore implements LanguageStore {
  FileLanguageStore({this.directory});
  final Directory? directory;

  Future<File> _file() async => File(
    '${directory?.path ?? '${(await AppPaths.root()).path}/settings'}/language.json',
  );

  @override
  Future<String?> read() async {
    try {
      final json = jsonDecode(await (await _file()).readAsString());
      return json is Map && json['language'] is String
          ? json['language'] as String
          : null;
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> write(String? language) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({'language': language}),
      flush: true,
    );
    await temporary.rename(file.path);
  }
}

class LocaleController extends ChangeNotifier with WidgetsBindingObserver {
  LocaleController({this.store, String? language})
    : _language = supportedLanguage(language);
  final LanguageStore? store;
  String? _language;
  String? get language => _language;
  Locale? get locale => _language == null
      ? null
      : AppLocalizations.supportedLocales.firstWhere(
          (locale) => locale.toLanguageTag() == _language,
        );
  bool _disposed = false;
  bool restoreFailed = false;
  bool _observing = false;
  bool _changed = false;
  Future<void> _writes = Future.value();
  Future<void>? _initialization;

  Future<void> initialize() => _initialization ??= _restore();

  Future<void> _restore() async {
    if (_disposed) return;
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    if (store == null) return;
    String? saved;
    try {
      saved = await store?.read();
      restoreFailed = false;
    } catch (_) {
      if (!_disposed && !_changed) {
        restoreFailed = true;
        notifyListeners();
      }
      return;
    }
    if (_disposed || _changed) return;
    _language = supportedLanguage(saved);
    notifyListeners();
  }

  Future<void> reload() async {
    if (_disposed) return;
    _changed = false;
    await _restore();
  }

  static String? supportedLanguage(String? language) =>
      AppLocalizations.supportedLocales.any(
        (locale) => locale.toLanguageTag() == language,
      )
      ? language
      : null;

  static String nativeName(String language) => switch (language) {
    'en' => 'English',
    'ru' => 'Русский',
    'ar' => 'العربية',
    'fa' => 'فارسی',
    'he' => 'עברית',
    'zh' => '中文（简体）',
    'de' => 'Deutsch',
    'fr' => 'Français',
    'es' => 'Español',
    _ => language,
  };

  Future<void> select(String? language) {
    if (language != null && supportedLanguage(language) == null) {
      return Future.error(ArgumentError.value(language, 'language'));
    }
    _changed = true;
    final operation = _writes.catchError((Object _) {}).then((_) async {
      await store?.write(language);
      if (_disposed) return;
      _language = language;
      restoreFailed = false;
      notifyListeners();
    });
    _writes = operation;
    return operation;
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (_language == null && !_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class LocaleScope extends InheritedNotifier<LocaleController> {
  const LocaleScope({
    super.key,
    required LocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static LocaleController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LocaleScope>()?.notifier;
}
