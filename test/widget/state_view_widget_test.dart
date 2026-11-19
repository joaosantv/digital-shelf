import 'package:digital_shelf/core/state/ui_state.dart';
import 'package:digital_shelf/core/theme/app_theme.dart';
import 'package:digital_shelf/ui/widgets/state_view_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StateViewWidget', () {
    Widget wrap(Widget child) {
      return MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: child),
      );
    }

    testWidgets('renderiza CircularProgressIndicator no estado Loading', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          StateViewWidget<List<String>>(
            state: const Loading<List<String>>(),
            loadingMessage: 'Carregando dados...',
            onSuccess: (_, data, _, _) => Text(data.join(',')),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Carregando dados...'), findsOneWidget);
    });

    testWidgets('renderiza mensagem e título no estado Empty', (tester) async {
      await tester.pumpWidget(
        wrap(
          StateViewWidget<List<String>>(
            state: const Empty<List<String>>('Nenhum jogo encontrado.'),
            emptyTitle: 'Lista vazia',
            onSuccess: (_, data, _, _) => Text(data.join(',')),
          ),
        ),
      );

      expect(find.text('Lista vazia'), findsOneWidget);
      expect(find.text('Nenhum jogo encontrado.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets(
      'renderiza erro e aciona callback ao clicar em Tentar novamente',
      (tester) async {
        var retryTapped = false;

        await tester.pumpWidget(
          wrap(
            StateViewWidget<List<String>>(
              state: const Error<List<String>>(
                'Falha de conexão com o servidor.',
                canRetry: true,
              ),
              onRetry: () => retryTapped = true,
              onSuccess: (_, data, _, _) => Text(data.join(',')),
            ),
          ),
        );

        expect(find.text('Falha de conexão com o servidor.'), findsOneWidget);
        final retryButton = find.text('Tentar novamente');
        expect(retryButton, findsOneWidget);

        await tester.tap(retryButton);
        await tester.pump();

        expect(retryTapped, isTrue);
      },
    );

    testWidgets('oculta botão de retry quando canRetry for false', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          StateViewWidget<List<String>>(
            state: const Error<List<String>>(
              'Permissão negada.',
              canRetry: false,
            ),
            onRetry: () {},
            onSuccess: (_, data, _, _) => Text(data.join(',')),
          ),
        ),
      );

      expect(find.text('Permissão negada.'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsNothing);
    });

    testWidgets('renderiza conteúdo esperado no estado Success', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          StateViewWidget<List<String>>(
            state: const Success<List<String>>([
              'Hades',
              'Celeste',
            ], isFromCache: true),
            onSuccess: (_, data, isFromCache, _) =>
                Text('${data.join(' | ')} (cache=$isFromCache)'),
          ),
        ),
      );

      expect(find.text('Hades | Celeste (cache=true)'), findsOneWidget);
    });
  });
}
