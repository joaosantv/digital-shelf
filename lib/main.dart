import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/backlog_repository.dart';
import 'data/repositories/deals_repository.dart';
import 'data/services/auth_service.dart';
import 'data/services/cheapshark_service.dart';
import 'data/services/firestore_service.dart';
import 'data/services/local_cache_service.dart';
import 'data/services/media_service.dart';
import 'ui/viewmodels/auth_viewmodel.dart';
import 'ui/viewmodels/backlog_viewmodel.dart';
import 'ui/viewmodels/deals_viewmodel.dart';
import 'ui/views/auth_gate.dart';

/// Flag de compilação para conectar ao Firebase Local Emulator Suite.
const bool useFirebaseEmulator = bool.fromEnvironment(
  'USE_FIREBASE_EMULATOR',
  defaultValue: false,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = await SharedPreferences.getInstance();
  final cacheService = LocalCacheService(preferences: preferences);

  final backend = await _initializeBackend();

  runApp(
    DigitalShelfApp(
      authService: backend.authService,
      firestoreService: backend.firestoreService,
      cacheService: cacheService,
      cheapSharkService: CheapSharkService(),
      mediaService: MediaService(),
    ),
  );
}

Future<({AuthService authService, FirestoreService firestoreService})>
_initializeBackend() async {
  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Firebase não inicializado: $e');
    }
  }

  // Quando o Firebase está ativo, usa sempre os serviços reais sem fallback em memória.
  if (Firebase.apps.isNotEmpty) {
    if (useFirebaseEmulator) {
      await FirebaseAuth.instance.useAuthEmulator('10.0.2.2', 9099);
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
        sslEnabled: false,
      );
      FirebaseFirestore.instance.useFirestoreEmulator('10.0.2.2', 8080);

      debugPrint(
        'Firebase Emulator ativo -> Auth: 10.0.2.2:9099 | '
        'Firestore: ${FirebaseFirestore.instance.settings.host} '
        '(persistence=${FirebaseFirestore.instance.settings.persistenceEnabled})',
      );
    }

    return (
      authService: FirebaseAuthService(firebaseAuth: FirebaseAuth.instance),
      firestoreService: FirebaseFirestoreService(
        firestore: FirebaseFirestore.instance,
      ),
    );
  }

  // Fallback em memória usado somente quando não há configuração do Firebase.
  final fallbackAuth = InMemoryAuthService()
    ..seedAccount(
      uid: 'demo-uid-1',
      email: 'jogador@digitalshelf.app',
      password: 'demo1234',
    );
  return (
    authService: fallbackAuth,
    firestoreService: InMemoryFirestoreService(),
  );
}

/// Widget raiz da aplicação Digital Shelf configurando injeção via Provider.
class DigitalShelfApp extends StatelessWidget {
  final AuthService authService;
  final FirestoreService firestoreService;
  final LocalCacheService cacheService;
  final CheapSharkService cheapSharkService;
  final MediaService mediaService;

  const DigitalShelfApp({
    super.key,
    required this.authService,
    required this.firestoreService,
    required this.cacheService,
    required this.cheapSharkService,
    required this.mediaService,
  });

  @override
  Widget build(BuildContext context) {
    final authRepository = AuthRepository(authService: authService);
    final dealsRepository = DealsRepository(
      cheapSharkService: cheapSharkService,
      cacheService: cacheService,
    );
    final backlogRepository = BacklogRepository(
      firestoreService: firestoreService,
      cacheService: cacheService,
    );

    return MultiProvider(
      providers: [
        Provider<AuthService>.value(value: authService),
        Provider<FirestoreService>.value(value: firestoreService),
        Provider<AuthRepository>.value(value: authRepository),
        Provider<DealsRepository>.value(value: dealsRepository),
        Provider<BacklogRepository>.value(value: backlogRepository),
        ChangeNotifierProvider<AuthViewModel>(
          create: (_) => AuthViewModel(authRepository: authRepository),
        ),
        ChangeNotifierProvider<DealsViewModel>(
          create: (_) => DealsViewModel(dealsRepository: dealsRepository),
        ),
        ChangeNotifierProvider<BacklogViewModel>(
          create: (_) => BacklogViewModel(
            backlogRepository: backlogRepository,
            mediaService: mediaService,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Digital Shelf',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const AuthGate(),
      ),
    );
  }
}
