import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/errors/app_exception.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/services/auth_service.dart';

/// ViewModel responsável pelo gerenciamento do estado de autenticação.
class AuthViewModel extends ChangeNotifier {
  final AuthRepository _authRepository;
  StreamSubscription<AuthUser?>? _authSubscription;

  AuthUser? _user;
  bool _isLoading = false;
  String? _errorMessage;

  AuthViewModel({required this._authRepository}) {
    _user = _authRepository.currentUser;
    _authSubscription = _authRepository.authStateChanges.listen((nextUser) {
      _user = nextUser;
      notifyListeners();
    });
  }

  /// Usuário autenticado na sessão atual, ou `null` se desconectado.
  AuthUser? get user => _user;

  /// Indica se existe uma sessão autenticada ativa.
  bool get isAuthenticated => _user != null;

  /// Indica se uma operação de login ou cadastro está em execução.
  bool get isLoading => _isLoading;

  /// Mensagem amigável de erro gerada na última tentativa de autenticação.
  String? get errorMessage => _errorMessage;

  /// Autentica um usuário existente com [email] e [password].
  Future<bool> signIn(String email, String password) async {
    return _runAuthAction(
      () => _authRepository.signIn(email: email, password: password),
    );
  }

  /// Cria uma nova conta e inicia sessão automaticamente.
  Future<bool> register(String email, String password) async {
    return _runAuthAction(
      () => _authRepository.register(email: email, password: password),
    );
  }

  /// Encerra a sessão do usuário atual.
  Future<void> signOut() async {
    _errorMessage = null;
    await _authRepository.signOut();
    _user = null;
    notifyListeners();
  }

  /// Limpa o erro exibido nos formulários de entrada.
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<bool> _runAuthAction(Future<AuthUser> Function() action) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await action();
      return true;
    } on AppException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (_) {
      _errorMessage = 'Ocorreu uma falha inesperada durante a autenticação.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
