import 'package:agent_uncle/core/theme/app_theme.dart';
import 'dart:async';

import 'package:agent_uncle/features/auth/domain/auth_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

class GoogleAuthApp extends StatefulWidget {
  const GoogleAuthApp({required this.authRepository, super.key});

  final AuthRepository authRepository;

  @override
  State<GoogleAuthApp> createState() => _GoogleAuthAppState();
}

class _GoogleAuthAppState extends State<GoogleAuthApp> {
  StreamSubscription<User?>? _authSubscription;
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = widget.authRepository.currentUser;
    _authSubscription = widget.authRepository.userChanges.listen((user) {
      if (mounted) {
        setState(() => _user = user);
      }
    });
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      debugShowCheckedModeBanner: false,
      title: 'Agent Uncle',
      color: AppColors.background,
      builder: (context, child) =>
          TdsMobileAITProvider(child: AppTheme(child: child!)),
      home: _user == null
          ? SignInPage(authRepository: widget.authRepository)
          : SignedInPage(authRepository: widget.authRepository, user: _user!),
      pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
        settings: settings,
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
      ),
    );
  }
}

class SignInPage extends StatefulWidget {
  const SignInPage({required this.authRepository, super.key});

  final AuthRepository authRepository;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  String? _loadingProvider;
  String? _error;

  Future<void> _signIn({
    required String providerName,
    required Future<bool> Function() authenticate,
  }) async {
    setState(() {
      _loadingProvider = providerName;
      _error = null;
    });

    try {
      final launched = await authenticate();
      if (!launched) {
        throw StateError('$providerName 로그인 페이지를 열 수 없습니다.');
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object catch (error) {
      if (mounted) setState(() => _error = '로그인 실패: $error');
    } finally {
      if (mounted) {
        setState(() => _loadingProvider = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const TdsTop(
                    title: TdsTopTitleParagraph('Agent Uncle', size: 28),
                    subtitleBottom: TdsTopSubtitleParagraph('Google 계정으로 시작해요'),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                      child: Semantics(
                        liveRegion: true,
                        child: TdsText(_error!, color: TdsPalette.red600),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: TdsButton(
                      display: TdsButtonDisplay.block,
                      disabled: _loadingProvider != null,
                      loading: _loadingProvider == 'Google',
                      onPressed: _loadingProvider == null
                          ? () => _signIn(
                              providerName: 'Google',
                              authenticate:
                                  widget.authRepository.signInWithGoogle,
                            )
                          : null,
                      child: const Text('Google로 로그인'),
                    ),
                  ),
                  const TdsSpacing(24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: TdsButton(
                      display: TdsButtonDisplay.block,
                      variant: TdsButtonVariant.weak,
                      disabled: _loadingProvider != null,
                      onPressed: _loadingProvider == null
                          ? () => _signIn(
                              providerName: 'Kakao',
                              authenticate:
                                  widget.authRepository.signInWithKakao,
                            )
                          : null,
                      loading: _loadingProvider == 'Kakao',
                      child: const Text('카카오로 로그인'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SignedInPage extends StatefulWidget {
  const SignedInPage({
    required this.authRepository,
    required this.user,
    super.key,
  });

  final AuthRepository authRepository;
  final User user;

  @override
  State<SignedInPage> createState() => _SignedInPageState();
}

class _SignedInPageState extends State<SignedInPage> {
  bool _isLoading = false;
  String? _error;

  Future<void> _signOut() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await widget.authRepository.signOut();
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object catch (error) {
      if (mounted) setState(() => _error = '로그아웃 실패: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final metadata = widget.user.userMetadata;
    final displayName =
        metadata?['full_name'] as String? ??
        metadata?['name'] as String? ??
        '사용자';

    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TdsTop(
                    title: TdsTopTitleParagraph(
                      '$displayName님, 반가워요',
                      size: 28,
                    ),
                    subtitleBottom: TdsTopSubtitleParagraph(
                      widget.user.email ?? widget.user.id,
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                      child: Semantics(
                        liveRegion: true,
                        child: TdsText(_error!, color: TdsPalette.red600),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: TdsButton(
                      display: TdsButtonDisplay.block,
                      variant: TdsButtonVariant.weak,
                      disabled: _isLoading,
                      loading: _isLoading,
                      onPressed: _isLoading ? null : _signOut,
                      child: const Text('로그아웃'),
                    ),
                  ),
                  const TdsSpacing(24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
