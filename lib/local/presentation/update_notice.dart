import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import '../../core/app_release.dart';
import '../app_services.dart';
import '../domain/convenience_models.dart';
import '../domain/models.dart';
import '../domain/release_visibility.dart';
import 'common.dart';

class UpdateNotice extends StatefulWidget {
  const UpdateNotice({super.key});

  @override
  State<UpdateNotice> createState() => _UpdateNoticeState();
}

class _UpdateNoticeState extends State<UpdateNotice> {
  late final Future<InstalledAppRelease?> _installedRelease =
      readInstalledAppRelease();
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<InstalledAppRelease?>(
      future: _installedRelease,
      builder: (context, snapshot) {
        final installed = snapshot.data;
        if (installed == null) return const SizedBox.shrink();
        final app = AppScope.of(context);
        final notice = _selectNotice(app, installed);
        if (notice == null) return const SizedBox.shrink();
        return FigmaSurface(
          tinted: notice.kind == _UpdateNoticeKind.available,
          children: [
            Item(
              notice.title,
              leading: FigmaIcon(
                notice.kind == _UpdateNoticeKind.available ? 'refresh' : 'bell',
              ),
              subtitle: notice.subtitle,
            ),
            if (expanded && notice.body.isNotEmpty)
              Inset(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: TdsText(
                  notice.body,
                  typography: TdsTypography.t7,
                  color: TdsTheme.of(context).color('grey700'),
                ),
              ),
            Inset(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TdsTextButton(
                    size: TdsTextButtonSize.small,
                    onPressed: () => setState(() => expanded = !expanded),
                    child: Text(expanded ? '변경 사항 접기' : '변경 사항 보기'),
                  ),
                ],
              ),
            ),
            if (notice.kind == _UpdateNoticeKind.available)
              ActionButton(
                '공식 스토어 열기',
                onPressed: () => _runAction(() => _openUpdate(notice)),
              ),
            ActionButton(
              notice.kind == _UpdateNoticeKind.available ? '나중에 보기' : '확인',
              weak: true,
              onPressed: () => _runAction(() => _dismiss(notice)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _runAction(Future<void> Function() action) async {
    try {
      await action();
    } on AppFailure catch (error) {
      if (!mounted) return;
      TdsToastProvider.maybeOf(context)?.openToast(error.message);
    }
  }

  _ResolvedNotice? _selectNotice(
    AppServices app,
    InstalledAppRelease installed,
  ) {
    final dismissed = _dismissedKeys(
      app.workspace.updateNoticeDismissalsInput(),
    );
    final account = app.session.current;
    final notices = <_ResolvedNotice>[];
    for (final record in app.workspace.records('appReleases')) {
      final resolved = _resolvedNotice(record, installed, account);
      if (resolved != null && !dismissed.contains(resolved.dismissKey)) {
        notices.add(resolved);
      }
    }
    if (notices.isEmpty) return null;
    notices.sort((left, right) {
      final byKind = left.kind.index.compareTo(right.kind.index);
      if (byKind != 0) return byKind;
      final byBuild = right.buildNumber.compareTo(left.buildNumber);
      if (byBuild != 0) return byBuild;
      return right.publishedAt.compareTo(left.publishedAt);
    });
    return notices.firstOrNull;
  }

  Future<void> _dismiss(_ResolvedNotice notice) async {
    final app = AppScope.read(context);
    final input = app.workspace.updateNoticeDismissalsInput();
    final dismissed = _dismissedKeys(input)..add(notice.dismissKey);
    await app.workspace.saveUpdateNoticeDismissalsInput({
      ...input,
      'dismissedKeys': dismissed.toList(growable: false),
      'dismissed': {for (final key in dismissed) key: true},
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> _openUpdate(_ResolvedNotice notice) async {
    final app = AppScope.read(context);
    final input = app.workspace.updateNoticeDismissalsInput();
    await app.workspace.saveUpdateNoticeDismissalsInput({
      ...input,
      'lastOpenAttemptBuild': notice.buildNumber,
      'lastOpenAttemptPlatform': notice.platform,
      'lastOpenAttemptAt': DateTime.now().toUtc().toIso8601String(),
    });
    final opened = await openOfficialAppStore(notice.storeUrl, notice.platform);
    if (!opened) {
      throw const AppFailure('공식 스토어를 열지 못했어요. 잠시 후 다시 시도해 주세요.');
    }
  }
}

enum _UpdateNoticeKind { available, installed }

class _ResolvedNotice {
  const _ResolvedNotice({
    required this.dismissKey,
    required this.kind,
    required this.platform,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.storeUrl,
    required this.buildNumber,
    required this.publishedAt,
  });

  final String dismissKey;
  final _UpdateNoticeKind kind;
  final String platform;
  final String title;
  final String subtitle;
  final String body;
  final String storeUrl;
  final int buildNumber;
  final DateTime publishedAt;
}

_ResolvedNotice? _resolvedNotice(
  Record record,
  InstalledAppRelease installed,
  Account? account,
) {
  final platform = installed.platform;
  if (!const ['ios', 'android'].contains(platform)) return null;
  final eligible = projectAppRelease(record.data, account);
  if (eligible == null) return null;
  final data = _platformData(eligible, platform);
  if (data == null) return null;
  final buildNumber = _intFrom(data, const [
    'buildNumber',
    'build',
    'versionCode',
  ]);
  if (buildNumber == null || buildNumber < installed.buildNumber) return null;
  final versionName = _stringFrom(data, const [
    'versionName',
    'version',
    'buildName',
  ]).trim();
  final body = _stringFrom(data, const [
    'body',
    'notes',
    'whatsNew',
    'description',
    'summary',
  ]).trim();
  final publishedAt =
      _publishedAtOf(data) ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  final storeUrl = _stringFrom(data, const [
    'storeUrl',
    'updateUrl',
    'appStoreUrl',
    'playStoreUrl',
    'url',
  ]).trim();
  if (buildNumber > installed.buildNumber &&
      !isOfficialStoreUrl(storeUrl, platform)) {
    return null;
  }
  final kind = buildNumber > installed.buildNumber
      ? _UpdateNoticeKind.available
      : _UpdateNoticeKind.installed;
  final title = _stringFrom(data, const ['title', 'headline']).trim().isNotEmpty
      ? _stringFrom(data, const ['title', 'headline']).trim()
      : kind == _UpdateNoticeKind.available
      ? '새 업데이트가 있어요'
      : '이번 버전에 추가된 내용';
  final platformLabel = platform == 'ios' ? 'iOS' : 'Android';
  final releaseLabel = versionName.isEmpty
      ? '$platformLabel · 빌드 $buildNumber'
      : '$platformLabel · $versionName+$buildNumber';
  final subtitle = kind == _UpdateNoticeKind.available
      ? '$releaseLabel · 현재 ${installed.version}+${installed.buildNumber}'
      : '$releaseLabel 설치됨';
  return _ResolvedNotice(
    dismissKey: '$platform:$buildNumber:${kind.name}',
    kind: kind,
    platform: platform,
    title: title,
    subtitle: subtitle,
    body: body,
    storeUrl: storeUrl,
    buildNumber: buildNumber,
    publishedAt: publishedAt,
  );
}

Data? _platformData(Data source, String platformKey) {
  final platforms = source['platforms'];
  if (source.containsKey('platforms') &&
      (platforms is! Map || platforms[platformKey] is! Map)) {
    return null;
  }
  if (platforms is Map && platforms[platformKey] is Map) {
    return {
      ...Map<String, Object?>.from(source),
      ...Map<String, Object?>.from(platforms[platformKey] as Map),
    };
  }
  final direct = source[platformKey];
  if (direct is Map) {
    return {
      ...Map<String, Object?>.from(source),
      ...Map<String, Object?>.from(direct),
    };
  }
  final platform = textOf(source, 'platform').trim().toLowerCase();
  if (platform.isNotEmpty && platform != platformKey) return null;
  return Map<String, Object?>.from(source);
}

Set<String> _dismissedKeys(Data source) {
  final keys = <String>{};
  for (final key in stringsOf(source, 'dismissedKeys')) {
    if (key.trim().isNotEmpty) keys.add(key.trim());
  }
  final dismissed = mapOf(source, 'dismissed');
  for (final entry in dismissed.entries) {
    if (entry.value == true) keys.add(entry.key);
  }
  return keys;
}

int? _intFrom(Data source, List<String> keys) {
  for (final key in keys) {
    final value = source[key];
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }
  return null;
}

String _stringFrom(Data source, List<String> keys) {
  for (final key in keys) {
    final value = source[key];
    if (value is String && value.trim().isNotEmpty) return value;
  }
  return '';
}

DateTime? _publishedAtOf(Data source) {
  final value = _stringFrom(source, const [
    'publishedAt',
    'releasedAt',
    'availableAt',
    'startsAt',
    'createdAt',
  ]).trim();
  if (value.isEmpty) return null;
  return DateTime.tryParse(value)?.toUtc();
}
