// SPDX-License-Identifier: GPL-3.0-or-later
import '../l10n/app_localizations.dart';

/// Turns a raw subscription error ("FormatException: Enter a valid HTTPS
/// subscription URL.") into a plain explanation of what went wrong and what
/// to do. Errors without a known meaning keep their own message, without the
/// exception name in front.
String describeSubscriptionError(String error, AppLocalizations strings) {
  final message = error.replaceFirst(
    RegExp(r'^(?:\w*(?:Exception|Error)|Bad state):\s*'),
    '',
  );
  final http = RegExp(r'\(HTTP (\d+)\)').firstMatch(message);
  if (http != null) return strings.subscriptionErrorHttp(http.group(1)!);
  if (message.startsWith('Enter a valid HTTPS subscription URL')) {
    return strings.subscriptionErrorInvalidLink;
  }
  if (message.startsWith('Subscription is empty')) {
    return strings.subscriptionErrorEmpty;
  }
  if (message.startsWith('No supported servers') ||
      message.startsWith('Subscription is not a supported URI list')) {
    return strings.subscriptionErrorUnsupported;
  }
  if (message.contains('1 MiB limit')) return strings.subscriptionErrorTooLarge;
  if (RegExp(
    r'^(?:SocketException|HandshakeException|TimeoutException|HttpException)',
  ).hasMatch(error)) {
    return strings.subscriptionErrorNetwork;
  }
  return message;
}
