import 'dart:async';

import 'package:chewie/src/center_play_button.dart';
import 'package:chewie/src/chewie_player.dart';
import 'package:chewie/src/chewie_progress_colors.dart';
import 'package:chewie/src/constants/events_enum.dart';
import 'package:chewie/src/helpers/utils.dart';
import 'package:chewie/src/material/material_progress_bar.dart';
import 'package:chewie/src/material/widgets/options_dialog.dart';
import 'package:chewie/src/material/widgets/playback_speed_dialog.dart';
import 'package:chewie/src/models/option_item.dart';
import 'package:chewie/src/models/subtitle_model.dart';
import 'package:chewie/src/notifiers/index.dart';
import 'package:chewie/src/player_keys.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

class MaterialControls extends StatefulWidget {
  const MaterialControls({
    this.showPlayButton = true,
    super.key, required this.isFullScreen,
  });

  final bool showPlayButton;
  final bool isFullScreen;

  @override
  State<StatefulWidget> createState() {
    return _MaterialControlsState();
  }
}

class _MaterialControlsState extends State<MaterialControls> with SingleTickerProviderStateMixin {
  late PlayerNotifier notifier;
  late VideoPlayerValue _latestValue;
  double? _latestVolume;
  Timer? _hideTimer;
  Timer? _initTimer;
  late var _subtitlesPosition = Duration.zero;
  bool _subtitleOn = false;
  Timer? _showAfterExpandCollapseTimer;
  bool _dragging = false;
  bool _displayTapped = false;
  Timer? _bufferingDisplayTimer;
  bool _displayBufferingIndicator = false;

  final barHeight = 48.0 * 1.5;
  final marginSize = 5.0;

  late VideoPlayerController controller;
  ChewieController? _chewieController;

  // We know that _chewieController is set in didChangeDependencies
  ChewieController get chewieController => _chewieController!;

  final Stopwatch _bufferingTimer = Stopwatch();

  @override
  void initState() {
    super.initState();
    notifier = Provider.of<PlayerNotifier>(context, listen: false);
  }

