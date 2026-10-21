// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show Bidi;

import 'app_localizations.dart';

bool isRtlLocale(AppLocalizations strings) =>
    Bidi.isRtlLanguage(strings.localeName);

/// Presentation only: never write directional controls into URLs or configuration.
String isolateTechnicalValue(AppLocalizations strings, String value) =>
    isRtlLocale(strings) ? '\u2066$value\u2069' : value;

TextDirection textDirectionFor(String value) =>
    Bidi.detectRtlDirectionality(value) ? TextDirection.rtl : TextDirection.ltr;
