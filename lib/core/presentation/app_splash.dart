import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

/// OS 시작 화면과 같은 원본 로고·크기·흰 배경으로 초기화를 이어간다.
class AppSplashScreen extends StatelessWidget {
  const AppSplashScreen({super.key});

  static const logoAsset = 'assets/logos/samchun_app_icon.png';
  static const logoSize = 192.0;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '사입삼춘을 시작하고 있어요',
    liveRegion: true,
    child: TdsAssetFrame(
      shape: const TdsAssetFrameShape(
        width: double.infinity,
        height: double.infinity,
        transparent: false,
      ),
      backgroundColor: TdsPalette.white,
      content: const TdsAssetImage(
        src: logoAsset,
        frameShape: TdsAssetFrameShape(
          width: logoSize,
          height: logoSize,
          transparent: true,
        ),
      ),
    ),
  );
}
