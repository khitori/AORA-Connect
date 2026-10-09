// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Replaces a leading flag emoji or country code with a bundled flag image.
class ServerNodeLabel extends StatelessWidget {
  const ServerNodeLabel({
    super.key,
    required this.name,
    required this.subtitleParts,
    required this.protocolColor,
  });

  final String name;
  final List<String> subtitleParts;
  final Color protocolColor;

  static final _invisibleCharacters = RegExp(
    r'[\u00AD\u200B-\u200F\u202A-\u202E\u2060\u2066-\u2069\uFE0E\uFE0F\uFEFF]',
  );
  static final _codePrefix = RegExp(r'^[^A-Za-z]*([A-Za-z]{2})(?=$|[\s|:_-])');
  static final _separator = RegExp(r'^[\s|:_-]+');

  static _NodeLabel _parse(String name) {
    final cleanName = name.replaceAll(_invisibleCharacters, '').trimLeft();
    final runes = cleanName.runes.toList();
    if (runes.length >= 2 &&
        runes[0] >= 0x1F1E6 &&
        runes[0] <= 0x1F1FF &&
        runes[1] >= 0x1F1E6 &&
        runes[1] <= 0x1F1FF) {
      final countryCode = String.fromCharCodes([
        runes[0] - 0x1F1E6 + 0x41,
        runes[1] - 0x1F1E6 + 0x41,
      ]);
      if (FlagCode.fromCountryCode(countryCode) != null) {
        final remainder = String.fromCharCodes(runes.skip(2));
        return _NodeLabel(countryCode, _stripSeparator(remainder));
      }
    }

    final match = _codePrefix.firstMatch(cleanName);
    final countryCode = match?.group(1)?.toUpperCase();
    if (countryCode != null && FlagCode.fromCountryCode(countryCode) != null) {
      return _NodeLabel(
        countryCode,
        _stripSeparator(cleanName.substring(match!.end)),
      );
    }
    return _NodeLabel(null, name);
  }

  static String _stripSeparator(String value) =>
      value.replaceFirst(_separator, '').trim();

  @override
  Widget build(BuildContext context) {
    final node = _parse(name);
    return Row(
      children: [
        SizedBox(
          width: 24,
          child: Center(
            child: node.countryCode == null
                ? Icon(
                    Icons.public_rounded,
                    size: 18,
                    color: AppColors.muted300,
                  )
                : CountryFlag.fromCountryCode(
                    node.countryCode!,
                    theme: const ImageTheme(
                      width: 24,
                      height: 16,
                      shape: RoundedRectangle(3),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(node.label, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text.rich(
                TextSpan(
                  children: [
                    for (var index = 0; index < subtitleParts.length; index++)
                      TextSpan(
                        text:
                            '${index == 0 ? '' : ' · '}${subtitleParts[index]}',
                        style: index == 1
                            ? TextStyle(
                                color: protocolColor,
                                fontWeight: FontWeight.w600,
                              )
                            : null,
                      ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.muted500, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NodeLabel {
  const _NodeLabel(this.countryCode, this.label);

  final String? countryCode;
  final String label;
}
