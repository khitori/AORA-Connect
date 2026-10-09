// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

/// Legacy firewall helper, retained only to remove rules left by older builds.
/// Connection protection is now configured in the cores' TUN settings.
abstract interface class KillSwitch {
  Future<bool> isArmed();
  Future<void> arm({
    required String corePath,
    required String serverAddress,
    required int serverPort,
  });
  Future<void> allowTun();
  Future<void> revokeTun();
  Future<void> disarm();
}

class WindowsKillSwitch implements KillSwitch {
  const WindowsKillSwitch({this.helperPath});

  final String? helperPath;

  Future<String> _run(List<String> arguments) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Kill Switch currently requires Windows.');
    }
    final helper =
        helperPath ??
        '${File(Platform.resolvedExecutable).parent.path}/aoravpn_kill_switch.exe';
    if (!await File(helper).exists()) {
      throw StateError(
        'Kill Switch helper is missing. Rebuild the Windows app.',
      );
    }
    final result = await Process.run(helper, arguments);
    if (result.exitCode != 0) {
      throw StateError('Kill Switch: ${result.stderr.toString().trim()}');
    }
    return result.stdout.toString().trim();
  }

  @override
  Future<bool> isArmed() async => (await _run(['status'])) == 'armed';

  @override
  Future<void> arm({
    required String corePath,
    required String serverAddress,
    required int serverPort,
  }) async {
    await _run(['arm', corePath, serverAddress, '$serverPort']);
  }

  @override
  Future<void> allowTun() async {
    for (var attempt = 0; attempt < 10; attempt++) {
      try {
        await _run(['allow-tun']);
        return;
      } catch (_) {
        if (attempt == 9) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  @override
  Future<void> revokeTun() async {
    await _run(['revoke-tun']);
  }

  @override
  Future<void> disarm() async {
    await _run(['disarm']);
  }
}
