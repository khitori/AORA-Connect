// SPDX-License-Identifier: GPL-3.0-or-later
import 'app_localizations.dart';
import 'app_localizations_en.dart';

class LocalizedFormatException extends FormatException {
  LocalizedFormatException(this.localize)
    : super(localize(AppLocalizationsEn()));
  final String Function(AppLocalizations) localize;
}

String localizedException(Object error, AppLocalizations strings) =>
    error is LocalizedFormatException
    ? error.localize(strings)
    : error is FormatException
    ? error.message
    : error.toString();
