import 'package:flutter/material.dart';

abstract final class AppShadows {
  static const card = <BoxShadow>[
    BoxShadow(
      color: Color(0x14202733),
      blurRadius: 24,
      spreadRadius: -10,
      offset: Offset(0, 10),
    ),
  ];

  static const floating = <BoxShadow>[
    BoxShadow(
      color: Color(0x332F6BFF),
      blurRadius: 28,
      spreadRadius: -10,
      offset: Offset(0, 14),
    ),
  ];
}
