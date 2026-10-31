// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/widgets.dart';

import 'app.dart';
import 'l10n/locale_controller.dart';
import 'storage/platform_settings_stores.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final locale = LocaleController(store: createLanguageStore());
  await locale.initialize();
  runApp(MyApp(localeController: locale));
}
