// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_dialog.dart';
import 'pill_button.dart';
import 'pill_field.dart';

/// Height of the scrolling list of applications.
const _listHeight = 288.0;

/// The application picker in the glass dialog style: a gray search pill, a
/// list of rounded rows that tint on hover, and Refresh and Cancel pills.
/// Choosing a row closes the dialog with that application's [result].
class ApplicationPickerDialog<T> extends StatefulWidget {
  const ApplicationPickerDialog({
    super.key,
    required this.title,
    required this.load,
    required this.label,
    required this.result,
    required this.loadFailed,
    this.detail,
    this.icon,
  });

  final String title;
  final Future<List<T>> Function() load;

  /// The row's main text; search matches it, and [detail] when given.
  final String Function(T) label;

  /// What the dialog returns for the chosen application.
  final String Function(T) result;

  /// A second, smaller line, such as an Android package name.
  final String? Function(T)? detail;

  /// The application's own icon; a generic one when it has none.
  final Widget? Function(T)? icon;

  /// Shown instead of the list when [load] fails.
  final String loadFailed;

  @override
  State<ApplicationPickerDialog<T>> createState() =>
      _ApplicationPickerDialogState<T>();
}

class _ApplicationPickerDialogState<T>
    extends State<ApplicationPickerDialog<T>> {
  late Future<List<T>> _applications = widget.load();
  String _query = '';

  bool _matches(T app) =>
      widget.label(app).toLowerCase().contains(_query) ||
      (widget.detail?.call(app)?.toLowerCase().contains(_query) ?? false);

  // Loading, empty and failed lists show one centered line instead.
  Widget _message(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(fontSize: 14, color: AppColors.dialogLabel),
      ),
    ),
  );

  Widget _row(T app) {
    final detail = widget.detail?.call(app);
    final theme = Theme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.sectionRowRadius),
        ),
        overlayColor: AppTheme.overlay(
          AppColors.apppickerRowHover,
          AppColors.apppickerRowPressed,
        ),
        onTap: () => Navigator.pop(context, widget.result(app)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.sectionPadding,
              vertical: 8,
            ),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 28,
                  child:
                      widget.icon?.call(app) ??
                      Icon(Icons.apps_rounded, color: AppColors.apppickerIcon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label(app),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      if (detail != null)
                        Text(
                          detail,
                          textDirection: TextDirection.ltr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.apppickerDetail,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: widget.title,
    subtitle: context.l10n.pickApplicationHelp,
    stackActions: true,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PillFieldBox(
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                size: 20,
                color: AppColors.apppickerSearchIcon,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  style: pillFieldTextStyle(context),
                  decoration: pillFieldDecoration(
                    context,
                    hintText: context.l10n.searchApplications,
                  ),
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                ),
              ),
            ],
          ),
        ),
        // The same gap as between the list and the buttons below it.
        const SizedBox(height: 24),
        SizedBox(
          height: _listHeight,
          child: FutureBuilder<List<T>>(
            future: _applications,
            builder: (context, snapshot) {
              if (snapshot.hasError) return _message(widget.loadFailed);
              if (!snapshot.hasData) {
                return const Center(
                  child: SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                );
              }
              final visible = snapshot.data!.where(_matches).toList();
              if (visible.isEmpty) {
                return _message(context.l10n.noMatchingApplications);
              }
              return ListView.builder(
                itemCount: visible.length,
                itemBuilder: (context, index) => _row(visible[index]),
              );
            },
          ),
        ),
      ],
    ),
    actions: [
      PillButton(
        label: context.l10n.refresh,
        onPressed: () => setState(() {
          _applications = widget.load();
        }),
      ),
      PillButton(
        label: context.l10n.cancel,
        onPressed: () => Navigator.pop(context),
      ),
    ],
  );
}
