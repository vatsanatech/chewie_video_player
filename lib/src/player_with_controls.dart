import 'package:chewie/src/chewie_player.dart';
import 'package:chewie/src/helpers/adaptive_controls.dart';
import 'package:chewie/src/notifiers/index.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'package:video_player/video_player.dart';

class PlayerWithControls extends StatelessWidget {
  const PlayerWithControls({
    super.key,
    required this.magnifyPlayer, required this.isFullscreen,
  });

  final ValueNotifier<bool> magnifyPlayer;
  final bool isFullscreen;

  @override
  Widget build(BuildContext context) {
    final ChewieController chewieController = ChewieController.of(context);

    double lastScale = 1.0;
    double scale = 1.0;

    double calculateAspectRatio(BuildContext context) {
      final size = MediaQuery.of(context).size;
      final width = size.width;
      final height = size.height;

      return width > height ? width / height : height / width;
    }

    Widget buildControls(
      BuildContext context,
      ChewieController chewieController,
    ) {
      return chewieController.showControls ? Stack(
        children: [
          AdaptiveControls(
            isFullScreen: isFullscreen,
          ),
          if(chewieController.landscapeControlsOverlay != null)
            chewieController.landscapeControlsOverlay!,
          if(chewieController.portraitFixedControls != null && !chewieController.isFullScreen)
            chewieController.portraitFixedControls!,
        ],
      ) : const SizedBox();
    }

    Widget buildPlayerWithControls(
      ChewieController chewieController,
      BuildContext context,
    ) {
      return Stack(
        children: <Widget>[
          if (chewieController.placeholder != null)
            chewieController.placeholder!,
          ValueListenableBuilder(
            valueListenable: magnifyPlayer,
            builder: (context, _, __) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                transform: Matrix4.diagonal3(Vector3(
                  scale.clamp(1.0, 5.0),
                  scale.clamp(1.0, 5.0),
                  scale.clamp(1.0, 5.0),
                )),
                alignment: Alignment.center,
                transformAlignment: FractionalOffset.center,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: chewieController.aspectRatio ??
                        chewieController.videoPlayerController.value.aspectRatio,
                    child: VideoPlayer(chewieController.videoPlayerController),
                  ),
                ),
              );
            }
          ),
          if (chewieController.overlay != null) chewieController.overlay!,
          if (Theme.of(context).platform != TargetPlatform.iOS)
            Consumer<PlayerNotifier>(
              builder: (
                BuildContext context,
                PlayerNotifier notifier,
                Widget? widget,
              ) =>
                  Visibility(
                visible: !notifier.hideStuff,
                child: AnimatedOpacity(
                  opacity: notifier.hideStuff ? 0.0 : 0.8,
                  duration: const Duration(
                    milliseconds: 250,
                  ),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(color: Colors.black54),
                    child: SizedBox.expand(),
                  ),
                ),
              ),
            ),
            buildControls(context, chewieController)
        ],
      );
    }

    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      return Center(
        child: InteractiveViewer(
          maxScale: 1,
          minScale: 1,
          panEnabled: chewieController.zoomAndPan,
          scaleEnabled: chewieController.zoomAndPan,
          onInteractionStart: (details){
            lastScale = scale;
          },
          onInteractionUpdate: (ScaleUpdateDetails details){
            if(!chewieController.zoomAndPan) return;
            final double thresholdScale = (1 + chewieController.maxScale) / 2;
            if(scale == chewieController.maxScale && (lastScale * details.scale) <= thresholdScale){
              scale = 1;
              magnifyPlayer.value = !magnifyPlayer.value;
            }
            else if(scale == 1 && (lastScale * details.scale) > thresholdScale){
              scale = chewieController.maxScale;
              magnifyPlayer.value = !magnifyPlayer.value;
            }
          },
          child: SizedBox(
            height: constraints.maxHeight,
            width: constraints.maxWidth,
            child: AspectRatio(
              aspectRatio: calculateAspectRatio(context),
              child: buildPlayerWithControls(chewieController, context),
            ),
          ),
        ),
      );
    });
  }
}
