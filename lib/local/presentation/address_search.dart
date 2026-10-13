import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';

import '../../core/address/address_search.dart';
import 'common.dart';

class AddressSearchPage extends StatefulWidget {
  const AddressSearchPage({this.gateway, super.key});

  final AddressSearchGateway? gateway;

  @override
  State<AddressSearchPage> createState() => _AddressSearchPageState();
}

class _AddressSearchPageState extends State<AddressSearchPage> {
  bool loading = true;
  String? error;
  late final AddressSearchGateway gateway;
  bool searching = false, closing = false;
  bool preparing = false;
  int request = 0;
  Future<void>? cancellation;

  @override
  void initState() {
    super.initState();
    gateway = widget.gateway ?? AddressSearch.instance;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (gateway.requiresUserGesture) {
        prepare();
      } else {
        start();
      }
    });
  }

  Future<void> prepare() async {
    if (!mounted || closing || preparing || searching) return;
    final currentRequest = ++request;
    setState(() {
      preparing = true;
      loading = true;
      error = null;
    });
    try {
      await gateway.prepare();
      if (!mounted || closing || currentRequest != request) return;
      setState(() => loading = false);
    } catch (failure) {
      if (!mounted || closing || currentRequest != request) return;
      setState(() {
        loading = false;
        error = failure is AddressSearchFailure
            ? failure.message
            : '주소 검색을 준비하지 못했어요. 다시 시도해 주세요.';
      });
    } finally {
      if (currentRequest == request) preparing = false;
    }
  }

  Future<void> start() async {
    if (!mounted || closing || searching) return;
    final currentRequest = ++request;
    setState(() {
      loading = true;
      searching = true;
      error = null;
    });
    try {
      final result = await gateway.search();
      if (!mounted || closing || currentRequest != request) return;
      closing = true;
      Navigator.pop(context, result);
    } catch (failure) {
      if (!mounted || closing || currentRequest != request) return;
      setState(() {
        loading = false;
        error = failure is AddressSearchFailure
            ? failure.message
            : '주소 검색을 열지 못했어요. 다시 시도해 주세요.';
      });
    } finally {
      if (currentRequest == request) searching = false;
    }
  }

  Future<void> cancelSearch() => cancellation ??= gateway
      .cancel()
      .timeout(const Duration(seconds: 2))
      .catchError((Object _) {});

  Future<void> close() async {
    if (closing) return;
    closing = true;
    request++;
    await cancelSearch();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    closing = true;
    request++;
    if (searching) {
      unawaited(cancelSearch());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: '주소 검색',
    back: false,
    bottom: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading)
          ActionButton('취소', weak: true, bottom: true, onPressed: close)
        else ...[
          ActionButton(
            error == null ? '주소 검색 열기' : '다시 시도',
            bottom: true,
            onPressed: error != null && gateway.requiresUserGesture
                ? prepare
                : start,
          ),
          const TdsSpacing(8),
          Inset(
            child: TdsTextButton(
              size: TdsTextButtonSize.small,
              colorToken: 'grey600',
              onPressed: close,
              child: const SizedBox(
                height: 44,
                child: Center(child: Text('닫기')),
              ),
            ),
          ),
        ],
      ],
    ),
    children: [
      FigmaSurface(
        children: [
          if (loading) ...[
            const Inset(
              child: SizedBox(height: 80, child: Center(child: TdsLoader())),
            ),
            Info(
              preparing
                  ? '카카오 주소검색을 준비하고 있어요.'
                  : gateway.requiresUserGesture
                  ? '새 창에서 주소를 검색하고 선택해 주세요.'
                  : '카카오 주소검색 화면을 여는 중이에요.',
            ),
          ] else if (error != null) ...[
            const Section('주소 검색을 열지 못했어요'),
            Info(error!, error: true),
            const Info('네트워크 상태를 확인한 뒤 다시 시도해 주세요.'),
          ] else ...[
            const Section('주소를 검색해 주세요'),
            const Info('아래 버튼을 누르면 카카오 주소검색 창이 열려요.'),
          ],
        ],
      ),
    ],
  );
}
