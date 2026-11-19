import 'package:flutter/foundation.dart';

import '../../core/errors/app_exception.dart';
import '../models/backlog_game_model.dart';
import '../services/firestore_service.dart';
import '../services/local_cache_service.dart';

/// Resultado da consulta de jogos da estante com indicação de cache offline.
typedef BacklogResult = ({
  List<BacklogGameModel> games,
  bool isFromCache,
  DateTime? lastUpdated,
});

/// Repositório que coordena CRUD no Firestore e cache local da estante.
class BacklogRepository {
  final FirestoreService _firestoreService;
  final LocalCacheService _cacheService;

  BacklogRepository({
    required this._firestoreService,
    required this._cacheService,
  });

  /// Carrega os jogos do usuário [ownerId] com fallback offline em cache local.
  Future<BacklogResult> getGames(String ownerId) async {
    if (ownerId.trim().isEmpty) {
      throw const AuthAppException('É necessário estar autenticado.');
    }

    try {
      final games = await _firestoreService.getBacklogGames(ownerId);
      final now = DateTime.now();
      await _cacheService.saveBacklogGames(ownerId, games, syncedAt: now);
      return (games: games, isFromCache: false, lastUpdated: now);
    } on AppException catch (error) {
      debugPrint('ERRO FIRESTORE: $error');
      if (error is PermissionDeniedAppException || error is AuthAppException) {
        rethrow;
      }

      final cached = await _cacheService.getCachedBacklogGames(ownerId);
      if (cached != null && cached.games.isNotEmpty) {
        return (
          games: cached.games,
          isFromCache: true,
          lastUpdated: cached.lastUpdated,
        );
      }
      rethrow;
    } catch (e) {
      debugPrint('ERRO FIRESTORE: $e');
      rethrow;
    }
  }

  /// Valida regras de negócio, persiste no Firestore e atualiza o cache local.
  Future<BacklogGameModel> addGame(BacklogGameModel game) async {
    _validateGame(game, requireId: false);

    final normalizedGame = game.copyWith(
      title: game.title.trim(),
      notes: game.notes.trim(),
      coverUrl: game.coverUrl.trim(),
      updatedAt: DateTime.now(),
    );

    try {
      final created = await _firestoreService.createBacklogGame(normalizedGame);
      await _upsertInCache(created);
      return created;
    } catch (e) {
      debugPrint('ERRO FIRESTORE: $e');
      rethrow;
    }
  }

  /// Valida regras de negócio, atualiza no Firestore e sincroniza o cache.
  Future<BacklogGameModel> updateGame(BacklogGameModel game) async {
    _validateGame(game, requireId: true);

    final normalizedGame = game.copyWith(
      title: game.title.trim(),
      notes: game.notes.trim(),
      coverUrl: game.coverUrl.trim(),
      updatedAt: DateTime.now(),
    );

    try {
      final updated = await _firestoreService.updateBacklogGame(normalizedGame);
      await _upsertInCache(updated);
      return updated;
    } catch (e) {
      debugPrint('ERRO FIRESTORE: $e');
      rethrow;
    }
  }

  /// Exclui um item da estante no Firestore e remove do cache local.
  Future<void> deleteGame({
    required String gameId,
    required String ownerId,
  }) async {
    if (ownerId.trim().isEmpty) {
      throw const AuthAppException('É necessário estar autenticado.');
    }
    if (gameId.trim().isEmpty) {
      throw const ValidationAppException('Identificador do jogo inválido.');
    }

    try {
      await _firestoreService.deleteBacklogGame(
        gameId: gameId,
        ownerId: ownerId,
      );
      final cached = await _cacheService.getCachedBacklogGames(ownerId);
      if (cached != null) {
        final updatedList = cached.games
            .where((item) => item.id != gameId)
            .toList();
        await _cacheService.saveBacklogGames(ownerId, updatedList);
      }
    } catch (e) {
      debugPrint('ERRO FIRESTORE: $e');
      rethrow;
    }
  }

  void _validateGame(BacklogGameModel game, {required bool requireId}) {
    if (game.ownerId.trim().isEmpty) {
      throw const AuthAppException('Usuário não autenticado.');
    }
    if (requireId && game.id.trim().isEmpty) {
      throw const ValidationAppException(
        'Identificador do jogo obrigatório para atualização.',
      );
    }
    if (game.title.trim().isEmpty) {
      throw const ValidationAppException('Informe o nome do jogo.');
    }
    if (!BacklogStatus.isValid(game.status)) {
      throw const ValidationAppException('Status do jogo inválido.');
    }
    if (game.targetPrice != null && game.targetPrice! < 0) {
      throw const ValidationAppException('O preço-alvo não pode ser negativo.');
    }
  }

  Future<void> _upsertInCache(BacklogGameModel game) async {
    final cached = await _cacheService.getCachedBacklogGames(game.ownerId);
    final items = List<BacklogGameModel>.from(cached?.games ?? const []);
    final index = items.indexWhere((element) => element.id == game.id);
    if (index >= 0) {
      items[index] = game;
    } else {
      items.insert(0, game);
    }
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _cacheService.saveBacklogGames(game.ownerId, items);
  }
}
