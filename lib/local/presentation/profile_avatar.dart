import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import '../app_services.dart';
import '../domain/models.dart';
import 'layout.dart';

/// 내 사진과 연결된 거래처 사진만 읽고, 나머지는 계정별 기본 아바타를 표시한다.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar(
    this.account, {
    this.photoId,
    this.large = false,
    this.size,
    super.key,
  }) : assert(size == null || size > 0);

  final Account account;
  final String? photoId;
  final bool large;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final viewer = app.session.current?.id;
    final canReadPhoto =
        viewer != null &&
        (viewer == account.id ||
            app.workspace.partners.any((peer) => peer.id == account.id));
    final id = (photoId ?? account.s('photoId')).trim();
    final dimension = size ?? (large ? 88.0 : 40.0);
    final shape = TdsAssetFrameShape(
      width: dimension,
      height: dimension,
      radius: TdsAssetFrames.circleLarge.radius,
      transparent: false,
    );
    final placeholder = TdsAssetFrame(
      shape: shape,
      content: FigmaIcon('person', size: dimension >= 64 ? 32 : 24),
    );
    final fallback = TdsAssetImage(
      key: ValueKey(account.defaultAvatarUrl),
      src: account.defaultAvatarUrl,
      frameShape: shape,
      backgroundColor: TdsTheme.of(context).color('grey100'),
      placeholder: placeholder,
      errorBuilder: (_, error, stack) => placeholder,
    );
    return Semantics(
      label: '${account.name} 프로필 사진',
      image: true,
      excludeSemantics: true,
      child: canReadPhoto && id.isNotEmpty
          ? _ProfilePhoto(
              // 계정·권한·사진 교체 후 이전 비동기 결과를 재사용하지 않는다.
              key: ValueKey((app.attachments, viewer, account.id, id)),
              repository: app.attachments,
              photoId: id,
              shape: shape,
              placeholder: placeholder,
              fallback: fallback,
            )
          : fallback,
    );
  }
}

class _ProfilePhoto extends StatefulWidget {
  const _ProfilePhoto({
    required this.repository,
    required this.photoId,
    required this.shape,
    required this.placeholder,
    required this.fallback,
    super.key,
  });

  final AttachmentRepository repository;
  final String photoId;
  final TdsAssetFrameShape shape;
  final Widget placeholder, fallback;

  @override
  State<_ProfilePhoto> createState() => _ProfilePhotoState();
}

class _ProfilePhotoState extends State<_ProfilePhoto> {
  late final Future<Uint8List> _bytes = widget.repository.bytes(widget.photoId);

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _bytes,
    builder: (context, snapshot) {
      if (snapshot.hasError) return widget.fallback;
      if (!snapshot.hasData) return widget.placeholder;
      return TdsAssetImage.memory(
        snapshot.data!,
        frameShape: widget.shape,
        scaleType: TdsAssetScaleType.fill,
        placeholder: widget.placeholder,
        errorBuilder: (_, error, stack) => widget.fallback,
      );
    },
  );
}
