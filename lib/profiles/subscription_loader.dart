// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';

import 'hysteria_profile.dart';
import 'link_profile.dart';
import 'server_profile.dart';

class SubscriptionLoadResult {
  const SubscriptionLoadResult({
    required this.profiles,
    this.skippedCount = 0,
    this.title,
    this.description,
    this.webPageUrl,
    this.supportUrl,
    this.expiresAt,
  });

  final List<ServerProfile> profiles;
  final int skippedCount;
  final String? title;
  final String? description;
  final String? webPageUrl;
  final String? supportUrl;
  final DateTime? expiresAt;
}

/// Providers commonly publish expiry as Unix seconds in subscription-userinfo.
/// Missing, zero, or malformed values do not establish an expiry date.
DateTime? subscriptionExpiry(String? userInfo) {
  if (userInfo == null) return null;
  final match = RegExp(
    r'(?:^|;)\s*expire\s*=\s*(\d+)\s*(?:;|$)',
    caseSensitive: false,
  ).firstMatch(userInfo);
  final seconds = int.tryParse(match?.group(1) ?? '');
  if (seconds == null || seconds <= 0 || seconds > 253402300799) return null;
  return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
}

SubscriptionLoadResult parseSubscriptionDetailed(String body) {
  var text = body.trim();
  if (!text.contains('://') && text.isNotEmpty) {
    try {
      text = utf8.decode(base64.decode(base64.normalize(text)));
    } on FormatException {
      throw const FormatException('Subscription is not a supported URI list.');
    }
  }
  final lines = const LineSplitter()
      .convert(text)
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  if (lines.isEmpty) {
    throw const FormatException(
      'Subscription is empty. Check access or expiry.',
    );
  }
  final profiles = <ServerProfile>[];
  final metadata = <String, String>{};
  var skippedCount = 0;
  FormatException? firstError;
  for (final line in lines) {
    if (line.startsWith('#')) {
      final separator = line.indexOf(':');
      if (separator > 1) {
        metadata[line.substring(1, separator).trim().toLowerCase()] = line
            .substring(separator + 1)
            .trim();
      }
      continue;
    }
    try {
      profiles.add(switch (line.split('://').first.toLowerCase()) {
        'hysteria2' || 'hy2' => HysteriaProfile.parse(line),
        _ => parseServerLink(line),
      });
    } on FormatException catch (error) {
      if (lines.length == 1) rethrow;
      firstError ??= error;
      skippedCount++;
    }
  }
  if (profiles.isEmpty) {
    throw FormatException(
      'No supported servers in subscription. ${firstError?.message ?? ''}'
          .trim(),
    );
  }
  return SubscriptionLoadResult(
    profiles: profiles,
    skippedCount: skippedCount,
    title: subscriptionTitle(metadata['profile-title']),
    description: subscriptionDescription(
      metadata['announce'] ?? metadata['profile-description'],
    ),
    webPageUrl: subscriptionPageUrl(metadata['profile-web-page-url']),
    supportUrl: subscriptionPageUrl(
      metadata['support-url'] ?? metadata['profile-support-url'],
    ),
    expiresAt: subscriptionExpiry(metadata['subscription-userinfo']),
  );
}

List<ServerProfile> parseSubscription(String body) =>
    parseSubscriptionDetailed(body).profiles;

Future<SubscriptionLoadResult> loadSubscriptionDetailed(String url) async {
  final source = url.trim();
  final scheme = source.split('://').first.toLowerCase();
  if ({'hysteria2', 'hy2', 'vless', 'trojan', 'ss', 'vmess'}.contains(scheme)) {
    return parseSubscriptionDetailed(source);
  }
  final uri = Uri.tryParse(source);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    throw const FormatException('Enter a valid HTTPS subscription URL.');
  }
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final request = await client
        .getUrl(uri)
        .timeout(const Duration(seconds: 15));
    request.followRedirects = false;
    final response = await request.close().timeout(const Duration(seconds: 15));
    if (response.statusCode != HttpStatus.ok) {
      throw StateError(
        'Subscription request failed (HTTP ${response.statusCode}).',
      );
    }
    final bytes = <int>[];
    await for (final chunk in response.timeout(const Duration(seconds: 15))) {
      bytes.addAll(chunk);
      if (bytes.length > 1024 * 1024) {
        throw const FormatException('Subscription exceeds the 1 MiB limit.');
      }
    }
    final parsed = parseSubscriptionDetailed(utf8.decode(bytes));
    return SubscriptionLoadResult(
      profiles: parsed.profiles,
      skippedCount: parsed.skippedCount,
      title:
          subscriptionTitle(response.headers.value('profile-title')) ??
          parsed.title,
      description:
          subscriptionDescription(
            response.headers.value('announce') ??
                response.headers.value('profile-description'),
          ) ??
          parsed.description,
      webPageUrl:
          subscriptionPageUrl(response.headers.value('profile-web-page-url')) ??
          parsed.webPageUrl,
      supportUrl:
          subscriptionPageUrl(
            response.headers.value('profile-support-url') ??
                response.headers.value('support-url'),
          ) ??
          parsed.supportUrl,
      expiresAt:
          subscriptionExpiry(response.headers.value('subscription-userinfo')) ??
          parsed.expiresAt,
    );
  } on IOException {
    throw StateError(
      'Could not retrieve the subscription. Check network and TLS.',
    );
  } finally {
    client.close(force: true);
  }
}

Future<List<ServerProfile>> loadSubscription(String url) async =>
    (await loadSubscriptionDetailed(url)).profiles;

/// Optional provider title; rendering always uses plain text.
String? subscriptionTitle(String? header) {
  if (header == null) return null;
  var title = header.trim();
  if (title.toLowerCase().startsWith('base64:')) {
    try {
      title = utf8.decode(
        base64.decode(base64.normalize(title.substring(7).trim())),
      );
    } on FormatException {
      return null;
    }
  }
  title = title.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ').trim();
  return title.isEmpty ? null : String.fromCharCodes(title.runes.take(160));
}

String? subscriptionDescription(String? header) {
  if (header == null) return null;
  var value = header.trim();
  if (value.toLowerCase().startsWith('base64:')) {
    try {
      value = utf8.decode(
        base64.decode(base64.normalize(value.substring(7).trim())),
      );
    } on FormatException {
      return null;
    }
  }
  value = value.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ').trim();
  return value.isEmpty ? null : String.fromCharCodes(value.runes.take(500));
}

String? subscriptionPageUrl(String? header) {
  if (header == null) return null;
  final uri = Uri.tryParse(header.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri.toString();
}
