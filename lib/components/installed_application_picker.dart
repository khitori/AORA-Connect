// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';

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
    showDialog<String>(
      context: context,
      builder: (_) => const InstalledApplicationPicker(),
    );

class InstalledApplicationPicker extends StatefulWidget {
  const InstalledApplicationPicker({super.key});

  @override
  State<InstalledApplicationPicker> createState() =>
      _InstalledApplicationPickerState();
}

class _InstalledApplicationPickerState
    extends State<InstalledApplicationPicker> {
  late Future<List<InstalledApplication>> applications =
      InstalledApplication.load();
  String query = '';

  void reload() => setState(() {
    applications = InstalledApplication.load();
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: const EdgeInsets.all(24),
    actionsAlignment: MainAxisAlignment.spaceBetween,
    actionsOverflowButtonSpacing: 8,
    title: Text(context.l10n.installedApplications),
    content: SizedBox(
      width: 400,
      height: 360,
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: context.l10n.searchApplications,
              prefixIcon: Icon(Icons.search_rounded, size: 20),
              prefixIconConstraints: BoxConstraints(
                minWidth: 40,
                minHeight: 36,
              ),
            ),
            onChanged: (value) =>
                setState(() => query = value.trim().toLowerCase()),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<InstalledApplication>>(
              future: applications,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text(context.l10n.installedLoadFailed));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final visible = snapshot.data!
                    .where(
                      (app) =>
                          app.label.toLowerCase().contains(query) ||
                          app.packageName.toLowerCase().contains(query),
                    )
                    .toList();
                if (visible.isEmpty) {
                  return Center(
                    child: Text(context.l10n.noMatchingApplications),
                  );
                }
                return ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final app = visible[index];
                    return Material(
                      type: MaterialType.transparency,
                      borderRadius: BorderRadius.circular(
                        AppTheme.controlRadius,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        leading: app.icon == null
                            ? const Icon(Icons.apps_rounded, size: 32)
                            : Image.memory(
                                app.icon!,
                                width: 32,
                                height: 32,
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.apps_rounded, size: 32),
                              ),
                        title: Text(
                          app.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          app.packageName,
                          textDirection: TextDirection.ltr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.pop(context, app.packageName),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: reload, child: Text(context.l10n.refresh)),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
    ],
  );
}