  @override
  void didChangeDependencies() {
    final oldController = _chewieController;
    _chewieController = ChewieController.of(context);
    controller = chewieController.videoPlayerController;

    if (oldController != chewieController) {
      _dispose();
      _initialize();
    }
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  void checkForVideoEnd() {
    if(controller.value.isCompleted){
      chewieController.playerEventEmitter(ChewiePlayerEvents.finished);
    }
  }

  void _dispose() {
    controller.removeListener(_updateState);
    _hideTimer?.cancel();
    _initTimer?.cancel();
    _showAfterExpandCollapseTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    if (_latestValue.hasError) {
      return chewieController.errorBuilder?.call(
            context,
            chewieController.videoPlayerController.value.errorDescription!,
          ) ??
          const Center(
            child: Icon(
              Icons.error,
              color: Colors.white,
              size: 42,
            ),
          );
    }

    return MouseRegion(
      onHover: (_) {
        _cancelAndRestartTimer();
      },
      child: GestureDetector(
        onTap: () => _cancelAndRestartTimer(),
        child: AbsorbPointer(
          absorbing: notifier.hideStuff,
          child: Stack(
            children: chewieController.isPlayerLocked && chewieController.isFullScreen
            ? [
              if(chewieController.supportPlayerLock && chewieController.isFullScreen)
                _buildPlayerLock(),
            ]
            : [
              if (_displayBufferingIndicator)
                const Center(
                  child: CircularProgressIndicator(),
                )
              else
                _buildHitArea(),
              _buildActionBar(),
              if(chewieController.customControls != null)
                AnimatedOpacity(
                  opacity: notifier.hideStuff ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 250),
                  child: chewieController.customControls!,
                ),
              if(chewieController.supportPlayerLock && chewieController.isFullScreen)
                _buildPlayerLock(),
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  if (_subtitleOn)
                    Transform.translate(
                      offset: Offset(
                        0.0,
                        notifier.hideStuff ? barHeight * 0.8 : 0.0,
                      ),
                      child:
                          _buildSubtitles(context, chewieController.subtitle!),
                    ),
                  _buildBottomBar(context),
                  if(widget.isFullScreen && chewieController.landscapeControls != null)
                    AnimatedOpacity(
                      opacity: notifier.hideStuff ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 250),
                      child: chewieController.landscapeControls!,
                    ),
                ],
              ),
              if (chewieController.allowMuting)
                Positioned(
                  top: 8,
                  right: 16,
                  child: _buildMuteButton(controller),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerLock() {
    return Positioned(
      top: 8,
      right: 6,
      child: AnimatedOpacity(
        opacity: notifier.hideStuff ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 250),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if(chewieController.isPlayerLocked)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                chewieController.playerLockText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: 'Noto Sans',
                ),
              ),
            ),
            GestureDetector(
              onTap: (){
                chewieController.togglePlayerLock();
              },
              child: Container(
                height: 40,
                width: 40,
                color: Colors.transparent,
                alignment: Alignment.center,
                child: Icon(
                  chewieController.isPlayerLocked
                      ? Icons.lock_rounded
                      : Icons.lock_open_rounded,
                  size: 22,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBar() {
    return Positioned(
      top: 0,
      right: 0,
      child: SafeArea(
        child: AnimatedOpacity(
          opacity: notifier.hideStuff ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 250),
          child: Row(
            children: [
              // _buildSubtitleToggle(),
              if (chewieController.showOptions) _buildOptionsButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionsButton() {
    final options = <OptionItem>[
      OptionItem(
        onTap: () async {
          Navigator.pop(context);
          _onSpeedButtonTap();
        },
        iconData: Icons.speed,
        title: chewieController.optionsTranslation?.playbackSpeedButtonText ??
            'Playback speed',
      )
    ];

    if (chewieController.additionalOptions != null &&
        chewieController.additionalOptions!(context).isNotEmpty) {
      options.addAll(chewieController.additionalOptions!(context));
    }

    return AnimatedOpacity(
      opacity: notifier.hideStuff ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 250),
      child: IconButton(
        onPressed: () async {
          _hideTimer?.cancel();

          if (chewieController.optionsBuilder != null) {
            await chewieController.optionsBuilder!(context, options);
          } else {
            await showModalBottomSheet<OptionItem>(
              context: context,
              isScrollControlled: true,
              useRootNavigator: chewieController.useRootNavigator,
              builder: (context) => OptionsDialog(
                options: options,
                cancelButtonText:
                    chewieController.optionsTranslation?.cancelButtonText,
              ),
            );
          }

          if (_latestValue.isPlaying) {
            _startHideTimer();
          }
        },
        icon: const Icon(
          Icons.more_vert,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSubtitles(BuildContext context, Subtitles subtitles) {
    if (!_subtitleOn) {
      return const SizedBox();
    }
    final currentSubtitle = subtitles.getByPosition(_subtitlesPosition);
    if (currentSubtitle.isEmpty) {
      return const SizedBox();
    }

    if (chewieController.subtitleBuilder != null) {
      return chewieController.subtitleBuilder!(
        context,
        currentSubtitle.first!.text,
      );
    }

    return Padding(
      padding: EdgeInsets.all(marginSize),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: const Color(0x96000000),
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Text(
          currentSubtitle.first!.text.toString(),
          style: const TextStyle(
            fontSize: 18,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  AnimatedOpacity _buildBottomBar(
    BuildContext context,
  ) {
    final iconColor = Theme.of(context).textTheme.labelLarge!.color;
    return AnimatedOpacity(
      opacity: notifier.hideStuff ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        height: barHeight + (widget.isFullScreen ? 10.0 : 0),
        padding: EdgeInsets.only(
          left: 20,
          bottom: !widget.isFullScreen ? 10.0 : 0,
        ),
        child: SafeArea(
          top: false,
          bottom: widget.isFullScreen,
          minimum: chewieController.controlsSafeAreaMinimum,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    if (chewieController.isLive)
                      const Expanded(child: Text('LIVE'))
                    else if(chewieController.showTime)
                      _buildPosition(iconColor),
                    const Spacer(),
                    if (chewieController.allowFullScreen) _buildExpandButton(),
                  ],
                ),
              ),
              // SizedBox(
              //   height: chewieController.isFullScreen ? 15.0 : 0,
              // ),
              if (!chewieController.isLive && chewieController.showProgressBar)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.only(right: 20),
                    child: Row(
                      children: [
                        _buildProgressBar(),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  GestureDetector _buildMuteButton(
    VideoPlayerController controller,
  ) {
    return GestureDetector(
      onTap: () {
        _cancelAndRestartTimer();

        if (_latestValue.volume == 0) {
          controller.setVolume(_latestVolume ?? 0.5);
          chewieController.playerEventEmitter(ChewiePlayerEvents.unmute);
        } else {
          _latestVolume = controller.value.volume;
          controller.setVolume(0.0);
          chewieController.playerEventEmitter(ChewiePlayerEvents.mute);
        }
      },
      child: AnimatedOpacity(
        key: const Key(ChewiePlayerKeys.muteToggleIcon),
        opacity: notifier.hideStuff ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: ClipRect(
          child: Container(
            height: 26,
            width: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              _latestValue.volume > 0 ? CupertinoIcons.speaker_fill : CupertinoIcons.speaker_slash_fill,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  GestureDetector _buildExpandButton() {
    return GestureDetector(
      onTap: _onExpandCollapse,
      child: AnimatedOpacity(
        key: const Key(ChewiePlayerKeys.fullscreenToggleIcon),
        opacity: notifier.hideStuff ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          height: 32,
          width: 32,
          color: Colors.transparent,
          margin: const EdgeInsets.only(right: 12.0),
          padding: const EdgeInsets.only(
            left: 8.0,
            right: 8.0,
          ),
          alignment: Alignment.center,
          child: Center(
            child: Icon(
              widget.isFullScreen
                  ? Icons.fullscreen_exit
                  : Icons.fullscreen,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHitArea() {
    final bool isFinished = _latestValue.position >= _latestValue.duration;
    final bool showPlayButton =
        widget.showPlayButton && !_dragging && !notifier.hideStuff;

    return GestureDetector(
      onTap: () {
        if (_latestValue.isPlaying) {
          if (_displayTapped) {
            setState(() {
              notifier.hideStuff = true;
            });
          } else {
            _cancelAndRestartTimer();
          }
        } else {
          // _playPause();

          setState(() {
            notifier.hideStuff = true;
          });
        }
      },
      child: CenterPlayButton(
        key: const Key(ChewiePlayerKeys.playToggleIcon),
        backgroundColor: Colors.transparent,
        iconColor: Colors.white,
        isFinished: isFinished,
        isPlaying: controller.value.isPlaying,
        show: showPlayButton,
        onPressed: _playPause,
      ),
    );
  }

  Future<void> _onSpeedButtonTap() async {
    _hideTimer?.cancel();

    final chosenSpeed = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: chewieController.useRootNavigator,
      builder: (context) => PlaybackSpeedDialog(
        speeds: chewieController.playbackSpeeds,
        selected: _latestValue.playbackSpeed,
      ),
    );

    if (chosenSpeed != null) {
      controller.setPlaybackSpeed(chosenSpeed);
    }

    if (_latestValue.isPlaying) {
      _startHideTimer();
    }
  }

  Widget _buildPosition(Color? iconColor) {
    final position = _latestValue.position;
    final duration = _latestValue.duration;

    return RichText(
      text: TextSpan(
        text: '${formatDuration(position)} ',
        children: <InlineSpan>[
          TextSpan(
            text: '/ ${formatDuration(duration)}',
            style: TextStyle(
              fontSize: 14.0,
              color: Colors.white.withOpacity(.75),
              fontWeight: FontWeight.normal,
            ),
          )
        ],
        style: const TextStyle(
          fontSize: 14.0,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Widget _buildSubtitleToggle() {
  //   //if don't have subtitle hiden button
  //   if (chewieController.subtitle?.isEmpty ?? true) {
  //     return const SizedBox();
  //   }
  //   return GestureDetector(
  //     onTap: _onSubtitleTap,
  //     child: Container(
  //       height: barHeight,
  //       color: Colors.transparent,
  //       padding: const EdgeInsets.only(
  //         left: 12.0,
  //         right: 12.0,
  //       ),
  //       child: Icon(
  //         _subtitleOn
  //             ? Icons.closed_caption
  //             : Icons.closed_caption_off_outlined,
  //         color: _subtitleOn ? Colors.white : Colors.grey[700],
  //       ),
  //     ),
  //   );
  // }

  // void _onSubtitleTap() {
  //   setState(() {
  //     _subtitleOn = !_subtitleOn;
  //   });
  // }

  void _cancelAndRestartTimer() {
    _hideTimer?.cancel();
    _startHideTimer();

    setState(() {
      notifier.hideStuff = false;
      _displayTapped = true;
    });
  }

  Future<void> _initialize() async {
    _subtitleOn = chewieController.subtitle?.isNotEmpty ?? false;
    controller.addListener(_updateState);

    _updateState();

    if (controller.value.isPlaying || chewieController.autoPlay) {
      _startHideTimer();
    }

    if (chewieController.showControlsOnInitialize) {
      _initTimer = Timer(const Duration(milliseconds: 200), () {
        setState(() {
          notifier.hideStuff = false;
        });
      });
    }
  }

  void _onExpandCollapse() {
    setState(() {
      notifier.hideStuff = true;

      chewieController.toggleFullScreen();
      _showAfterExpandCollapseTimer =
          Timer(const Duration(milliseconds: 300), () {
            setState(() {
              _cancelAndRestartTimer();
              notifier.hideStuff = true;
            });
          });
    });
  }

  void _playPause() {
    final isFinished = _latestValue.position >= _latestValue.duration;

    setState(() {
      if (controller.value.isPlaying) {
        notifier.hideStuff = false;
        _hideTimer?.cancel();
        controller.pause();
        chewieController.playerEventEmitter(
          ChewiePlayerEvents.pause,
          {
            'action_source': 'player_play_pause_button',
            'video_position_seconds': controller.value.position.inSeconds,
          },
        );
      }
      else {
        _cancelAndRestartTimer();

        if (!controller.value.isInitialized) {
          // controller.initialize().then((_) {
          //   controller.play();
          // });
        } else {
          if (isFinished) {
            controller.seekTo(Duration.zero);
          }
          controller.play();
        }

        chewieController.playerEventEmitter(
          ChewiePlayerEvents.play,
          {
            'action_source': 'player_play_pause_button',
            'video_position_seconds': controller.value.position.inSeconds,
          },
        );
      }
    });
  }

  void _startHideTimer() {
    final hideControlsTimer = chewieController.hideControlsTimer.isNegative
        ? ChewieController.defaultHideControlsTimer
        : chewieController.hideControlsTimer;
    _hideTimer = Timer(hideControlsTimer, () {
      setState(() {
        notifier.hideStuff = true;
      });
    });
  }

  void _bufferingTimerTimeout() {
    _displayBufferingIndicator = true;
    if (mounted) {
      setState(() {});
    }
  }

  static DateTime lastBufferStartEventTime = DateTime(1990, 1, 1);
  static DateTime lastBufferEndEventTime = DateTime(1990, 1, 1);

  void handleBufferEvent(bool currentBufferingState, bool newBufferingState) {
    if(currentBufferingState == newBufferingState) return;

    if (newBufferingState) {
      _bufferStartEvent();
    }
    else {
      _bufferEndEvent();
    }
  }

  void _bufferStartEvent() {
    if(DateTime.now().difference(lastBufferStartEventTime) < const Duration(milliseconds: 10)) return;
    lastBufferStartEventTime = DateTime.now();

    _bufferingTimer.stop();
    _bufferingTimer.reset();
    _bufferingTimer.start();
    chewieController.playerEventEmitter(ChewiePlayerEvents.bufferStart, {
      'video_position_seconds': controller.value.position.inSeconds,
    });
  }

  void _bufferEndEvent() {
    if(DateTime.now().difference(lastBufferEndEventTime) < const Duration(milliseconds: 10)) return;
    lastBufferEndEventTime = DateTime.now();

    _bufferingTimer.stop();
    chewieController.playerEventEmitter(ChewiePlayerEvents.bufferEnd, {
      'video_position_seconds': controller.value.position.inSeconds,
      'buffer_duration_seconds': _bufferingTimer.elapsed.inMilliseconds / 1000,
    });
  }

  void _updateState() {
    if (!mounted) return;

    handleBufferEvent(_displayBufferingIndicator, controller.value.isBuffering);
    // display the progress bar indicator only after the buffering delay if it has been set
    if (chewieController.progressIndicatorDelay != null) {
      if (controller.value.isBuffering) {
        _bufferingDisplayTimer ??= Timer(
          chewieController.progressIndicatorDelay!,
          _bufferingTimerTimeout,
        );
      } else {
        _bufferingDisplayTimer?.cancel();
        _bufferingDisplayTimer = null;
        _displayBufferingIndicator = false;
      }
    }
    else {
      _displayBufferingIndicator = controller.value.isBuffering;
    }

    checkForVideoEnd();

    setState(() {
      _latestValue = controller.value;
      _subtitlesPosition = controller.value.position;
    });
  }

  Widget _buildProgressBar() {
    return Expanded(
      child: MaterialVideoProgressBar(
        controller,
        height: _chewieController?.progressBarHeight,
        handleHeight: _chewieController?.progressBarHandleHeight,
        onTap: () {
          final int duration = controller.value.position.inSeconds;
          Future.delayed(const Duration(milliseconds: 50), (){
            chewieController.playerEventEmitter(ChewiePlayerEvents.progressBarTap, {
              'seek_from': duration,
              'seek_to': controller.value.position.inSeconds,
              'action_source': 'progress_bar',
            });
          });
        },
        onDragStart: () {
          setState(() {
            _dragging = true;
          });
          chewieController.playerEventEmitter(ChewiePlayerEvents.progressBarDragStart, {
            'seek_from': controller.value.position.inSeconds,
            'actionSource': 'progress_bar',
          });

          _hideTimer?.cancel();
        },
        onDragUpdate: () {
          _hideTimer?.cancel();
        },
        onDragEnd: () {
          setState(() {
            _dragging = false;
          });
          final int duration = controller.value.position.inSeconds;
          Future.delayed(const Duration(milliseconds: 50), (){
            chewieController.playerEventEmitter(ChewiePlayerEvents.progressBarDragEnd, {
              'seek_from': duration,
              'seek_to': controller.value.position.inSeconds,
              'action_source': 'progress_bar',
            });
          });
          _startHideTimer();
        },
        colors: chewieController.materialProgressColors ??
            ChewieProgressColors(
              playedColor: Theme.of(context).colorScheme.secondary,
              handleColor: Theme.of(context).colorScheme.secondary,
              bufferedColor:
                  Theme.of(context).colorScheme.surface.withOpacity(0.5),
              backgroundColor: Theme.of(context).disabledColor.withOpacity(.5),
            ),
      ),
    );
  }
}
