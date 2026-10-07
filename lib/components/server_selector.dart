// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../profiles/hysteria_profile.dart';
import 'app_select.dart';

class ServerSelector extends StatelessWidget {
  const ServerSelector({
    super.key,
    required this.profiles,
    required this.selected,
    required this.onChanged,
  });
  final List<HysteriaProfile> profiles;
  final HysteriaProfile? selected;
  final ValueChanged<HysteriaProfile>? onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: AppSelect<HysteriaProfile>(
      value: selected,
      items: profiles
          .map(
            (profile) =>
                DropdownMenuItem(value: profile, child: Text(profile.name)),
          )
          .toList(),
      onChanged: onChanged == null
          ? null
          : (profile) {
              if (profile != null) onChanged!(profile);
            },
    ),
  );
}
