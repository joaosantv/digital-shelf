import 'dart:convert';

import 'package:digital_shelf/core/errors/app_exception.dart';
import 'package:digital_shelf/core/state/ui_state.dart';
import 'package:digital_shelf/data/models/deal_model.dart';
import 'package:digital_shelf/data/repositories/deals_repository.dart';
import 'package:digital_shelf/data/services/cheapshark_service.dart';
import 'package:digital_shelf/data/services/local_cache_service.dart';
import 'package:digital_shelf/ui/viewmodels/deals_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DealsViewModel - Transições de UiState', () {
    late LocalCacheService cacheService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      cacheService = LocalCacheService(preferences: prefs);
    });

    test(
      'transita de Loading para Success quando a busca retorna ofertas',
      () async {
        final mockClient = MockClient((request) async {
          expect(request.url.host, 'www.cheapshark.com');
          expect(request.url.queryParameters['title'], 'Hades');
          expect(request.url.queryParameters['pageSize'], '20');
          return http.Response(
            jsonEncode([
              {
                'dealID': 'deal-1',
                'title': 'Hades',
                'salePrice': '9.99',
                'normalPrice': '24.99',
                'savings': '60.02',
                'metacriticScore': '93',
                'thumb': 'https://example.com/hades.jpg',
              },
            ]),
            200,
          );
        });

        final viewModel = DealsViewModel(
          dealsRepository: DealsRepository(
            cheapSharkService: CheapSharkService(client: mockClient),
            cacheService: cacheService,
          ),
        );

        final recordedStates = <UiState<List<DealModel>>>[];
        viewModel.addListener(() => recordedStates.add(viewModel.state));

        await viewModel.searchDeals('Hades');

        expect(recordedStates.length, 2);
        expect(recordedStates.first, isA<Loading<List<DealModel>>>());
        expect(recordedStates.last, isA<Success<List<DealModel>>>());

        final success = recordedStates.last as Success<List<DealModel>>;
        expect(success.data.length, 1);
        expect(success.data.first.title, 'Hades');
        expect(success.data.first.discountPercent, 60);
        expect(success.isFromCache, isFalse);
        expect(viewModel.isFromCache, isFalse);
      },
    );

    test(
      'transita de Loading para Empty quando não há ofertas para o termo',
      () async {
        final mockClient = MockClient(
          (_) async => http.Response(jsonEncode([]), 200),
        );

        final viewModel = DealsViewModel(
          dealsRepository: DealsRepository(
            cheapSharkService: CheapSharkService(client: mockClient),
            cacheService: cacheService,
          ),
        );

        final recordedStates = <UiState<List<DealModel>>>[];
        viewModel.addListener(() => recordedStates.add(viewModel.state));

        await viewModel.searchDeals('JogoInexistenteXYZ');

        expect(recordedStates.length, 2);
        expect(recordedStates.first, isA<Loading<List<DealModel>>>());
        expect(recordedStates.last, isA<Empty<List<DealModel>>>());

        final empty = recordedStates.last as Empty<List<DealModel>>;
        expect(empty.message, contains('JogoInexistenteXYZ'));
      },
    );

    test(
      'transita de Loading para Error sem cache e recupera ao chamar retry()',
      () async {
        var shouldFail = true;

        final mockClient = MockClient((_) async {
          if (shouldFail) {
            return http.Response('Erro interno', 503);
          }
          return http.Response(
            jsonEncode([
              {
                'dealID': 'deal-2',
                'title': 'Hollow Knight',
                'salePrice': '7.49',
                'normalPrice': '14.99',
                'savings': '50.03',
                'metacriticScore': '90',
                'thumb': 'https://example.com/hk.jpg',
              },
            ]),
            200,
          );
        });

        final viewModel = DealsViewModel(
          dealsRepository: DealsRepository(
            cheapSharkService: CheapSharkService(client: mockClient),
            cacheService: cacheService,
          ),
        );

        final recordedStates = <UiState<List<DealModel>>>[];
        viewModel.addListener(() => recordedStates.add(viewModel.state));

        await viewModel.searchDeals('Hollow Knight');

        expect(recordedStates.length, 2);
        expect(recordedStates[0], isA<Loading<List<DealModel>>>());
        expect(recordedStates[1], isA<Error<List<DealModel>>>());
        final errorState = recordedStates[1] as Error<List<DealModel>>;
        expect(errorState.canRetry, isTrue);

        shouldFail = false;
        await viewModel.retry();

        expect(recordedStates.length, 4);
        expect(recordedStates[2], isA<Loading<List<DealModel>>>());
        expect(recordedStates[3], isA<Success<List<DealModel>>>());
        final recovered = recordedStates[3] as Success<List<DealModel>>;
        expect(recovered.data.single.title, 'Hollow Knight');
        expect(recovered.isFromCache, isFalse);
      },
    );

    test('usa cache local com isFromCache true quando a rede falha', () async {
      await cacheService.saveDeals(const [
        DealModel(
          dealID: 'cached-1',
          title: 'Celeste',
          salePrice: 4.99,
          normalPrice: 19.99,
          savings: 75.0,
          metacriticScore: 92,
          thumb: '',
        ),
      ], query: 'Celeste');

      final failingClient = MockClient((_) async {
        throw const TimeoutAppException();
      });

      final viewModel = DealsViewModel(
        dealsRepository: DealsRepository(
          cheapSharkService: CheapSharkService(client: failingClient),
          cacheService: cacheService,
        ),
      );

      await viewModel.searchDeals('Celeste');

      expect(viewModel.state, isA<Success<List<DealModel>>>());
      final success = viewModel.state as Success<List<DealModel>>;
      expect(success.isFromCache, isTrue);
      expect(success.data.single.title, 'Celeste');
      expect(viewModel.isFromCache, isTrue);
    });
  });
}
