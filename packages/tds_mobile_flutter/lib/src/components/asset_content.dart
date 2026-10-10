import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';
import 'asset.dart';
import 'icon_button.dart';
import 'text.dart';

/// Content-only variants omit the frame background. Frames are composed separately.
class TdsAssetContentIcon extends TdsAssetIcon {
  const TdsAssetContentIcon({
    required super.name,
    super.alt,
    super.color,
    super.size,
    super.scale,
    super.scaleType,
    super.key,
  });
}

class TdsAssetContentImage extends TdsAssetImage {
  const TdsAssetContentImage({
    required super.src,
    super.alt,
    super.scale,
    super.scaleType,
    super.package,
    super.key,
  }) : super(backgroundColor: const Color(0x00000000));
}

class TdsAssetContentLottie extends TdsAssetLottie {
  const TdsAssetContentLottie({
    required super.src,
    super.repeat,
    super.animate,
    super.controller,
    super.alt,
    super.package,
    super.scale,
    super.key,
  });
}

class TdsAssetVideo extends StatelessWidget {
  const TdsAssetVideo({
    required this.content,
    this.frameShape = const TdsAssetFrameShape(),
    this.backgroundColor = const Color(0x00000000),
    this.accessory,
    this.accessoryPosition = TdsAssetAccessoryPosition.bottomRight,
    this.accessoryMasking = false,
    this.contentMasker,
    super.key,
  });
  final TdsAssetContentVideo content;
  final TdsAssetFrameShape frameShape;
  final Color backgroundColor;
  final Widget? accessory;
  final TdsAssetAccessoryPosition accessoryPosition;
  final bool accessoryMasking;
  final Widget Function(Widget)? contentMasker;
  @override
  Widget build(BuildContext context) => TdsAssetFrame(
    shape: frameShape,
    backgroundColor: backgroundColor,
    accessory: accessory,
    accessoryPosition: accessoryPosition,
    accessoryMasking: accessoryMasking,
    contentMasker: contentMasker,
    content: content,
  );
}

/// Native playback (AVPlayer/ExoPlayer/HTML video); injected controllers remain
/// caller-owned. `playsInline` is always true: this widget never opens a route.
class TdsAssetContentVideo extends StatefulWidget {
  const TdsAssetContentVideo({
    this.src,
    this.controller,
    this.package,
    this.autoPlay = true,
    this.loop = true,
    this.muted = true,
    this.controls = false,
    this.scaleType = TdsAssetScaleType.fit,
    this.scale = 1,
    this.alt,
    this.onError,
    this.placeholder,
    super.key,
  }) : assert((src == null) != (controller == null));
  final String? src, package, alt;
  final VideoPlayerController? controller;
  final bool autoPlay, loop, muted, controls;
  final TdsAssetScaleType scaleType;
  final double scale;
  final ValueChanged<String>? onError;
  final Widget? placeholder;
  @override
  State<TdsAssetContentVideo> createState() => _TdsAssetContentVideoState();
}

class _TdsAssetContentVideoState extends State<TdsAssetContentVideo> {
  late VideoPlayerController _controller;
  bool _owned = false;
  int _generation = 0;
  String? _error;
  Future<void>? _initialization;
  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    _owned = widget.controller == null;
    _error = null;
    _initialization = null;
    _controller =
        widget.controller ??
        (widget.src!.startsWith('https:') || widget.src!.startsWith('http:')
            ? VideoPlayerController.networkUrl(Uri.parse(widget.src!))
            : VideoPlayerController.asset(
                widget.src!,
                package: widget.package,
              ));
    _controller.addListener(_changed);
    _initialize(++_generation);
  }

  Future<void> _initialize(int generation) async {
    final controller = _controller;
    try {
      // Option updates can arrive before the platform's initialized event.
      // Share that in-flight initialization instead of creating another player.
      await (_initialization ??= controller.value.isInitialized
          ? Future<void>.value()
          : controller.initialize());
      if (!mounted || generation != _generation) return;
      await controller.setLooping(widget.loop);
      if (!mounted || generation != _generation) return;
      await controller.setVolume(widget.muted ? 0 : 1);
      if (!mounted || generation != _generation) return;
      if (widget.autoPlay) {
        await controller.play();
      } else {
        await controller.pause();
      }
    } catch (error) {
      if (mounted && generation == _generation) _report(error.toString());
    }
  }

  void _report(String error) {
    if (error == _error) return;
    setState(() => _error = error);
    widget.onError?.call(error);
  }

  void _changed() {
    if (!mounted) return;
    if (_controller.value.hasError) {
      _report(_controller.value.errorDescription ?? 'Video playback failed');
    } else {
      setState(() {});
    }
  }

  void _detach() {
    _generation++;
    _controller.removeListener(_changed);
    if (_owned) _controller.dispose();
  }

  @override
  void didUpdateWidget(TdsAssetContentVideo old) {
    super.didUpdateWidget(old);
    if (old.src != widget.src ||
        old.controller != widget.controller ||
        old.package != widget.package) {
      _detach();
      _attach();
    } else if (old.autoPlay != widget.autoPlay ||
        old.loop != widget.loop ||
        old.muted != widget.muted) {
      _initialize(++_generation);
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.placeholder ??
          Semantics(label: widget.alt, child: const TdsText('동영상을 재생할 수 없어요'));
    }
    final value = _controller.value;
    if (!value.isInitialized) {
      return widget.placeholder ?? const SizedBox.shrink();
    }
    return Semantics(
      label: widget.alt,
      child: AspectRatio(
        aspectRatio: value.aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRect(
              child: FittedBox(
                fit: widget.scaleType == TdsAssetScaleType.fit
                    ? BoxFit.contain
                    : BoxFit.cover,
                child: SizedBox.fromSize(
                  size: value.size,
                  child: Transform.scale(
                    scale: widget.scale,
                    child: VideoPlayer(_controller),
                  ),
                ),
              ),
            ),
            if (widget.controls)
              Align(
                alignment: Alignment.bottomCenter,
                child: Row(
                  children: [
                    TdsIconButton(
                      semanticLabel: value.isPlaying ? '일시 정지' : '재생',
                      onPressed: () async {
                        try {
                          if (_controller.value.isPlaying) {
                            await _controller.pause();
                          } else {
                            await _controller.play();
                          }
                        } catch (error) {
                          if (mounted) _report(error.toString());
                        }
                      },
                      child: Text(value.isPlaying ? 'Ⅱ' : '▶'),
                    ),
                    Expanded(
                      child: VideoProgressIndicator(
                        _controller,
                        allowScrubbing: true,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
