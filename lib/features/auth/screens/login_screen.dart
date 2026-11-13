import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/state/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/tone_stage.dart';
import '../../../core/widgets/tonetype_primary_button.dart';
import '../../navigation/screens/main_shell.dart';
import '../../onboarding/screens/onboarding_problem_screen.dart';
import '../data/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.authService = const UnconfiguredAuthService(),
  });

  final AuthService authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  bool get _canSignIn =>
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty &&
      !_loading;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_canSignIn) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await widget.authService.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (!result.isSuccess) {
      setState(() => _error = result.errorMessage);
      return;
    }
    final controller = AppScope.of(context, listen: false);
    controller.signIn(result.email!);
    _enterApp(controller.onboardingComplete);
  }

  void _socialSignIn(String provider) {
    _showUnavailableMessage('$provider 로그인');
  }

  void _browseAsGuest() {
    final controller = AppScope.of(context, listen: false);
    controller.continueAsGuest();
    _enterApp(controller.onboardingComplete);
  }

  void _enterApp(bool onboardingComplete) {
    Navigator.of(context).pushAndRemoveUntil<void>(
      CupertinoPageRoute<void>(
        builder: (_) => onboardingComplete
            ? const MainShell()
            : const OnboardingProblemScreen(),
      ),
      (_) => false,
    );
  }

  void _showUnavailableMessage(String label) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label 기능은 계정 서버 연결 후 사용할 수 있어요.')));
  }

  @override
  Widget build(BuildContext context) {
    return ToneStage(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 44),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const _LoginWordmark(),
                  const Spacer(flex: 4),
                  _LoginField(
                    controller: _emailController,
                    placeholder: '아이디 또는 이메일',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() => _error = null),
                  ),
                  const SizedBox(height: 12),
                  _LoginField(
                    controller: _passwordController,
                    placeholder: '비밀번호',
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() => _error = null),
                    onSubmitted: (_) => _signIn(),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    child: _error == null
                        ? const SizedBox(height: 18)
                        : Padding(
                            padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _error!,
                                style: AppTypography.caption.copyWith(
                                  color: Colors.redAccent,
                                ),
                              ),
                            ),
                          ),
                  ),
                  ToneTypePrimaryButton(
                    label: _loading ? '로그인 중…' : '로그인',
                    onPressed: _canSignIn ? _signIn : null,
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      _LoginLink(
                        label: '회원가입',
                        onTap: () => _showUnavailableMessage('회원가입'),
                      ),
                      const _LinkDot(),
                      _LoginLink(
                        label: '아이디 찾기',
                        onTap: () => _showUnavailableMessage('아이디 찾기'),
                      ),
                      const _LinkDot(),
                      _LoginLink(
                        label: '비밀번호 찾기',
                        onTap: () => _showUnavailableMessage('비밀번호 찾기'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const _SimpleLoginDivider(),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: _SocialButton(
                          label: 'Apple로 로그인',
                          background: const Color(0xFF111419),
                          child: const Icon(
                            Icons.apple,
                            color: Colors.white,
                            size: 25,
                          ),
                          onTap: () => _socialSignIn('Apple'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SocialButton(
                          label: 'Google로 로그인',
                          background: Colors.white,
                          borderColor: AppColors.ink.withValues(alpha: 0.10),
                          child: const _GoogleMark(),
                          onTap: () => _socialSignIn('Google'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SocialButton(
                          label: '카카오로 로그인',
                          background: const Color(0xFFFFE500),
                          child: const Icon(
                            CupertinoIcons.chat_bubble_fill,
                            color: Color(0xFF17130F),
                            size: 23,
                          ),
                          onTap: () => _socialSignIn('Kakao'),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(flex: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox.square(dimension: 6),
                        ),
                        SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            '로그인 없이 기기에서 바로 사용할 수 있어요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _browseAsGuest,
                    child: const Text(
                      '로그인 없이 시작하기',
                      style: TextStyle(
                        color: AppColors.inkSoft,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginField extends StatelessWidget {
  const _LoginField({
    required this.controller,
    required this.placeholder,
    required this.onChanged,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String placeholder;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      placeholderStyle: const TextStyle(
        color: AppColors.inkFaint,
        fontSize: 16,
      ),
      style: const TextStyle(fontSize: 16, color: AppColors.ink),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.09)),
      ),
    );
  }
}

class _LoginWordmark extends StatelessWidget {
  const _LoginWordmark();

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      const TextSpan(
        style: TextStyle(
          fontFamily: AppTypography.family,
          fontSize: 34,
          color: AppColors.ink,
          letterSpacing: -1.3,
        ),
        children: [
          TextSpan(
            text: 'Tone',
            style: TextStyle(fontWeight: FontWeight.w400),
          ),
          TextSpan(
            text: 'Type',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
      semanticsLabel: 'ToneType',
    );
  }
}

class _LoginLink extends StatelessWidget {
  const _LoginLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.inkSoft,
        padding: const EdgeInsets.symmetric(horizontal: 3),
        minimumSize: const Size(0, 36),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _LinkDot extends StatelessWidget {
  const _LinkDot();

  @override
  Widget build(BuildContext context) {
    return const Text('·', style: TextStyle(color: AppColors.inkFaint));
  }
}

class _SimpleLoginDivider extends StatelessWidget {
  const _SimpleLoginDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: AppColors.separator)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('간편 로그인', style: AppTypography.caption),
        ),
        Expanded(child: Divider(color: AppColors.separator)),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.background,
    required this.child,
    required this.onTap,
    this.borderColor,
  });

  final String label;
  final Color background;
  final Color? borderColor;
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor ?? Colors.transparent),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(height: 58, child: Center(child: child)),
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.square(25),
      painter: const _GoogleMarkPainter(),
    );
  }
}

class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 18, size.height / 18);

    Paint fill(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final bluePath = Path()
      ..moveTo(17.64, 9.205)
      ..cubicTo(17.64, 8.567, 17.583, 7.953, 17.476, 7.364)
      ..lineTo(9, 7.364)
      ..lineTo(9, 10.846)
      ..lineTo(13.844, 10.846)
      ..cubicTo(13.635, 11.971, 13.001, 12.925, 12.047, 13.562)
      ..lineTo(12.047, 15.82)
      ..lineTo(14.956, 15.82)
      ..cubicTo(16.658, 14.254, 17.64, 11.946, 17.64, 9.205)
      ..close();

    final greenPath = Path()
      ..moveTo(9, 18)
      ..cubicTo(11.43, 18, 13.467, 17.194, 14.956, 15.82)
      ..lineTo(12.047, 13.562)
      ..cubicTo(11.241, 14.102, 10.212, 14.421, 9, 14.421)
      ..cubicTo(6.656, 14.421, 4.672, 12.836, 3.963, 10.707)
      ..lineTo(0.956, 10.707)
      ..lineTo(0.956, 13.039)
      ..cubicTo(2.437, 15.983, 5.482, 18, 9, 18)
      ..close();

    final yellowPath = Path()
      ..moveTo(3.963, 10.707)
      ..cubicTo(3.783, 10.167, 3.682, 9.592, 3.682, 9)
      ..cubicTo(3.682, 8.408, 3.784, 7.833, 3.963, 7.293)
      ..lineTo(3.963, 4.961)
      ..lineTo(0.956, 4.961)
      ..cubicTo(0.347, 6.176, 0, 7.55, 0, 9)
      ..cubicTo(0, 10.45, 0.347, 11.824, 0.956, 13.039)
      ..lineTo(3.963, 10.707)
      ..close();

    final redPath = Path()
      ..moveTo(9, 3.579)
      ..cubicTo(10.321, 3.579, 11.507, 4.033, 12.441, 4.925)
      ..lineTo(15.022, 2.344)
      ..cubicTo(13.463, 0.891, 11.426, 0, 9, 0)
      ..cubicTo(5.482, 0, 2.437, 2.017, 0.956, 4.961)
      ..lineTo(3.963, 7.293)
      ..cubicTo(4.672, 5.164, 6.656, 3.579, 9, 3.579)
      ..close();

    canvas.drawPath(bluePath, fill(_blue));
    canvas.drawPath(greenPath, fill(_green));
    canvas.drawPath(yellowPath, fill(_yellow));
    canvas.drawPath(redPath, fill(_red));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GoogleMarkPainter oldDelegate) => false;
}
