import 'package:flutter/widgets.dart';

/// Tells route-aware widgets, such as the feed, when another route covers
/// them or uncovers them again.
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();
