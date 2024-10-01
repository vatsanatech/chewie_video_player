import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';

class AdaptiveControls extends StatelessWidget {
  const AdaptiveControls({
    super.key, required this.isFullScreen,
  });

  final bool isFullScreen;

  @override
  Widget build(BuildContext context) {
    switch (Theme.of(context).platform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.iOS:
        return MaterialControls(
          isFullScreen: isFullScreen,
        );

      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return const MaterialDesktopControls();

      // case TargetPlatform.iOS:
      //   return const CupertinoControls(
      //     backgroundColor: Color.fromRGBO(41, 41, 41, 0.7),
      //     iconColor: Color.fromARGB(255, 200, 200, 200),
      //   );
      default:
        return MaterialControls(
          isFullScreen: isFullScreen,
        );
    }
  }
}
