import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../../core/errors/app_exception.dart';

/// Representação agnóstica do usuário autenticado na aplicação.
class AuthUser {
  final String uid;
  final String email;

  const AuthUser({required this.uid, required this.email});
}

/// Contrato de autenticação utilizado pelos repositórios e ViewModels.
abstract class AuthService {
  /// Fluxo reativo com alterações no estado de sessão.
  Stream<AuthUser?> get authStateChanges;

  /// Usuário autenticado no momento, ou `null` caso não haja sessão ativa.
  AuthUser? get currentUser;

  /// Realiza login com e-mail e senha.
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  /// Cria nova conta de usuário com e-mail e senha.
  Future<AuthUser> createUserWithEmailAndPassword({
    required String email,
    required String password,
  });

  /// Encerra a sessão atual do usuário.
  Future<void> signOut();
}

/// Implementação concreta sobre o Firebase Authentication.
class FirebaseAuthService implements AuthService {
  final FirebaseAuth _firebaseAuth;

  FirebaseAuthService({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  @override
  Stream<AuthUser?> get authStateChanges =>
      _firebaseAuth.authStateChanges().map(_mapFirebaseUser);

  @override
  AuthUser? get currentUser => _mapFirebaseUser(_firebaseAuth.currentUser);

  @override
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = _mapFirebaseUser(credential.user);
      if (user == null) {
        throw const AuthAppException('Sessão indisponível após o login.');
      }
      return user;
    } on FirebaseAuthException catch (e) {
      throw AuthAppException(_translateFirebaseError(e));
    }
  }

  @override
  Future<AuthUser> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = _mapFirebaseUser(credential.user);
      if (user == null) {
        throw const AuthAppException('Não foi possível iniciar a nova conta.');
      }
      return user;
    } on FirebaseAuthException catch (e) {
      throw AuthAppException(_translateFirebaseError(e));
    }
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  AuthUser? _mapFirebaseUser(User? user) {
    if (user == null) return null;
    return AuthUser(uid: user.uid, email: user.email ?? '');
  }

  String _translateFirebaseError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'O formato do e-mail informado é inválido.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha incorretos.';
      case 'email-already-in-use':
        return 'Este e-mail já está cadastrado em outra conta.';
      case 'weak-password':
        return 'A senha deve possuir pelo menos 6 caracteres.';
      case 'network-request-failed':
        return 'Falha de rede ao conectar ao serviço de autenticação.';
      case 'too-many-requests':
        return 'Muitas tentativas seguidas. Aguarde alguns instantes.';
      default:
        final details = error.message?.trim();
        if (details != null && details.isNotEmpty) {
          return 'Erro na autenticação (${error.code}): $details';
        }
        return 'Erro na autenticação (${error.code}). Tente novamente.';
    }
  }
}

/// Implementação em memória utilizada como fallback local e em testes.
class InMemoryAuthService implements AuthService {
  final Map<String, ({String uid, String password})> _usersByEmail = {};
  final StreamController<AuthUser?> _controller =
      StreamController<AuthUser?>.broadcast();
  AuthUser? _currentUser;
  int _counter = 1;

  InMemoryAuthService({AuthUser? initialUser, String initialPassword = ''}) {
    if (initialUser != null) {
      final normalizedEmail = initialUser.email.trim().toLowerCase();
      _usersByEmail[normalizedEmail] = (
        uid: initialUser.uid,
        password: initialPassword,
      );
      _currentUser = initialUser;
    }
  }

  @override
  Stream<AuthUser?> get authStateChanges => _controller.stream;

  @override
  AuthUser? get currentUser => _currentUser;

  /// Registra credenciais em memória sem alterar a sessão ativa.
  void seedAccount({
    required String uid,
    required String email,
    required String password,
  }) {
    _usersByEmail[email.trim().toLowerCase()] = (uid: uid, password: password);
  }

  @override
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final record = _usersByEmail[normalizedEmail];

    if (record == null || record.password != password) {
      throw const AuthAppException('E-mail ou senha incorretos.');
    }

    final user = AuthUser(uid: record.uid, email: normalizedEmail);
    _currentUser = user;
    _controller.add(user);
    return user;
  }

  @override
  Future<AuthUser> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (_usersByEmail.containsKey(normalizedEmail)) {
      throw const AuthAppException(
        'Este e-mail já está cadastrado em outra conta.',
      );
    }

    final uid = 'local-uid-${_counter++}';
    _usersByEmail[normalizedEmail] = (uid: uid, password: password);
    final user = AuthUser(uid: uid, email: normalizedEmail);
    _currentUser = user;
    _controller.add(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _controller.add(null);
  }

  /// Libera recursos do controlador de stream em testes.
  Future<void> dispose() async {
    await _controller.close();
  }
}
