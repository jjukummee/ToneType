class AuthResult {
  const AuthResult.success(this.email) : errorMessage = null;
  const AuthResult.failure(this.errorMessage) : email = null;

  final String? email;
  final String? errorMessage;
  bool get isSuccess => email != null;
}

abstract interface class AuthService {
  Future<AuthResult> signIn({required String email, required String password});
}

class UnconfiguredAuthService implements AuthService {
  const UnconfiguredAuthService();

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    return const AuthResult.failure('계정 로그인 서버가 아직 연결되지 않았습니다.');
  }
}
