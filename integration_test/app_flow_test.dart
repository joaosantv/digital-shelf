import 'dart:convert';

import 'package:digital_shelf/data/services/auth_service.dart';
import 'package:digital_shelf/data/services/cheapshark_service.dart';
import 'package:digital_shelf/data/services/firestore_service.dart';
import 'package:digital_shelf/data/services/local_cache_service.dart';
import 'package:digital_shelf/data/services/media_service.dart';
import 'package:digital_shelf/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Jornada completa: login -> buscar oferta -> salvar -> editar status -> excluir',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final authService = InMemoryAuthService()
        ..seedAccount(
          uid: 'uid-integracao',
          email: 'jogador@digitalshelf.app',
          password: 'password123',
        );
      final firestoreService = InMemoryFirestoreService();
      final cacheService = LocalCacheService(preferences: prefs);

      final mockHttpClient = MockClient((request) async {
        expect(request.url.queryParameters['title'], 'Hades');
        return http.Response(
          jsonEncode([
            {
              'dealID': 'deal-hades-1',
              'title': 'Hades',
              'salePrice': '9.99',
              'normalPrice': '24.99',
              'savings': '60.0',
              'metacriticScore': '93',
              'thumb': '',
            },
          ]),
          200,
        );
      });

      await tester.pumpWidget(
        DigitalShelfApp(
          authService: authService,
          firestoreService: firestoreService,
          cacheService: cacheService,
          cheapSharkService: CheapSharkService(client: mockHttpClient),
          mediaService: MediaService(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Login na tela inicial.
      await tester.enterText(
        find.byKey(const Key('login_email_field')),
        'jogador@digitalshelf.app',
      );
      await tester.enterText(
        find.byKey(const Key('login_password_field')),
        'password123',
      );
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Digital Shelf'), findsOneWidget);

      // 2. Busca de oferta na aba Explorar Ofertas.
      await tester.enterText(
        find.byKey(const Key('deals_search_field')),
        'Hades',
      );
      await tester.tap(find.byKey(const Key('deals_search_button')));
      await tester.pumpAndSettle();

      expect(find.text('Hades'), findsWidgets);
      expect(find.text('-60%'), findsOneWidget);

      // 3. Salvamento da oferta na estante.
      await tester.tap(find.byKey(const Key('save_deal_deal-hades-1')));
      await tester.pumpAndSettle();

      expect(find.text('"Hades" salvo na sua estante!'), findsOneWidget);
      // Aguarda o fechamento automático do SnackBar para liberar a área inferior.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // 4. Navega para a aba Minha Estante.
      await tester.tap(find.text('Minha Estante'));
      await tester.pumpAndSettle();

      expect(find.text('Hades'), findsWidgets);
      expect(find.text('Quero jogar'), findsWidgets);

      // 5. Abre edição e altera status para Zerado.
      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();

      final statusDropdown = find.byKey(const Key('game_form_status_dropdown'));
      await tester.ensureVisible(statusDropdown);
      await tester.pumpAndSettle();
      await tester.tap(statusDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zerado').last);
      await tester.pumpAndSettle();

      final saveButton = find.byKey(const Key('game_form_save_button'));
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('Zerado'), findsWidgets);

      // 6. Exclui o item com diálogo de confirmação.
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();

      expect(find.text('Remover da estante'), findsOneWidget);
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Sua estante ainda está vazia. Adicione um jogo ou salve uma oferta!',
        ),
        findsOneWidget,
      );

      await authService.dispose();
    },
  );
}
