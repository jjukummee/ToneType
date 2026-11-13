import 'package:flutter/animation.dart';

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 180);
  static const normal = Duration(milliseconds: 260);
  static const sheet = Duration(milliseconds: 340);
  static const slow = Duration(milliseconds: 520);
  static const splash = Duration(milliseconds: 2400);
  static const settleDelay = Duration(milliseconds: 130);

  static const standardCurve = Curves.easeOutCubic;
  static const premiumCurve = Cubic(0.22, 1, 0.36, 1);
}
