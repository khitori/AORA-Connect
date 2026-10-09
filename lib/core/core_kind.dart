// SPDX-License-Identifier: GPL-3.0-or-later
enum CoreKind { singBox, xray }

extension CoreKindLabel on CoreKind {
  String get label => switch (this) {
    CoreKind.singBox => 'sing-box',
    CoreKind.xray => 'Xray',
  };

  String get configuredVersion => switch (this) {
    CoreKind.singBox => '1.14.2',
    CoreKind.xray => '26.9.30',
  };

  String get displayName => '$label $configuredVersion';
}
