import 'dart:async';

import 'package:digital_shelf/core/theme/app_theme.dart';
import 'package:digital_shelf/data/repositories/auth_repository.dart';
import 'package:digital_shelf/data/services/auth_service.dart';
import 'package:digital_shelf/ui/viewmodels/auth_viewmodel.dart';
import 'package:digital_shelf/ui/views/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _DelayedAuthService implements AuthService {
  final Completer<AuthUser> completer;
  final StreamController<AuthUser?> _controller =
      StreamController<AuthUser?>.broadcast();

  _DelayedAuthService(this.completer);

  @override
  Stream<AuthUser?> get authStateChanges => _controller.stream;

  @override
  AuthUser? get currentUser => null;

  @override
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return completer.future;
  }

  @override
  Future<AuthUser> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {}

  Future<void> dispose() => _controller.close();
}

void main() {
  group('LoginScreen', () {
    testWidgets('exibe mensagens de validação para campos vazios e inválidos', (
      tester,
    ) async {
      final authService = InMemoryAuthService();
      final authViewModel = AuthViewModel(
        authRepository: AuthRepository(authService: authService),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthViewModel>.value(
          value: authViewModel,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const LoginScreen(),
          ),
        ),
      );

      // Toca em Entrar com campos vazios.
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pump();

      expect(find.text('Informe seu e-mail.'), findsOneWidget);
      expect(find.text('Informe sua senha.'), findsOneWidget);

      // Digita e-mail malformado e senha curta.
      await tester.enterText(
        find.byKey(const Key('login_email_field')),
        'email-invalido',
      );
      await tester.enterText(
        find.byKey(const Key('login_password_field')),
        '123',
      );
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pump();

      expect(find.text('Informe um e-mail válido.'), findsOneWidget);
      expect(
        find.text('A senha deve ter pelo menos 6 caracteres.'),
        findsOneWidget,
      );

      authViewModel.dispose();
      await authService.dispose();
    });

    testWidgets('exibe CircularProgressIndicator no botão durante login', (
      tester,
    ) async {
      final completer = Completer<AuthUser>();
      final delayedAuth = _DelayedAuthService(completer);
      final authViewModel = AuthViewModel(
        authRepository: AuthRepository(authService: delayedAuth),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthViewModel>.value(
          value: authViewModel,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const LoginScreen(),
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('login_email_field')),
        'jogador@exemplo.com',
      );
      await tester.enterText(
        find.byKey(const Key('login_password_field')),
        '123456',
      );

      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final submitButton = tester.widget<FilledButton>(
        find.byKey(const Key('login_submit_button')),
      );
      expect(submitButton.onPressed, isNull);

      completer.complete(
        const AuthUser(uid: 'u1', email: 'jogador@exemplo.com'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);

      authViewModel.dispose();
      await delayedAuth.dispose();
    });
  });
}
