/// [time] as a clock reading: "mm:ss", or "h:mm:ss" from an hour up.
///
/// Whole seconds, rounded down, so a position never reads past the
/// duration it belongs to. Negative times read as zero.
String formatPlaybackTime(Duration time) {
  final seconds = time.isNegative ? 0 : time.inSeconds;
  final hours = seconds ~/ Duration.secondsPerHour;
  final minutes = seconds ~/ Duration.secondsPerMinute % 60;
  String two(int value) => value.toString().padLeft(2, '0');
  final clock = '${two(minutes)}:${two(seconds % 60)}';
  return hours > 0 ? '$hours:$clock' : clock;
}
