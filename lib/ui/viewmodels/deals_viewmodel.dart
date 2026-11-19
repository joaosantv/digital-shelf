import 'package:flutter/foundation.dart';

import '../../core/errors/app_exception.dart';
import '../../core/state/ui_state.dart';
import '../../data/models/deal_model.dart';
import '../../data/repositories/deals_repository.dart';

/// ViewModel da aba *Explorar Ofertas*, controlando busca e cache offline.
class DealsViewModel extends ChangeNotifier {
  final DealsRepository _dealsRepository;

  UiState<List<DealModel>> _state = const Empty(
    'Pesquise um título de PC para encontrar promoções na CheapShark.',
  );
  String _currentQuery = '';

  DealsViewModel({required this._dealsRepository});

  /// Estado atual da listagem de promoções.
  UiState<List<DealModel>> get state => _state;

  /// Último termo pesquisado pelo usuário.
  String get currentQuery => _currentQuery;

  /// Indica se os dados atualmente exibidos vieram do cache offline.
  bool get isFromCache => switch (_state) {
    Success<List<DealModel>>(:final isFromCache) => isFromCache,
    _ => false,
  };

  /// Timestamp da última atualização dos dados exibidos, quando disponível.
  DateTime? get lastUpdated => switch (_state) {
    Success<List<DealModel>>(:final lastUpdated) => lastUpdated,
    _ => null,
  };

  /// Executa a busca de ofertas na CheapShark com transição explícita de estados.
  Future<void> searchDeals(String query) async {
    _currentQuery = query.trim();
    _state = const Loading();
    notifyListeners();

    try {
      final result = await _dealsRepository.searchDeals(_currentQuery);
      if (result.deals.isEmpty) {
        final message = _currentQuery.isEmpty
            ? 'Nenhuma oferta encontrada no momento.'
            : 'Nenhuma oferta encontrada para "$_currentQuery".';
        _state = Empty(message);
      } else {
        _state = Success(
          result.deals,
          isFromCache: result.isFromCache,
          lastUpdated: result.lastUpdated,
        );
      }
    } on AppException catch (e) {
      _state = Error(e.message, canRetry: e.canRetry);
    } catch (_) {
      _state = const Error(
        'Não foi possível carregar as promoções no momento.',
        canRetry: true,
      );
    }

    notifyListeners();
  }

  /// Repete a última pesquisa após uma falha recuperável.
  Future<void> retry() => searchDeals(_currentQuery);
}
