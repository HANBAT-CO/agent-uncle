import 'dart:async';

import 'package:agent_uncle/features/auth/domain/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AgentUncleApp extends StatefulWidget {
  const AgentUncleApp({required this.authRepository, super.key});

  final AuthRepository authRepository;

  @override
  State<AgentUncleApp> createState() => _AgentUncleAppState();
}

class _AgentUncleAppState extends State<AgentUncleApp> {
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Agent Uncle',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: _user == null
          ? SignInPage(authRepository: widget.authRepository)
          : SignedInPage(authRepository: widget.authRepository, user: _user!),
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

  Future<void> _signIn({
    required String providerName,
    required Future<bool> Function() authenticate,
  }) async {
    setState(() => _loadingProvider = providerName);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final launched = await authenticate();
      if (!launched) {
        throw StateError('$providerName 로그인 페이지를 열 수 없습니다.');
      }
    } on AuthException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('로그인 실패: $error')));
    } finally {
      if (mounted) {
        setState(() => _loadingProvider = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.account_circle, size: 72),
                const SizedBox(height: 20),
                Text(
                  'Agent Uncle',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Supabase Google 로그인 테스트 화면',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _loadingProvider == null
                      ? () => _signIn(
                          providerName: 'Google',
                          authenticate: widget.authRepository.signInWithGoogle,
                        )
                      : null,
                  icon: _loadingProvider == 'Google'
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: const Text('Google로 로그인'),
                ),
                // TODO(auth): Re-enable after Kakao Biz App registration.
                // const SizedBox(height: 12),
                // FilledButton.icon(
                //   style: FilledButton.styleFrom(
                //     backgroundColor: const Color(0xFFFEE500),
                //     foregroundColor: const Color(0xFF191919),
                //   ),
                //   onPressed: _loadingProvider == null
                //       ? () => _signIn(
                //           providerName: 'Kakao',
                //           authenticate: widget.authRepository.signInWithKakao,
                //         )
                //       : null,
                //   icon: _loadingProvider == 'Kakao'
                //       ? const SizedBox.square(
                //           dimension: 18,
                //           child: CircularProgressIndicator(strokeWidth: 2),
                //         )
                //       : const Icon(Icons.chat_bubble),
                //   label: const Text('카카오로 로그인'),
                // ),
              ],
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

  Future<void> _signOut() async {
    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await widget.authRepository.signOut();
    } on AuthException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
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

    return Scaffold(
      appBar: AppBar(title: const Text('로그인 완료')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_user, size: 72),
              const SizedBox(height: 20),
              Text(displayName, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(widget.user.email ?? widget.user.id),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: _isLoading ? null : _signOut,
                child: const Text('로그아웃'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
