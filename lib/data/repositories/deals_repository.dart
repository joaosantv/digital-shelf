import '../../core/errors/app_exception.dart';
import '../models/deal_model.dart';
import '../services/cheapshark_service.dart';
import '../services/local_cache_service.dart';

/// Resultado da consulta de ofertas com rastreamento da origem dos dados.
typedef DealsResult = ({
  List<DealModel> deals,
  bool isFromCache,
  DateTime? lastUpdated,
});

/// Repositório que coordena busca online na CheapShark e fallback em cache.
class DealsRepository {
  final CheapSharkService _cheapSharkService;
  final LocalCacheService _cacheService;

  DealsRepository({
    required this._cheapSharkService,
    required this._cacheService,
  });

  /// Consulta ofertas para [query], atualizando o cache em caso de sucesso.
  ///
  /// Quando ocorre falha de rede, timeout ou erro do servidor, tenta recuperar
  /// a última resposta válida do cache local sinalizando `isFromCache: true`.
  Future<DealsResult> searchDeals(String query) async {
    try {
      final deals = await _cheapSharkService.fetchDeals(query: query);
      final now = DateTime.now();
      await _cacheService.saveDeals(deals, query: query, syncedAt: now);
      return (deals: deals, isFromCache: false, lastUpdated: now);
    } on AppException {
      final cached = await _cacheService.getCachedDeals();
      if (cached != null && cached.deals.isNotEmpty) {
        return (
          deals: cached.deals,
          isFromCache: true,
          lastUpdated: cached.lastUpdated,
        );
      }
      rethrow;
    }
  }
}
