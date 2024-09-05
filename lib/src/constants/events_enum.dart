enum ChewiePlayerEvents {
  initialized,
  play,
  pause,
  forward,
  rewind,
  enterFullscreen,
  exitFullscreen,
  progressBarDragStart,
  progressBarDragEnd,
  progressBarTap,
  bufferStart,
  bufferEnd,
  finished,
  exception,
  mute,
  unmute,
}

ChewiePlayerEvents getEventFromString(String eventName) {
  for (ChewiePlayerEvents playerEvent in ChewiePlayerEvents.values) {
    if(playerEvent.name == eventName){
      return playerEvent;
    }
  }

  return ChewiePlayerEvents.exception;
}
