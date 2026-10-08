/// Geometry shared by the episode overlay and its skeleton, so the skeleton
/// lines up with the content that replaces it. Bottom offsets are measured
/// from the bottom safe-area edge.
abstract final class EpisodeLayout {
  /// Inset of the caption from the left screen edge.
  static const double gutter = 16;

  /// Width of the action rail column.
  static const double railWidth = 64;

  /// Inset of the rail from the right screen edge.
  static const double railRight = 8;

  /// Gap between the caption and the rail.
  static const double railGap = 12;

  /// Size of a rail button's icon.
  static const double railIcon = 32;

  /// Height of the label under a rail icon.
  static const double railLabelHeight = 16;

  /// Gap between a rail icon and its label.
  static const double railLabelGap = 4;

  /// Padding above and below each rail button, part of its tap target.
  static const double railButtonPadding = 4;

  /// Full height of one rail button.
  static const double railButtonHeight =
      railButtonPadding * 2 + railIcon + railLabelGap + railLabelHeight;

  /// Vertical gap between rail buttons.
  static const double railSpacing = 18;

  /// Bottom offset of the rail.
  static const double railBottom = 36;

  /// Bottom offset of the caption.
  static const double captionBottom = 36;

  /// Line height of the episode title.
  static const double titleLineHeight = 24;

  /// Height of the episode chip.
  static const double chipHeight = 22;

  /// Gap between the episode chip and the title.
  static const double chipGap = 8;

  /// Bottom offset of the progress track.
  static const double progressBottom = 14;

  /// Thickness of the progress track at rest.
  static const double progressHeight = 3;

  /// Size of the brand mark in skeletons.
  static const double brandMark = 72;
}
