import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 실제 설치된 앱 메타데이터만 사용한다. 읽을 수 없으면 최신으로 추정하지 않는다.
class InstalledAppRelease {
  const InstalledAppRelease({
    required this.platform,
    required this.version,
    required this.buildNumber,
  });

  final String platform;
  final String version;
  final int buildNumber;
}

const _releaseChannel = MethodChannel('agent_uncle/app_release');

Future<InstalledAppRelease?> readInstalledAppRelease() async {
  if (kIsWeb) return null;
  try {
    final value = await _releaseChannel.invokeMapMethod<String, Object?>(
      'info',
    );
    if (value == null) return null;
    final platform = value['platform'];
    final version = value['version'];
    final build = int.tryParse('${value['buildNumber']}');
    if (!const ['ios', 'android'].contains(platform) ||
        version is! String ||
        version.isEmpty ||
        build == null ||
        build < 1) {
      return null;
    }
    return InstalledAppRelease(
      platform: platform as String,
      version: version,
      buildNumber: build,
    );
  } on PlatformException {
    return null;
  } on MissingPluginException {
    return null;
  }
}

bool isOfficialStoreUrl(String url, String platform) {
  final uri = Uri.tryParse(url);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      uri.hasFragment) {
    return false;
  }
  return switch (platform) {
    'ios' =>
      uri.host == 'apps.apple.com' && RegExp(r'/id[0-9]+$').hasMatch(uri.path),
    'android' =>
      uri.host == 'play.google.com' &&
          uri.path == '/store/apps/details' &&
          (uri.queryParameters['id']?.isNotEmpty ?? false),
    _ => false,
  };
}

Future<bool> openOfficialAppStore(String url, String platform) async {
  if (kIsWeb || !isOfficialStoreUrl(url, platform)) return false;
  try {
    return await _releaseChannel.invokeMethod<bool>('openStore', {
          'url': url,
        }) ??
        false;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}
