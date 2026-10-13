import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import '../../core/navigation/external_link.dart';
import '../../remote/remote_config.dart';
import '../app_services.dart';
import '../domain/models.dart';
import 'common.dart';

class RemoteGate extends StatelessWidget {
  const RemoteGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final config = app.config.current;
    if (config.update.required) {
      return _GateScreen(
        title: '업데이트가 필요해요',
        description: config.update.message.isEmpty
            ? '최신 버전으로 업데이트한 뒤 다시 이용해 주세요.'
            : config.update.message,
        buttonLabel: '스토어로 이동',
        disabled: config.update.storeUrl.isEmpty,
        onPressed: () => unawaited(openExternalUrl(config.update.storeUrl)),
      );
    }
    if (config.maintenance.active) {
      return _GateScreen(
        title: config.maintenance.title.isEmpty
            ? '점검 중이에요'
            : config.maintenance.title,
        description: config.maintenance.message.isEmpty
            ? '더 안정적인 이용을 위해 잠시 점검하고 있어요.'
            : config.maintenance.message,
      );
    }
    if (config.account?.status == 'suspended') {
      return _GateScreen(
        title: '이용이 제한된 계정이에요',
        description: config.account!.message.isEmpty
            ? '고객센터로 문의해 주세요.'
            : config.account!.message,
        buttonLabel: '로그아웃',
        onPressed: () => unawaited(app.session.signOut()),
      );
    }
    return child;
  }
}

class _GateScreen extends StatelessWidget {
  const _GateScreen({
    required this.title,
    required this.description,
    this.buttonLabel,
    this.onPressed,
    this.disabled = false,
  });

  final String title;
  final String description;
  final String? buttonLabel;
  final VoidCallback? onPressed;
  final bool disabled;

  @override
  Widget build(BuildContext context) => PageFrame(
    title: '사입삼춘',
    back: false,
    children: [
      SizedBox(height: MediaQuery.sizeOf(context).height * .18),
      TdsResult(
        title: Text(title),
        description: Text(description),
        button: buttonLabel == null
            ? null
            : TdsResultButton(
                onPressed: onPressed,
                disabled: disabled,
                child: Text(buttonLabel!),
              ),
      ),
    ],
  );
}

class RecommendedUpdateBanner extends StatelessWidget {
  const RecommendedUpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final update = app.config.current.update;
    if (!app.config.current.showRecommendedUpdate) {
      return const SizedBox.shrink();
    }
    return FigmaSurface(
      key: const ValueKey('recommended-update-banner'),
      tinted: true,
      children: [
        TdsListRow(
          leftAlignment: TdsListRowAlignment.top,
          left: const ExcludeSemantics(child: FigmaIcon('refresh')),
          contents: TdsListRowTexts(
            type: TdsListRowTextType.row2TypeA,
            top: const Text('새 버전이 준비됐어요'),
            bottom: Text(
              update.message.isEmpty
                  ? '더 안정적인 이용을 위해 최신 버전으로 업데이트해 주세요.'
                  : update.message,
            ),
          ),
          right: TdsTextButton(
            size: TdsTextButtonSize.small,
            onPressed: () => unawaited(app.config.dismissRecommendedUpdate()),
            child: const Text('나중에'),
          ),
        ),
        if (update.storeUrl.isNotEmpty)
          Inset(
            child: TdsButton(
              display: TdsButtonDisplay.block,
              size: TdsButtonSize.large,
              variant: TdsButtonVariant.weak,
              onPressed: () => unawaited(openExternalUrl(update.storeUrl)),
              child: const Text('업데이트'),
            ),
          ),
      ],
    );
  }
}

class RemoteNoticeCard extends StatelessWidget {
  const RemoteNoticeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final notice = app.config.current.topNoticeFor(app.session.current?.role);
    if (notice == null) return const SizedBox.shrink();
    return FigmaSurface(
      key: ValueKey('home-remote-notice-${notice.id}'),
      tinted: notice.severity == AppNoticeSeverity.critical,
      children: [
        _RemoteNoticeRow(
          notice: notice,
          prominent: true,
          onDismiss: notice.dismissible
              ? () => unawaited(app.config.dismissNotice(notice.id))
              : null,
        ),
      ],
    );
  }
}

class OperationNoticeSection extends StatelessWidget {
  const OperationNoticeSection({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final notices = app.config.current.visibleNoticesFor(
      app.session.current?.role,
    );
    if (notices.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Section('운영 공지'),
        FigmaSurface(
          children: [
            for (var i = 0; i < notices.length; i++)
              _RemoteNoticeRow(
                notice: notices[i],
                border: i > 0,
                onDismiss: notices[i].dismissible
                    ? () => unawaited(app.config.dismissNotice(notices[i].id))
                    : null,
              ),
          ],
        ),
      ],
    );
  }
}

class _RemoteNoticeRow extends StatelessWidget {
  const _RemoteNoticeRow({
    required this.notice,
    this.onDismiss,
    this.border = false,
    this.prominent = false,
  });

  final AppNotice notice;
  final VoidCallback? onDismiss;
  final bool border;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final theme = TdsTheme.of(context);
    final time = notice.updatedAt == null
        ? ''
        : displayTime(notice.updatedAt!.toIso8601String());
    return TdsListRow(
      key: ValueKey('remote-notice-${notice.id}'),
      verticalPadding: prominent
          ? TdsListRowVerticalPadding.large
          : TdsListRowVerticalPadding.medium,
      leftAlignment: TdsListRowAlignment.top,
      border: border ? TdsListRowBorder.indented : TdsListRowBorder.none,
      left: ExcludeSemantics(
        child: FigmaIcon(
          notice.severity == AppNoticeSeverity.critical ? 'bell' : 'pin',
          selected: notice.severity != AppNoticeSeverity.info,
        ),
      ),
      contents: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TdsBadge(
            size: TdsBadgeSize.xsmall,
            color: notice.severity == AppNoticeSeverity.critical
                ? TdsBadgeColor.red
                : TdsBadgeColor.blue,
            variant: TdsBadgeVariant.weak,
            child: Text('운영 공지 · ${notice.severity.label}'),
          ),
          const TdsSpacing(8),
          TdsText(
            notice.title,
            typography: prominent ? TdsTypography.t4 : TdsTypography.t5,
            fontWeight: TdsFontWeight.semibold,
          ),
          if (notice.body.isNotEmpty) ...[
            const TdsSpacing(6),
            TdsText(
              notice.body,
              typography: TdsTypography.t6,
              color: theme.color('grey700'),
            ),
          ],
          if (time.isNotEmpty) ...[
            const TdsSpacing(8),
            TdsText(
              time,
              typography: TdsTypography.t7,
              color: theme.color('grey600'),
            ),
          ],
        ],
      ),
      right: onDismiss == null
          ? null
          : TdsTextButton(
              size: TdsTextButtonSize.small,
              onPressed: onDismiss,
              child: const Text('닫기'),
            ),
      onPressed: notice.linkUrl.isEmpty
          ? null
          : () => unawaited(openExternalUrl(notice.linkUrl)),
    );
  }
}
