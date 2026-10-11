import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import '../../../core/theme/app_theme.dart';

enum SocialLoginProvider {
  google('Google로 로그인'),
  kakao('카카오 로그인');

  const SocialLoginProvider(this.label);
  final String label;
}

/// Original provider lettering and symbols sit within a wider brand-colored
/// surface. Only the surrounding container changes; artwork never stretches.
/// TDS supplies the existing pointer, keyboard and accessibility behavior.
class SocialLoginButton extends StatelessWidget {
  const SocialLoginButton({
    required this.provider,
    this.onPressed,
    this.disabled = false,
    super.key,
  });

  final SocialLoginProvider provider;
  final VoidCallback? onPressed;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final ios = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final (asset, imageSize, contentWidth) = switch (provider) {
      SocialLoginProvider.google when ios => (
        'assets/images/google_sign_in_ios.png',
        const Size(188, 44),
        156.0,
      ),
      SocialLoginProvider.google => (
        'assets/images/google_sign_in_android.png',
        const Size(180, 40),
        156.0,
      ),
      SocialLoginProvider.kakao => (
        'assets/images/kakao_login_kr.png',
        const Size(224, 46),
        112.0,
      ),
    };
    final google = provider == SocialLoginProvider.google;
    // Display the original ~14px lettering at ~16px, independent of the
    // button width. The crop contains the complete logo + label and excludes
    // the old container edge, without modifying any bundled image bytes.
    const artworkScale = 1.125;
    final width = imageSize.width * artworkScale;
    final height = imageSize.height * artworkScale;
    return TdsTextButton(
      size: TdsTextButtonSize.small,
      semanticLabel: provider.label,
      disabled: disabled || onPressed == null,
      onPressed: onPressed,
      child: TdsAssetFrame(
        shape: const TdsAssetFrameShape(
          width: double.infinity,
          height: 56,
          radius: 12,
        ),
        backgroundColor: google
            ? AppColors.googleBorder
            : AppColors.kakaoYellow,
        content: Padding(
          padding: EdgeInsets.all(google ? 1 : 0),
          child: TdsAssetFrame(
            shape: const TdsAssetFrameShape(
              width: double.infinity,
              height: 56,
              radius: 11,
            ),
            backgroundColor: google
                ? TdsTheme.of(context).color('white')
                : AppColors.kakaoYellow,
            content: TdsAssetFrame(
              shape: TdsAssetFrameShape(
                width: contentWidth * artworkScale,
                height: 28 * artworkScale,
                transparent: true,
              ),
              content: OverflowBox(
                minWidth: width,
                maxWidth: width,
                minHeight: height,
                maxHeight: height,
                child: ExcludeSemantics(
                  child: TdsAssetImage(
                    src: asset,
                    frameShape: TdsAssetFrameShape(
                      width: width,
                      height: height,
                      transparent: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared by both login entry points; one pending OAuth launch at a time.
class SocialLoginButtons extends StatefulWidget {
  const SocialLoginButtons({required this.onSignIn, super.key});

  final Future<void> Function(SocialLoginProvider provider) onSignIn;

  @override
  State<SocialLoginButtons> createState() => _SocialLoginButtonsState();
}

class _SocialLoginButtonsState extends State<SocialLoginButtons> {
  SocialLoginProvider? _pending;
  String? _error;

  Future<void> _signIn(SocialLoginProvider provider) async {
    if (_pending != null) return;
    setState(() {
      _pending = provider;
      _error = null;
    });
    try {
      await widget.onSignIn(provider);
    } catch (error) {
      if (mounted) setState(() => _error = '로그인하지 못했어요. $error');
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SocialLoginButton(
          provider: SocialLoginProvider.google,
          disabled: _pending != null,
          onPressed: () => _signIn(SocialLoginProvider.google),
        ),
        const TdsSpacing(12),
        SocialLoginButton(
          provider: SocialLoginProvider.kakao,
          disabled: _pending != null,
          onPressed: () => _signIn(SocialLoginProvider.kakao),
        ),
        if (_pending != null || _error != null) ...[
          const TdsSpacing(12),
          Semantics(
            liveRegion: true,
            child: TdsText(
              _error ?? '${_pending!.label} 연결 중…',
              typography: TdsTypography.t7,
              color: _error == null
                  ? TdsTheme.of(context).color('grey600')
                  : TdsPalette.red600,
            ),
          ),
        ],
      ],
    ),
  );
}
