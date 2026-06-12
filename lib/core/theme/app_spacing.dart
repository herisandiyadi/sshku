import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

abstract final class AppBorderRadius {
  static final sm = BorderRadius.circular(4);
  static final md = BorderRadius.circular(8);
  static final lg = BorderRadius.circular(12);
}
