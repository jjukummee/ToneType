import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/state/app_controller.dart';
import 'core/state/app_scope.dart';
import 'features/onboarding/screens/splash_screen.dart';

class ToneTypeApp extends StatelessWidget {
  const ToneTypeApp({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => MaterialApp(
          title: 'ToneType',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(highContrast: controller.highContrast),
          scrollBehavior: const CupertinoScrollBehavior(),
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                textScaler: TextScaler.linear(controller.textScale),
                disableAnimations:
                    media.disableAnimations || controller.reduceMotion,
                highContrast: media.highContrast || controller.highContrast,
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
