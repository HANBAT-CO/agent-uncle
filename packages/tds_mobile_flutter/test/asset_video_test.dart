import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'collections_feedback_test.dart' show testApp;

class _FakeVideoPlatform extends VideoPlayerPlatform {
  bool autoInitialize = true;
  final events = <int, StreamController<VideoEvent>>{};
  final disposed = <int>[];
  final playing = <int, bool>{}, loops = <int, bool>{};
  final volumes = <int, double>{};
  final sources = <DataSource>[];
  @override
  Future<void> init() async {}
  @override
  Future<int> createWithOptions(VideoCreationOptions options) async {
    sources.add(options.dataSource);
    final id = sources.length;
    events[id] = StreamController<VideoEvent>();
    if (autoInitialize) initializePlayer(id);
    return id;
  }

  void initializePlayer(int id) => events[id]!.add(
    VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 10),
      size: const Size(320, 180),
    ),
  );

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => events[playerId]!.stream;
  @override
  Future<void> dispose(int playerId) async {
    disposed.add(playerId);
    await events[playerId]!.close();
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {
    loops[playerId] = looping;
  }

  @override
  Future<void> play(int playerId) async {
    playing[playerId] = true;
  }

  @override
  Future<void> pause(int playerId) async {
    playing[playerId] = false;
  }

  @override
  Future<void> setVolume(int playerId, double volume) async {
    volumes[playerId] = volume;
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const SizedBox.expand();
}

void main() {
  late _FakeVideoPlatform platform;
  setUp(() {
    platform = _FakeVideoPlatform();
    VideoPlayerPlatform.instance = platform;
  });
  testWidgets(
    'Video option changes share an in-flight initialization and use latest options',
    (tester) async {
      platform.autoInitialize = false;
      await tester.pumpWidget(
        testApp(const TdsAssetContentVideo(src: 'assets/a.mp4')),
      );
      await tester.pump();
      expect(platform.sources.length, 1);
      await tester.pumpWidget(
        testApp(
          const TdsAssetContentVideo(
            src: 'assets/a.mp4',
            loop: false,
            muted: false,
            autoPlay: false,
          ),
        ),
      );
      await tester.pump();
      expect(platform.sources.length, 1);
      platform.initializePlayer(1);
      await tester.pumpAndSettle();
      expect(platform.loops[1], false);
      expect(platform.volumes[1], 1);
      expect(platform.playing[1], false);
      await tester.pumpWidget(testApp(const SizedBox()));
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(platform.disposed, [1]);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Video honors source defaults, option updates, replacement and owned disposal',
    (tester) async {
      await tester.pumpWidget(
        testApp(const TdsAssetContentVideo(src: 'assets/a.mp4')),
      );
      await tester.pumpAndSettle();
      expect(platform.sources.length, 1);
      expect(platform.playing[1], true);
      expect(platform.loops[1], true);
      expect(platform.volumes[1], 0);
      await tester.pumpWidget(
        testApp(
          const TdsAssetContentVideo(
            src: 'assets/a.mp4',
            autoPlay: false,
            muted: false,
            loop: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(platform.sources.length, 1);
      expect(platform.playing[1], false);
      expect(platform.loops[1], false);
      expect(platform.volumes[1], 1);
      await tester.pumpWidget(
        testApp(
          const TdsAssetContentVideo(src: 'https://example.invalid/b.mp4'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(platform.disposed, [1]);
      expect(platform.sources.last.sourceType, DataSourceType.network);
      await tester.pumpWidget(testApp(const SizedBox()));
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(platform.disposed, [1, 2]);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Video external controller remains caller owned and reports errors once',
    (tester) async {
      final controller = VideoPlayerController.asset('assets/a.mp4');
      final errors = <String>[];
      await tester.pumpWidget(
        testApp(
          TdsAssetContentVideo(
            controller: controller,
            autoPlay: false,
            onError: errors.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      controller.value = VideoPlayerValue.erroneous('codec not supported');
      await tester.pump();
      expect(errors, ['codec not supported']);
      expect(find.text('동영상을 재생할 수 없어요'), findsOneWidget);
      await tester.pumpWidget(testApp(const SizedBox()));
      await tester.pumpAndSettle();
      expect(platform.disposed, isEmpty);
      await tester.runAsync(controller.dispose);
      expect(platform.disposed, [1]);
    },
  );
}
