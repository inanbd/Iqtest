import 'package:flutter/material.dart';

/// Lets a screen learn when it has been uncovered again.
///
/// The quiz replaces itself with the results screen, which completes the
/// quiz route's future the moment the swap happens — long before the attempt
/// has been filed. So the home screen cannot refresh by awaiting its own
/// `push`; it listens for `didPopNext` instead and reloads once it is
/// genuinely back on top.
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();
