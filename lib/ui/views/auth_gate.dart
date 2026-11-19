import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/auth_viewmodel.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// Porta de entrada que alterna automaticamente entre login e área autenticada.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final user = authVm.user;

    if (authVm.isAuthenticated && user != null) {
      return HomeScreen(key: ValueKey<String>(user.uid));
    }
    return const LoginScreen();
  }
}
