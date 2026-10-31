// SPDX-License-Identifier: GPL-3.0-or-later
import 'server_ping.dart';

class PingCancellation {
  bool cancelled = false;
  final _callbacks = <void Function()>[];
  void cancel() {
    if (cancelled) return;
    cancelled = true;
    for (final callback in List.of(_callbacks)) {
      callback();
    }
    _callbacks.clear();
  }

  void add(void Function() callback) {
    if (cancelled) {
      callback();
    } else {
      _callbacks.add(callback);
    }
  }

  void remove(void Function() callback) => _callbacks.remove(callback);
  void check() {
    if (cancelled) throw const ServerPingException('Cancelled');
  }
}
