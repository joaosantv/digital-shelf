import 'package:flutter/foundation.dart';

import '../../core/errors/app_exception.dart';
import '../../core/state/ui_state.dart';
import '../../data/models/backlog_game_model.dart';
import '../../data/models/deal_model.dart';
import '../../data/repositories/backlog_repository.dart';
import '../../data/services/media_service.dart';

/// Resultado da tentativa de captura ou seleção de foto nativa.
typedef PhotoPickResult = ({
  String? path,
  String feedbackMessage,
  bool captured,
});

/// ViewModel da estante pessoal (*Minha Estante*), filtro por status e CRUD.
class BacklogViewModel extends ChangeNotifier {
  static const String filterAll = 'Todos';

  final BacklogRepository _backlogRepository;
  final MediaService _mediaService;

  UiState<List<BacklogGameModel>> _state = const Empty(
    'Sua estante ainda está vazia. Adicione um jogo ou salve uma oferta!',
  );
  List<BacklogGameModel> _allGames = [];
  String _statusFilter = filterAll;
  bool _isMutating = false;
  String? _lastFeedbackMessage;
  String? _lastOwnerId;

  BacklogViewModel({
    required this._backlogRepository,
    required this._mediaService,
  });

  /// Estado bruto da estante do usuário.
  UiState<List<BacklogGameModel>> get state => _state;

  /// Estado já considerando o filtro selecionado pelo usuário.
  UiState<List<BacklogGameModel>> get filteredState {
    return switch (_state) {
      Loading<List<BacklogGameModel>>() => const Loading(),
      Error<List<BacklogGameModel>>(:final message, :final canRetry) => Error(
        message,
        canRetry: canRetry,
      ),
      Empty<List<BacklogGameModel>>(:final message) => Empty(message),
      Success<List<BacklogGameModel>>(:final isFromCache, :final lastUpdated) =>
        filteredGames.isEmpty
            ? Empty('Nenhum jogo com o status "$_statusFilter".')
            : Success(
                filteredGames,
                isFromCache: isFromCache,
                lastUpdated: lastUpdated,
              ),
    };
  }

  /// Filtro de status ativo (*Todos*, *Quero jogar*, *Jogando*, *Zerado*).
  String get statusFilter => _statusFilter;

  /// Lista de jogos filtrada pelo [statusFilter] atual.
  List<BacklogGameModel> get filteredGames {
    if (_statusFilter == filterAll) {
      return List.unmodifiable(_allGames);
    }
    return List.unmodifiable(
      _allGames.where((game) => game.status == _statusFilter),
    );
  }

  /// Indica se a estante exibida veio do cache local offline.
  bool get isFromCache => switch (_state) {
    Success<List<BacklogGameModel>>(:final isFromCache) => isFromCache,
    _ => false,
  };

  /// Instante da última sincronização conhecida da estante.
  DateTime? get lastUpdated => switch (_state) {
    Success<List<BacklogGameModel>>(:final lastUpdated) => lastUpdated,
    _ => null,
  };

  /// Indica se existe operação de criação, edição ou exclusão em andamento.
  bool get isMutating => _isMutating;

  /// Última mensagem de sucesso ou erro gerada por uma mutação.
  String? get lastFeedbackMessage => _lastFeedbackMessage;

  /// Carrega os jogos da estante pertencentes ao usuário [ownerId].
  Future<void> loadGames(String ownerId) async {
    _lastOwnerId = ownerId;
    _state = const Loading();
    notifyListeners();

    try {
      final result = await _backlogRepository.getGames(ownerId);
      _allGames = List<BacklogGameModel>.from(result.games);
      if (_allGames.isEmpty) {
        _state = const Empty(
          'Sua estante ainda está vazia. Adicione um jogo ou salve uma oferta!',
        );
      } else {
        _state = Success(
          List.unmodifiable(_allGames),
          isFromCache: result.isFromCache,
          lastUpdated: result.lastUpdated,
        );
      }
    } on AppException catch (e) {
      _state = Error(e.message, canRetry: e.canRetry);
    } catch (_) {
      _state = const Error(
        'Não foi possível carregar sua estante agora.',
        canRetry: true,
      );
    }

    notifyListeners();
  }

  /// Atualiza o filtro por status na visualização da estante.
  void setStatusFilter(String filter) {
    if (_statusFilter != filter) {
      _statusFilter = filter;
      notifyListeners();
    }
  }

  /// Recarrega os jogos para o último usuário carregado.
  Future<void> retry() async {
    final ownerId = _lastOwnerId;
    if (ownerId != null && ownerId.isNotEmpty) {
      await loadGames(ownerId);
    }
  }

