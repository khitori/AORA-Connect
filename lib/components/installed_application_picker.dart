// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import 'app_dialog.dart';
import 'application_picker_dialog.dart';

class InstalledApplication {
  const InstalledApplication({
    required this.packageName,
    required this.label,
    this.icon,
  });

  final String packageName;
  final String label;
  final Uint8List? icon;

  static const channel = MethodChannel('aora/applications');

  static Future<List<InstalledApplication>> load() async {
    final entries = await channel.invokeListMethod<Object?>('listInstalled');
    if (entries == null) throw StateError('Application list unavailable.');
    final unique = <String, InstalledApplication>{};
    for (final entry in entries) {
      final data = Map<Object?, Object?>.from(entry as Map);
      final package = data['packageName'] as String;
      unique[package] = InstalledApplication(
        packageName: package,
        label: data['label'] as String,
        icon: data['icon'] as Uint8List?,
      );
    }
    return unique.values.toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  }
}

Future<String?> showInstalledApplicationPicker(BuildContext context) =>
    showAppDialog<String>(
      context: context,
      builder: (_) => const InstalledApplicationPicker(),
    );

/// Installed Android applications: their own icon, label and package name.
/// Choosing one returns the package name.
class InstalledApplicationPicker extends StatelessWidget {
  const InstalledApplicationPicker({super.key});

  @override
  Widget build(BuildContext context) =>
      ApplicationPickerDialog<InstalledApplication>(
        title: context.l10n.installedApplications,
        load: InstalledApplication.load,
        label: (app) => app.label,
        detail: (app) => app.packageName,
        result: (app) => app.packageName,
        icon: (app) => app.icon == null
            ? null
            : Image.memory(
                app.icon!,
                errorBuilder: (_, _, _) =>
                    Icon(Icons.apps_rounded, color: AppColors.muted500),
              ),
        loadFailed: context.l10n.installedLoadFailed,
      );
}
