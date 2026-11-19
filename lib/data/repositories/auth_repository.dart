import '../../core/errors/app_exception.dart';
import '../services/auth_service.dart';

/// Repositório de autenticação com validação de entrada e gestão de sessão.
class AuthRepository {
  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  final AuthService _authService;

  AuthRepository({required this._authService});

  /// Stream reativo que notifica mudanças de login/logout.
  Stream<AuthUser?> get authStateChanges => _authService.authStateChanges;

  /// Usuário atualmente logado na sessão.
  AuthUser? get currentUser => _authService.currentUser;

  /// Valida os campos e autentica o usuário existente.
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    _validateCredentials(email: email, password: password);
    return _authService.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Valida os campos e registra uma nova conta de usuário.
  Future<AuthUser> register({
    required String email,
    required String password,
  }) async {
    _validateCredentials(email: email, password: password);
    return _authService.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Encerra a sessão ativa.
  Future<void> signOut() async {
    await _authService.signOut();
  }

  void _validateCredentials({required String email, required String password}) {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || !_emailRegex.hasMatch(trimmedEmail)) {
      throw const AuthAppException('Informe um endereço de e-mail válido.');
    }
    if (password.length < 6) {
      throw const AuthAppException('A senha deve ter no mínimo 6 caracteres.');
    }
  }
}
