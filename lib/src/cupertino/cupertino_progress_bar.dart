import 'package:chewie/src/chewie_progress_colors.dart';
import 'package:chewie/src/progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

class CupertinoVideoProgressBar extends StatelessWidget {
  CupertinoVideoProgressBar(
    this.controller, {
    this.height,
    this.handleHeight,
    ChewieProgressColors? colors,
    this.onDragEnd,
    this.onDragStart,
    this.onDragUpdate,
    this.onTap,
    super.key,
  }) : colors = colors ?? ChewieProgressColors();

  final double? height;
  final double? handleHeight;
  final VideoPlayerController controller;
  final ChewieProgressColors colors;
  final Function()? onDragStart;
  final Function()? onDragEnd;
  final Function()? onDragUpdate;
  final Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return VideoProgressBar(
      controller,
      barHeight: height ?? 5,
      handleHeight: handleHeight ?? 6,
      drawShadow: true,
      colors: colors,
      onDragEnd: onDragEnd,
      onDragStart: onDragStart,
      onDragUpdate: onDragUpdate,
      onTap: onTap,
    );
  }
}