  /// Salva diretamente uma oferta da CheapShark na estante do usuário.
  Future<bool> addDealToBacklog({
    required String ownerId,
    required DealModel deal,
  }) async {
    final alreadyExists = _allGames.any(
      (item) => item.title.toLowerCase() == deal.title.trim().toLowerCase(),
    );
    if (alreadyExists) {
      _lastFeedbackMessage = '"${deal.title}" já está na sua estante.';
      notifyListeners();
      return false;
    }

    final newGame = BacklogGameModel(
      id: '',
      ownerId: ownerId,
      title: deal.title,
      status: BacklogStatus.queroJogar,
      targetPrice: deal.salePrice,
      notes: 'Oferta CheapShark (-${deal.discountPercent}%)',
      coverUrl: deal.thumb,
      updatedAt: DateTime.now(),
    );

    return saveGame(newGame, isNew: true);
  }

  /// Cria ou atualiza um item na estante e mantém o estado sincronizado.
  Future<bool> saveGame(BacklogGameModel game, {required bool isNew}) async {
    _isMutating = true;
    _lastFeedbackMessage = null;
    notifyListeners();

    try {
      final saved = isNew
          ? await _backlogRepository.addGame(game)
          : await _backlogRepository.updateGame(game);

      final existingIndex = _allGames.indexWhere((g) => g.id == saved.id);
      if (existingIndex >= 0) {
        _allGames[existingIndex] = saved;
      } else {
        _allGames.insert(0, saved);
      }
      _allGames.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      _state = Success(
        List.unmodifiable(_allGames),
        isFromCache: false,
        lastUpdated: DateTime.now(),
      );
      _lastFeedbackMessage = isNew
          ? '"${saved.title}" salvo na sua estante!'
          : '"${saved.title}" atualizado com sucesso!';
      return true;
    } on AppException catch (e) {
      debugPrint('ERRO FIRESTORE: $e');
      _lastFeedbackMessage = e.message;
      return false;
    } catch (e) {
      debugPrint('ERRO FIRESTORE: $e');
      _lastFeedbackMessage = 'Erro ao salvar o jogo: $e';
      return false;
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  /// Exclui o item [gameId] pertencente a [ownerId].
  Future<bool> deleteGame({
    required String gameId,
    required String ownerId,
  }) async {
    _isMutating = true;
    _lastFeedbackMessage = null;
    notifyListeners();

    try {
      await _backlogRepository.deleteGame(gameId: gameId, ownerId: ownerId);
      _allGames.removeWhere((game) => game.id == gameId);

      if (_allGames.isEmpty) {
        _state = const Empty(
          'Sua estante ainda está vazia. Adicione um jogo ou salve uma oferta!',
        );
      } else {
        _state = Success(
          List.unmodifiable(_allGames),
          isFromCache: false,
          lastUpdated: DateTime.now(),
        );
      }
      _lastFeedbackMessage = 'Jogo removido da sua estante.';
      return true;
    } on AppException catch (e) {
      debugPrint('ERRO FIRESTORE: $e');
      _lastFeedbackMessage = e.message;
      return false;
    } catch (e) {
      debugPrint('ERRO FIRESTORE: $e');
      _lastFeedbackMessage = 'Não foi possível excluir o jogo: $e';
      return false;
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  /// Captura ou seleciona foto nativa com fallback seguro quando negada/cancelada.
  Future<PhotoPickResult> capturePhoto(MediaSourceType source) async {
    try {
      final path = await _mediaService.pickCompressedImage(source);
      if (path == null) {
        return (
          path: null,
          feedbackMessage: 'Captura cancelada. A capa oficial da API ou o ícone padrão será mantido.',
          captured: false,
        );
      }
      return (
        path: path,
        feedbackMessage: 'Foto anexada com compressão e sem metadados EXIF.',
        captured: true,
      );
    } on PermissionDeniedAppException {
      return (
        path: null,
        feedbackMessage: 'Permissão negada. Você pode continuar usando a capa oficial da API ou o ícone padrão.',
        captured: false,
      );
    } catch (_) {
      return (
        path: null,
        feedbackMessage: 'Recurso de câmera/galeria indisponível. A capa oficial será mantida.',
        captured: false,
      );
    }
  }

  /// Limpa os dados mantidos em memória ao encerrar a sessão.
  void clearSessionData() {
    _allGames = [];
    _statusFilter = filterAll;
    _lastOwnerId = null;
    _lastFeedbackMessage = null;
    _state = const Empty(
      'Sua estante ainda está vazia. Adicione um jogo ou salve uma oferta!',
    );
    notifyListeners();
  }
}
