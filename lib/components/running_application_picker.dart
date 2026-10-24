// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_theme.dart';

Future<List<String>> loadRunningApplications() async {
  final ProcessResult result;
  final List<String> names;
  if (Platform.isWindows) {
    result = await Process.run('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      r'@(Get-Process | Select-Object -ExpandProperty ProcessName -Unique) | ConvertTo-Json -Compress',
    ]).timeout(const Duration(seconds: 10));
    if (result.exitCode != 0) {
      throw StateError('Unable to read running applications.');
    }
    final decoded = jsonDecode(result.stdout as String);
    names = (decoded is List ? decoded : [decoded])
        .cast<String>()
        .where((name) => name != 'Idle' && name != 'System')
        .map((name) => '$name.exe')
        .toList();
  } else if (Platform.isLinux || Platform.isMacOS) {
    result = await Process.run('ps', [
      '-A',
      '-o',
      'comm=',
    ]).timeout(const Duration(seconds: 10));
    if (result.exitCode != 0) {
      throw StateError('Unable to read running applications.');
    }
    names = const LineSplitter()
        .convert(result.stdout as String)
        .map((name) => name.trim().split('/').last)
        .toList();
  } else {
    throw UnsupportedError(
      'Running application selection is available on desktop.',
    );
  }
  return names.where((name) => name.isNotEmpty).toSet().toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}

Future<String?> showRunningApplicationPicker(BuildContext context) =>
    showDialog<String>(
      context: context,
      builder: (_) => const _RunningApplicationPicker(),
    );

class _RunningApplicationPicker extends StatefulWidget {
  const _RunningApplicationPicker();

  @override
  State<_RunningApplicationPicker> createState() =>
      _RunningApplicationPickerState();
}

class _RunningApplicationPickerState extends State<_RunningApplicationPicker> {
  late Future<List<String>> applications = loadRunningApplications();
  String query = '';

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.runningApplications),
    content: SizedBox(
      width: 320,
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
            onChanged: (value) => setState(() => query = value.toLowerCase()),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<String>>(
              future: applications,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text(context.l10n.runningLoadFailed));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final visible = snapshot.data!
                    .where((name) => name.toLowerCase().contains(query))
                    .toList();
                if (visible.isEmpty) {
                  return Center(
                    child: Text(context.l10n.noMatchingApplications),
                  );
                }
                return ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, index) => Material(
                    type: MaterialType.transparency,
                    borderRadius: BorderRadius.circular(AppTheme.controlRadius),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.controlRadius,
                        ),
                      ),
                      leading: const Icon(Icons.apps_rounded),
                      title: Text(visible[index]),
                      onTap: () => Navigator.pop(context, visible[index]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () =>
            setState(() => applications = loadRunningApplications()),
        child: Text(context.l10n.refresh),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
    ],
  );
}
